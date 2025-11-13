import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authService: ClerkAuthService

    var body: some View {
        Group {
            switch authService.sessionState {
            case .loading:
                LoadingView()
            case .needsSignIn:
                AuthenticationView()
            case let .signedIn(session):
                MainTabView(session: session)
            case let .error(message):
                ErrorStateView(message: message) {
                    Task {
                        await authService.configure(force: true)
                    }
                }
            }
        }
        .animation(.easeInOut, value: authService.sessionState)
    }
}

#Preview {
    RootView()
        .environmentObject(ClerkAuthService.preview)
}
