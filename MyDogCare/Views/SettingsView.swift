import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: ClerkAuthService
    let session: ClerkAuthService.SessionDetails
    @State private var notificationsEnabled = true
    @State private var preferredVet = "Happy Paws Clinic"

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(session.displayName)
                                .font(.headline)
                            if let email = session.emailAddress {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        Task { await authService.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("Preferences") {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    TextField("Preferred veterinarian", text: $preferredVet)
                }

                Section("Support") {
                    Link(destination: URL(string: "https://clerk.com")!) {
                        Label("Manage Clerk account", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(session: .mock)
        .environmentObject(ClerkAuthService.preview)
}
