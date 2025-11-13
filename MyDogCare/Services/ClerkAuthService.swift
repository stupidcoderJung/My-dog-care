import Foundation
import Clerk

@MainActor
protocol ClerkAuthServicing {
    func restoreLastActiveSession() async throws -> Session
    func signIn(email: String, password: String) async throws -> Session
    func presentSignUp() async throws
    func signOut() async throws
}

enum ClerkAuthError: Error {
    case noActiveSession
    case signInIncomplete(SignIn.Status)
    case missingSessionIdentifier
    case unsupportedPlatform
}

extension ClerkAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "현재 로그인된 세션이 없습니다."
        case .signInIncomplete(let status):
            let message: String
            switch status {
            case .needsFirstFactor:
                message = "추가 인증이 필요합니다. 이메일이나 다른 인증 수단을 확인해주세요."
            case .needsSecondFactor:
                message = "2단계 인증이 필요합니다. 설정된 인증 방법을 완료해주세요."
            case .needsIdentifier:
                message = "계정 식별 정보가 필요합니다. 이메일 또는 사용자 이름을 다시 확인해주세요."
            case .needsNewPassword:
                message = "새 비밀번호를 설정해야 합니다."
            case .complete:
                message = "로그인을 완료하지 못했습니다."
            case .unknown:
                message = "로그인을 완료하지 못했습니다."
            }
            return message
        case .missingSessionIdentifier:
            return "세션 정보가 확인되지 않았습니다."
        case .unsupportedPlatform:
            return "이 플랫폼에서는 Clerk 가입 화면을 표시할 수 없습니다."
        }
    }
}

@MainActor
final class ClerkAuthService: ClerkAuthServicing {
    static let shared = ClerkAuthService()

    private let publishableKey: String
    private var isConfigured = false

    init(publishableKey: String = Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String ?? "YOUR_PUBLISHABLE_KEY") {
        self.publishableKey = publishableKey
    }

    private func configureIfNeeded() async throws {
        guard !isConfigured else { return }
        Clerk.shared.configure(publishableKey: publishableKey)
        try await Clerk.shared.load()
        isConfigured = true
    }

    func restoreLastActiveSession() async throws -> Session {
        try await configureIfNeeded()
        guard let session = Clerk.shared.session else {
            throw ClerkAuthError.noActiveSession
        }
        return session
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await configureIfNeeded()

        let signIn = try await SignIn.create(strategy: .identifier(email, password: password))
        let completedSignIn: SignIn

        switch signIn.status {
        case .complete:
            completedSignIn = signIn
        case .needsFirstFactor:
            completedSignIn = try await signIn.attemptFirstFactor(strategy: .password(password: password))
            guard completedSignIn.status == .complete else {
                throw ClerkAuthError.signInIncomplete(completedSignIn.status)
            }
        default:
            throw ClerkAuthError.signInIncomplete(signIn.status)
        }

        guard let sessionId = completedSignIn.createdSessionId else {
            throw ClerkAuthError.missingSessionIdentifier
        }

        try await Clerk.shared.setActive(sessionId: sessionId)
        guard let activeSession = Clerk.shared.session else {
            throw ClerkAuthError.noActiveSession
        }
        return activeSession
    }

    func presentSignUp() async throws {
        try await configureIfNeeded()
#if canImport(UIKit)
        guard let rootViewController = UIApplication.sharedOrNil?.topMostViewController() else {
            throw NSError(
                domain: "Clerk",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Unable to find a presentation context for Clerk AuthView."]
            )
        }

        let hostingController = UIHostingController(rootView: AuthView(mode: .signUp))
        hostingController.modalPresentationStyle = .formSheet
        rootViewController.present(hostingController, animated: true)
#else
        throw ClerkAuthError.unsupportedPlatform
#endif
    }

    func signOut() async throws {
        try await configureIfNeeded()
        try await Clerk.shared.signOut()
    }
}

#if canImport(UIKit)
import SwiftUI
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
