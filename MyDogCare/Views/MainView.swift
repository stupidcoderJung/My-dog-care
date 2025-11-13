import SwiftUI

struct MainView: View {
    let session: SignedInSession
    @State private var isPresentingSettings = false

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
            .navigationTitle("My Dog Care")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingSettings.toggle() }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView(session: session)
            }
        }
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
                .foregroundStyle(.accentColor)
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
