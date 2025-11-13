import SwiftUI

struct MainTabView: View {
    let session: ClerkAuthService.SessionDetails

    var body: some View {
        TabView {
            MainView(session: session)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SettingsView(session: session)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView(session: .mock)
}
