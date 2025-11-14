import SwiftUI

struct SettingsView: View {
    enum DisplayMode {
        case embedded
        case modal
    }

    let session: SignedInSession
    var displayMode: DisplayMode = .embedded

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var modelRegistry: ModelRegistry

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

                Section(header: Text("내 강아지")) {
                    NavigationLink {
                        DogListView()
                    } label: {
                        Label("내 강아지 관리", systemImage: "pawprint")
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

                Section(header: Text("로컬 모델")) {
                    ForEach(modelRegistry.statuses) { status in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(status.descriptor.displayName)
                                    .font(.subheadline)
                                Text(modelStatusSubtitle(for: status))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if status.state == .loading {
                                ProgressView()
                            } else {
                                Image(systemName: status.state.accessorySystemImage)
                                    .foregroundStyle(stateColor(for: status.state))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            if displayMode == .modal {
                                await MainActor.run { dismiss() }
                            }
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if displayMode == .modal {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    private func modelStatusSubtitle(for status: ModelRegistry.Status) -> String {
        switch status.state {
        case .failed:
            return status.subtitle
        default:
            return "\(status.state.statusText) · \(status.subtitle)"
        }
    }

    private func stateColor(for state: ModelRegistry.LoadState) -> Color {
        switch state {
        case .loaded:
            return .green
        case .failed:
            return .orange
        default:
            return .secondary
        }
    }
}

#Preview("Embedded") {
    SettingsView(session: .preview)
        .environmentObject(AuthViewModel(isPreview: true))
        .environmentObject(ModelRegistry.preview())
}

#Preview("Modal") {
    SettingsView(session: .preview, displayMode: .modal)
        .environmentObject(AuthViewModel(isPreview: true))
        .environmentObject(ModelRegistry.preview())
}
