import SwiftUI

@main
struct MyDogCareApp: App {
    @StateObject private var authService = ClerkAuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .task {
                    await authService.configure()
                }
        }
    }
}
