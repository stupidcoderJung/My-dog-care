import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading your dog care space...")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    LoadingView()
}
