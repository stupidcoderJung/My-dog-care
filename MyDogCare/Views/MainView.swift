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
            MenuOneView(session: session)
                .tabItem {
                    Label("Menu 1", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.menu1)

            MenuTwoView()
                .tabItem {
                    Label("Menu 2", systemImage: "calendar")
                }
                .tag(Tab.menu2)

            MenuThreeView()
                .tabItem {
                    Label("Menu 3", systemImage: "pawprint")
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

private struct MenuOneView: View {
    let session: SignedInSession

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderSection(session: session)
                    RemindersSection()
                    ActivitySection()
                }
                .padding()
            }
            .navigationTitle("Menu 1")
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

private struct MenuThreeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Menu 3")
                    .font(.title.bold())
                Text("Use this area for quick tips, health insights, or anything else your pup needs.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Menu 3")
        }
    }
}

private struct SettingsTabView: View {
    let session: SignedInSession

    var body: some View {
        SettingsView(session: session, displayMode: .embedded)
    }
}

private struct HeaderSection: View {
    let session: SignedInSession

    var body: some View {
        HStack(spacing: 16) {
            AsyncAvatarView(imageURL: session.profileImageURL)
                .frame(width: 64, height: 64)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("Hello, \(session.displayName)!")
                    .font(.title2.bold())
                Text("Here's what's coming up for your pup today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RemindersSection: View {
    let reminders = [
        ("Morning Walk", "08:30", "Take Bella around the block for 20 minutes."),
        ("Vet Appointment", "13:00", "Routine check-up at City Vet Clinic."),
        ("Evening Feeding", "18:30", "Serve 1 cup of kibble with supplements.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Reminders")
                .font(.headline)
            ForEach(reminders, id: \.0) { reminder in
                HStack(alignment: .top, spacing: 16) {
                    VStack {
                        Text(reminder.1)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.0)
                            .font(.subheadline.bold())
                        Text(reminder.2)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActivitySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Overview")
                .font(.headline)
            HStack(spacing: 16) {
                ActivityCard(title: "Walks", value: "2/3", systemImage: "figure.walk")
                ActivityCard(title: "Meals", value: "1/2", systemImage: "fork.knife")
                ActivityCard(title: "Medications", value: "0/1", systemImage: "pills")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActivityCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    MainView(session: .preview)
}
