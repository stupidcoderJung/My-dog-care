import SwiftUI

struct MainView: View {
    var user: ClerkUser?
    var onSignOut: () -> Void

    @State private var selectedTab: MainTab = .overview

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header
                TabView(selection: $selectedTab) {
                    overview
                        .tag(MainTab.overview)
                    reminders
                        .tag(MainTab.reminders)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                NavigationLink(destination: SettingsView(onSignOut: onSignOut)) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("My Dog Care")
            .toolbarTitleDisplayMode(.large)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AvatarView(initials: user?.initials ?? "DC")
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(user?.fullName ?? "Dog Lover")
                    .font(.title3.bold())
            }
            Spacer()
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Care Overview")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("Morning walk completed", systemImage: "checkmark.circle.fill")
                Label("Next meal in 2 hours", systemImage: "clock")
                Label("Medication due at 6 PM", systemImage: "pills")
            }
            .labelStyle(HighlightedLabelStyle())
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders")
                .font(.headline)
            ReminderRow(title: "Order more treats", time: "Today")
            ReminderRow(title: "Schedule vet visit", time: "Next week")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

private enum MainTab {
    case overview
    case reminders
}

private struct ReminderRow: View {
    var title: String
    var time: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.tertiaryLabel)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

private struct AvatarView: View {
    var initials: String

    var body: some View {
        Text(initials)
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(Color.accentColor)
            .clipShape(Circle())
    }
}

private struct HighlightedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .foregroundColor(.accentColor)
            configuration.title
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(user: ClerkUser.example, onSignOut: {})
    }
}
