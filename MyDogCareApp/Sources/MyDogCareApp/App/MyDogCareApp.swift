import SwiftUI

@main
struct MyDogCareApp: App {
    @StateObject private var appState = AppState()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    appState.configure()
                }
        }
    }

    private func configureAppearance() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor(named: "AccentColor") ?? UIColor.label
        ]
    }
}
