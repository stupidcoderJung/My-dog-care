import SwiftUI
#if canImport(ClerkSDK)
import ClerkSDK
#endif

struct ClerkSignInView: View {
    var body: some View {
        #if canImport(ClerkSDK)
        ClerkSignInWidget()
        #else
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Sign in to keep caring for your best friend")
                .multilineTextAlignment(.center)
                .font(.title3)
            Button(action: {}) {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
        #endif
    }
}

#if canImport(ClerkSDK)
private struct ClerkSignInWidget: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = ClerkHostedAuthController(flow: .signIn)
        controller.primaryButtonLabel = "Continue"
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}
#endif

struct ClerkSignInView_Previews: PreviewProvider {
    static var previews: some View {
        ClerkSignInView()
    }
}
