import SwiftUI
import ClerkSDK
import UIKit

struct ClerkHostedAuthView: UIViewControllerRepresentable {
    @EnvironmentObject private var authService: ClerkAuthService

    func makeUIViewController(context: Context) -> UINavigationController {
        guard let controller = Clerk.shared?.signInController() else {
            let fallback = UIViewController()
            fallback.view.backgroundColor = .systemBackground
            fallback.title = "Sign In"
            let label = UILabel()
            label.text = "Unable to load Clerk sign-in."
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            fallback.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: fallback.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: fallback.view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: fallback.view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(lessThanOrEqualTo: fallback.view.trailingAnchor, constant: -24)
            ])
            return UINavigationController(rootViewController: fallback)
        }

        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.prefersLargeTitles = true
        navigation.presentationController?.delegate = context.coordinator
        return navigation
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(authService: authService)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        private let authService: ClerkAuthService

        init(authService: ClerkAuthService) {
            self.authService = authService
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            Task {
                await authService.refreshSession()
            }
        }
    }
}
