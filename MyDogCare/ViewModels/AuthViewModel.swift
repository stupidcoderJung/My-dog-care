import Foundation
import SwiftUI
import Clerk

struct SignedInSession: Equatable {
    let id: String
    let firstName: String?
    let lastName: String?
    let username: String?
    let primaryEmail: String?
    let profileImageURL: URL?

    static let preview = SignedInSession(
        id: "session_preview",
        firstName: "Alex",
        lastName: "Kim",
        username: "alex",
        primaryEmail: "alex@example.com",
        profileImageURL: URL(string: "https://example.com/avatar.png")
    )

    var displayName: String {
        if let first = firstName, let last = lastName { return "\(first) \(last)" }
        return firstName ?? username ?? "Dog Lover"
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedIn(SignedInSession)
        case signedOut
        case error(String)
    }

    @Published private(set) var state: State
    @Published var isPerformingAction: Bool = false
    @Published var loadingMessage: String

    private let authService: ClerkAuthServicing
    private var authEventsTask: Task<Void, Never>?

    var stateIdentifier: String {
        switch state {
        case .loading: return "loading"
        case .signedIn: return "signedIn"
        case .signedOut: return "signedOut"
        case .error: return "error"
        }
    }

    init(authService: ClerkAuthServicing = ClerkAuthService.shared, isPreview: Bool = false) {
        self.authService = authService
        if isPreview {
            self.state = .signedIn(.preview)
            self.loadingMessage = "Loading preview…"
        } else {
            self.state = .loading
            self.loadingMessage = "Connecting to Clerk…"
        }
        observeAuthEvents()
    }

    func initialize() async {
        state = .loading
        loadingMessage = "Connecting to Clerk…"
        await refreshActiveSession()
    }

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            let session = try await authService.signIn(email: email, password: password)
            withAnimation { state = .signedIn(makeSession(from: session)) }
        } catch {
            withAnimation { state = .error(error.localizedDescription) }
        }
    }

    func startSignUp() async {
        do {
            try await authService.presentSignUp()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
            withAnimation { state = .signedOut }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    deinit {
        authEventsTask?.cancel()
    }

    private func observeAuthEvents() {
        authEventsTask?.cancel()
        authEventsTask = Task { [weak self] in
            for await event in Clerk.shared.authEventEmitter.events {
                await MainActor.run {
                    self?.handleAuthEvent(event)
                }
            }
        }
    }

    private func handleAuthEvent(_ event: AuthEvent) {
        switch event {
        case .signInCompleted, .signUpCompleted:
            Task { [weak self] in
                await self?.refreshActiveSession()
            }
        case .signedOut:
            withAnimation { state = .signedOut }
        }
    }

    private func refreshActiveSession(retryCount: Int = 3) async {
        do {
            let session = try await authService.restoreLastActiveSession()
            withAnimation { state = .signedIn(makeSession(from: session)) }
        } catch ClerkAuthError.noActiveSession {
            if retryCount > 0 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                await refreshActiveSession(retryCount: retryCount - 1)
            } else {
                withAnimation { state = .signedOut }
            }
        } catch {
            withAnimation { state = .error(error.localizedDescription) }
        }
    }

    private func makeSession(from clerkSession: Session) -> SignedInSession {
        let user = clerkSession.user
        let publicData = clerkSession.publicUserData
        let primaryEmail = user?.primaryEmailAddress?.emailAddress
            ?? user?.emailAddresses.first?.emailAddress
            ?? publicData?.identifier
        let profileImageURL = user?.imageUrl ?? publicData?.imageUrl

        return SignedInSession(
            id: clerkSession.id,
            firstName: user?.firstName ?? publicData?.firstName,
            lastName: user?.lastName ?? publicData?.lastName,
            username: user?.username ?? publicData?.identifier,
            primaryEmail: primaryEmail,
            profileImageURL: profileImageURL.flatMap(URL.init(string:))
        )
    }
}
