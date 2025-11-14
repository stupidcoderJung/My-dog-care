import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                LoadingView(status: authViewModel.loadingMessage)
            case .signedIn(let session):
                MainView(session: session)
            case .signedOut:
                SignInView()
            case .error(let message):
                ErrorView(message: message) {
                    Task { await authViewModel.initialize() }
                }
            }
        }
        .animation(.easeInOut, value: authViewModel.stateIdentifier)
    }
}

struct SignInView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var field: Field?

    enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back!")
                        .font(.largeTitle.bold())
                    Text("Sign in with your Clerk account to continue managing your dog's care schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($field, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { field = .password }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($field, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Button(action: signIn) {
                    HStack {
                        if authViewModel.isPerformingAction {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(authViewModel.isPerformingAction ? "Signing In…" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(authViewModel.isPerformingAction ? Color.gray : Color.accentColor)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(authViewModel.isPerformingAction)

                Button("Need an account? Create one") {
                    Task { await authViewModel.startSignUp() }
                }
                .buttonStyle(.borderless)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { field = nil }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func signIn() {
        Task { await authViewModel.signIn(email: email, password: password) }
    }
}

struct ErrorView: View {
    let message: String
    var retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.title3.bold())

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel(isPreview: true))
        .environmentObject(ModelRegistry.preview())
}
