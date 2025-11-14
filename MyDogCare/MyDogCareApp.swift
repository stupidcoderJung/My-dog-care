import SwiftUI

@main
struct MyDogCareApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    private let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    await authViewModel.initialize()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                saveContext()
            }
        }
    }

    private func saveContext() {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}
