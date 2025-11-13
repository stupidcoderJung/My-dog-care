import Foundation
import ClerkSDK

protocol ClerkAuthServicing {
    func restoreLastActiveSession() async throws -> ClerkSession
    func signIn(email: String, password: String) async throws -> ClerkSession
    func presentSignUp() async throws
    func signOut() async throws
}

enum ClerkAuthError: Error {
    case noActiveSession
}

final class ClerkAuthService: ClerkAuthServicing {
    static let shared = ClerkAuthService()

    private let publishableKey: String
    private var isConfigured = false

    init(publishableKey: String = "YOUR_PUBLISHABLE_KEY") {
        self.publishableKey = publishableKey
    }

    private func configureIfNeeded() async throws {
        guard !isConfigured else { return }
        try await Clerk.shared.initialize(withPublishableKey: publishableKey)
        isConfigured = true
    }

    func restoreLastActiveSession() async throws -> ClerkSession {
        try await configureIfNeeded()
        guard let session = Clerk.shared.lastActiveSession else {
            throw ClerkAuthError.noActiveSession
        }
        return session
    }

    func signIn(email: String, password: String) async throws -> ClerkSession {
        try await configureIfNeeded()
        let result = try await Clerk.shared.signIn(identifier: email, password: password)
        guard let session = result.session else {
            throw ClerkAuthError.noActiveSession
        }
        return session
    }

    func presentSignUp() async throws {
        try await configureIfNeeded()
#if canImport(UIKit)
        guard let rootViewController = UIApplication.sharedOrNil?.topMostViewController() else {
            throw NSError(domain: "Clerk", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to present sign up interface."])
        }
        try await Clerk.shared.presentSignUp(from: rootViewController)
#else
        throw NSError(domain: "Clerk", code: 0, userInfo: [NSLocalizedDescriptionKey: "Sign up presentation is only available on UIKit platforms."])
#endif
    }

    func signOut() async throws {
        try await configureIfNeeded()
        try await Clerk.shared.signOut()
    }
}

#if canImport(UIKit)
import UIKit

private extension UIApplication {
    static var sharedOrNil: UIApplication? {
        UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication
    }

    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseController = base ?? connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController

        if let navigation = baseController as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController()
        }
        if let tab = baseController as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        if let presented = baseController?.presentedViewController {
            return presented.topMostViewController()
        }
        return baseController
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        return self
    }
}
#endif
