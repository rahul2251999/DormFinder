import SwiftUI

/// Combined login/signup screen. The mode toggle keeps both flows on one screen so
/// VoiceOver users don't lose context when switching between them.
struct AuthView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password, fullName, university
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(spacing: 16) {
                        emailField
                        passwordField
                        if viewModel.mode == .signup {
                            fullNameField
                            universityField
                        }
                    }

                    if case .failed(let message) = viewModel.formState {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityAddTraits(.isStaticText)
                    }

                    submitButton
                    toggleModeButton
                }
                .padding()
            }
            .navigationTitle("DormFinder")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.mode == .login ? "Welcome back" : "Create your account")
                .font(.title.bold())
            Text(viewModel.mode == .login
                 ? "Log in to find your next dorm."
                 : "Sign up with your university email to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var emailField: some View {
        TextField("Email", text: $viewModel.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Email address")
    }

    private var passwordField: some View {
        SecureField("Password (min. 8 characters)", text: $viewModel.password)
            .textContentType(viewModel.mode == .login ? .password : .newPassword)
            .focused($focusedField, equals: .password)
            .submitLabel(viewModel.mode == .login ? .go : .next)
            .onSubmit {
                if viewModel.mode == .signup {
                    focusedField = .fullName
                } else {
                    Task { await viewModel.submit() }
                }
            }
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Password")
            .accessibilityHint("At least 8 characters")
    }

    private var fullNameField: some View {
        TextField("Full name", text: $viewModel.fullName)
            .textContentType(.name)
            .focused($focusedField, equals: .fullName)
            .submitLabel(.next)
            .onSubmit { focusedField = .university }
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Full name")
    }

    private var universityField: some View {
        TextField("University (optional)", text: $viewModel.university)
            .textContentType(.organizationName)
            .focused($focusedField, equals: .university)
            .submitLabel(.go)
            .onSubmit { Task { await viewModel.submit() } }
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("University, optional")
    }

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.submit() }
        } label: {
            HStack {
                Spacer()
                if viewModel.formState == .submitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.mode == .login ? "Log In" : "Sign Up")
                        .font(.headline)
                }
                Spacer()
            }
            .padding()
            .background(viewModel.isFormValid ? Color.accentColor : Color.gray.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!viewModel.isFormValid || viewModel.formState == .submitting)
        .accessibilityLabel(viewModel.mode == .login ? "Log in" : "Sign up")
        .accessibilityHint(viewModel.isFormValid ? "" : "Enter a valid email and an 8 character password to continue")
    }

    private var toggleModeButton: some View {
        Button {
            viewModel.toggleMode()
        } label: {
            Text(viewModel.mode == .login
                 ? "Don't have an account? Sign up"
                 : "Already have an account? Log in")
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHint("Switches between login and sign up forms")
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel(authService: AppEnvironment.preview().authService))
}
