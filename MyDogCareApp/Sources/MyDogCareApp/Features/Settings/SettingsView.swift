import SwiftUI

struct SettingsView: View {
    var onSignOut: () -> Void

    var body: some View {
        List {
            Section(header: Text("Account")) {
                Button(role: .destructive) {
                    onSignOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section(header: Text("Notifications")) {
                Toggle(isOn: .constant(true)) {
                    Label("Daily reminders", systemImage: "bell")
                }
                Toggle(isOn: .constant(false)) {
                    Label("Training tips", systemImage: "pawprint")
                }
            }

            Section(header: Text("Support")) {
                Link(destination: URL(string: "https://example.com/support")!) {
                    Label("Contact us", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView(onSignOut: {})
        }
    }
}
