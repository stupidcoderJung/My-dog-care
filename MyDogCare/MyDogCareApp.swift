import SwiftUI

@main
struct MyDogCareApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .task {
                    await authViewModel.initialize()
                }
        }
    }
}
