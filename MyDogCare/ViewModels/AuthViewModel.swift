import Foundation
import SwiftUI
import ClerkSDK

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
    }

    func initialize() async {
        state = .loading
        loadingMessage = "Connecting to Clerk…"
        do {
            let session = try await authService.restoreLastActiveSession()
            state = .signedIn(makeSession(from: session))
        } catch ClerkAuthError.noActiveSession {
            state = .signedOut
        } catch {
            state = .error(error.localizedDescription)
        }
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

    private func makeSession(from clerkSession: ClerkSession) -> SignedInSession {
        let user = clerkSession.user
        let primaryEmail = user.primaryEmailAddressId.flatMap { id in
            user.emailAddresses.first(where: { $0.id == id })?.emailAddress
        } ?? user.emailAddresses.first?.emailAddress

        return SignedInSession(
            id: clerkSession.id,
            firstName: user.firstName,
            lastName: user.lastName,
            username: user.username,
            primaryEmail: primaryEmail,
            profileImageURL: user.profileImageURL
        )
    }
}
