import Combine
import Foundation
#if canImport(ClerkSDK)
import ClerkSDK
#endif

/// Minimal representation of the Clerk user that our UI consumes.
struct ClerkUser: Equatable {
    var id: String
    var fullName: String
    var email: String?

    var initials: String {
        let components = fullName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return initials.isEmpty ? "DC" : initials.map(String.init).joined()
    }
}

extension ClerkUser {
    static let example = ClerkUser(id: "user_123", fullName: "Taylor Bark", email: "taylor@example.com")
}

/// Wraps Clerk SDK calls so the rest of the application can remain testable.
@MainActor
final class ClerkAuthService {
    static let shared = ClerkAuthService()

    private let userSubject = CurrentValueSubject<ClerkUser?, Never>(nil)
    var userPublisher: AnyPublisher<ClerkUser?, Never> { userSubject.eraseToAnyPublisher() }

    private init() {}

    /// Initializes Clerk and starts listening for auth changes.
    func initialize() async {
        #if canImport(ClerkSDK)
        do {
            try await Clerk.shared.configure()
            Clerk.shared.addListener(self)
            if let session = await Clerk.shared.session, let user = session.user {
                userSubject.send(ClerkUser(from: user))
            } else {
                userSubject.send(nil)
            }
        } catch {
            print("Clerk configuration failed: \(error)")
            userSubject.send(nil)
        }
        #else
        // Preview fallback for non-iOS platforms.
        await Task.sleep(500_000_000)
        userSubject.send(.example)
        #endif
    }

    /// Signs the current user out.
    func signOut() async {
        #if canImport(ClerkSDK)
        do {
            try await Clerk.shared.signOut()
            userSubject.send(nil)
        } catch {
            print("Failed to sign out: \(error)")
        }
        #else
        userSubject.send(nil)
        #endif
    }
}

#if canImport(ClerkSDK)
private extension ClerkUser {
    init(from user: Clerk.User) {
        self.init(
            id: user.id,
            fullName: user.fullName ?? user.username ?? "Dog Lover",
            email: user.primaryEmailAddress?.emailAddress
        )
    }
}

extension ClerkAuthService: Clerk.Listener {
    nonisolated func onUserChanged(_ user: Clerk.User?) {
        Task { [weak self] in
            await self?.updateUser(user)
        }
    }

    nonisolated func onSessionChanged(_ session: Clerk.Session?) {
        Task { [weak self] in
            await self?.updateUser(session?.user)
        }
    }

    private func updateUser(_ user: Clerk.User?) async {
        await MainActor.run {
            userSubject.send(user.map(ClerkUser.init(from:)))
        }
    }
}
#endif
