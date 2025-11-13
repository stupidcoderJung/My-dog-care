import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authService: ClerkAuthService
    @State private var isPresentingSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.orange)

            Text("Welcome to My Dog Care")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Sign in with your Clerk account to sync your dog's routines and preferences.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button(action: { isPresentingSheet = true }) {
                Label("Sign in with Clerk", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $isPresentingSheet) {
                ClerkHostedAuthView()
                    .environmentObject(authService)
            }
        }
        .padding()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(ClerkAuthService.preview)
}
