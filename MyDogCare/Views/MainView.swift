import SwiftUI

struct MainView: View {
    let session: ClerkAuthService.SessionDetails
    @State private var remindersEnabled = true
    @State private var hydrationLevel: Double = 0.6

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GreetingCard(session: session)
                    DailyChecklistView(remindersEnabled: $remindersEnabled)
                    HydrationTracker(level: $hydrationLevel)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Dogs")
        }
    }
}

private struct GreetingCard: View {
    let session: ClerkAuthService.SessionDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hi, \(session.displayName)")
                .font(.title2.bold())

            Text("Here's what to focus on today.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.1))
        )
    }
}

private struct DailyChecklistView: View {
    @Binding var remindersEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Reminders", isOn: $remindersEnabled)
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                ChecklistRow(title: "Morning walk", isCompleted: true)
                ChecklistRow(title: "Meal prep", isCompleted: false)
                ChecklistRow(title: "Medication", isCompleted: false)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct ChecklistRow: View {
    let title: String
    var isCompleted: Bool

    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? .green : .secondary)
            Text(title)
            Spacer()
        }
        .font(.body)
    }
}

private struct HydrationTracker: View {
    @Binding var level: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration")
                .font(.headline)

            ProgressView(value: level)
                .tint(.blue)

            Slider(value: $level)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    MainView(session: .mock)
}
