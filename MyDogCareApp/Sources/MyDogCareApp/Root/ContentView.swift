import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.flow {
        case .loading:
            LoadingView()
        case .signedOut:
            ClerkSignInView()
        case .authenticated:
            MainView(user: appState.user, onSignOut: appState.signOut)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
