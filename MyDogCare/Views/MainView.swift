import SwiftUI

struct MainView: View {
    private enum Tab {
        case menu1
        case menu2
        case menu3
        case settings
    }

    let session: SignedInSession

    var body: some View {
        TabView {
            ChatView()
            .tabItem {
                Label("AI Chat", systemImage: "message.fill")
            }
            .tag(Tab.menu1)

            CareCalendarView()
                .tabItem {
                    Label("Care Calendar", systemImage: "calendar")
                }
                .tag(Tab.menu2)

            OnAirView()
                .tabItem {
                    Label("On Air", systemImage: "video.fill")
                }
                .tag(Tab.menu3)

            SettingsTabView(session: session)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}





private struct SettingsTabView: View {
    let session: SignedInSession

    var body: some View {
        SettingsView(session: session, displayMode: .embedded)
    }
}

#Preview {
    MainView(session: .preview)
        .environmentObject(AuthViewModel(isPreview: true))
        .environmentObject(VisionClient())
}
