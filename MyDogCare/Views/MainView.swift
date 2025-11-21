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

            MenuTwoView()
                .tabItem {
                    Label("Menu 2", systemImage: "calendar")
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

private struct MenuTwoView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Menu 2")
                    .font(.title.bold())
                Text("Build out this section to keep track of upcoming routines and appointments.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Menu 2")
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
