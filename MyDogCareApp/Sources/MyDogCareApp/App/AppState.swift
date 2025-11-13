import Foundation
import Combine

/// Represents the high-level navigation flow for the application.
enum AppFlow {
    case loading
    case authenticated
    case signedOut
}

/// Stores the global application state and drives navigation based on Clerk authentication.
final class AppState: ObservableObject {
    @Published private(set) var flow: AppFlow = .loading
    @Published private(set) var user: ClerkUser? = nil

    private var cancellables: Set<AnyCancellable> = []
    private let authService: ClerkAuthService

    init(authService: ClerkAuthService = ClerkAuthService.shared) {
        self.authService = authService
    }

    /// Starts listening for Clerk state changes.
    func configure() {
        authService.userPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.user = user
                self?.flow = user == nil ? .signedOut : .authenticated
            }
            .store(in: &cancellables)

        Task { [weak self] in
            await self?.authService.initialize()
        }
    }

    /// Signs the current user out via Clerk.
    func signOut() {
        Task {
            await authService.signOut()
        }
    }
}
