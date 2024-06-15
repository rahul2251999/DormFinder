import Foundation
import Combine

/// Drives login/signup forms and exposes the app-wide authentication state by mirroring
/// `AuthService.sessionPublisher`. Owned at the app root and injected via environment so
/// every screen can react to sign-in/sign-out.
@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode {
        case login
        case signup
    }

    enum FormState: Equatable {
        case idle
        case submitting
        case failed(String)
    }

    @Published var mode: Mode = .login
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var fullName: String = ""
    @Published var university: String = ""
    @Published private(set) var formState: FormState = .idle

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated: Bool = false

    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthServiceProtocol) {
        self.authService = authService

        authService.sessionPublisher
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)
    }

    var isFormValid: Bool {
        guard email.contains("@"), password.count >= 8 else { return false }
        if mode == .signup { return !fullName.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    func submit() async {
        guard isFormValid else {
            formState = .failed("Please fill in all required fields with a valid email and an 8+ character password.")
            return
        }

        formState = .submitting
        do {
            let user: User
            switch mode {
            case .login:
                user = try await authService.login(email: email, password: password)
            case .signup:
                user = try await authService.signup(
                    email: email,
                    password: password,
                    fullName: fullName,
                    university: university.isEmpty ? nil : university
                )
            }
            currentUser = user
            formState = .idle
            clearForm()
        } catch {
            formState = .failed((error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again.")
        }
    }

    func toggleMode() {
        mode = (mode == .login) ? .signup : .login
        formState = .idle
    }

    func logout() {
        authService.logout()
        currentUser = nil
        clearForm()
    }

    private func clearForm() {
        password = ""
    }
}
