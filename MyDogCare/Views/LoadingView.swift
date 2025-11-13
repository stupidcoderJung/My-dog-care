import SwiftUI

struct LoadingView: View {
    let status: String

    init(status: String = "Initializing...") {
        self.status = status
    }

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.accentColor)
                .scaleEffect(1.4)
            Text(status)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView(status: "Connecting to Clerk…")
}
