import SwiftUI

struct SettingsView: View {
    let session: SignedInSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    HStack {
                        AsyncAvatarView(imageURL: session.profileImageURL)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.displayName)
                                .font(.headline)
                            Text(session.primaryEmail ?? "No email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Preferences")) {
                    Toggle(isOn: .constant(true)) {
                        Label("Daily summary notifications", systemImage: "bell.badge")
                    }
                    Toggle(isOn: .constant(false)) {
                        Label("Low food reminders", systemImage: "bag")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(session: .preview)
        .environmentObject(AuthViewModel(isPreview: true))
}
