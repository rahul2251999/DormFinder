import XCTest
import Combine
@testable import DormFinder

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_isFormValid_requiresEmailAndLongPassword() {
        let viewModel = AuthViewModel(authService: MockAuthService())

        viewModel.email = "not-an-email"
        viewModel.password = "short"
        XCTAssertFalse(viewModel.isFormValid)

        viewModel.email = "student@university.edu"
        viewModel.password = "longenoughpassword"
        XCTAssertTrue(viewModel.isFormValid)
    }

    func test_isFormValid_signupAlsoRequiresFullName() {
        let viewModel = AuthViewModel(authService: MockAuthService())
        viewModel.mode = .signup
        viewModel.email = "student@university.edu"
        viewModel.password = "longenoughpassword"

        XCTAssertFalse(viewModel.isFormValid, "Signup should require a full name")

        viewModel.fullName = "Jamie Rivera"
        XCTAssertTrue(viewModel.isFormValid)
    }

    func test_submit_onSuccess_publishesAuthenticatedState() async {
        let mockAuth = MockAuthService()
        mockAuth.userToReturn = .stub()
        let viewModel = AuthViewModel(authService: mockAuth)
        viewModel.email = "student@university.edu"
        viewModel.password = "longenoughpassword"

        let expectation = expectation(description: "becomes authenticated")
        viewModel.$isAuthenticated
            .dropFirst()
            .sink { isAuthenticated in
                if isAuthenticated { expectation.fulfill() }
            }
            .store(in: &cancellables)

        await viewModel.submit()

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.currentUser?.id, "user-1")
        XCTAssertEqual(viewModel.password, "", "Password should be cleared after a successful submission")
    }

    func test_submit_onFailure_setsFailedFormState() async {
        let mockAuth = MockAuthService()
        mockAuth.errorToThrow = NetworkError.requestFailed(statusCode: 401, message: "Invalid credentials")
        let viewModel = AuthViewModel(authService: mockAuth)
        viewModel.email = "student@university.edu"
        viewModel.password = "longenoughpassword"

        await viewModel.submit()

        guard case .failed(let message) = viewModel.formState else {
            return XCTFail("Expected failed form state, got \(viewModel.formState)")
        }
        XCTAssertEqual(message, "Invalid credentials")
    }

    func test_logout_clearsCurrentUser() async {
        let mockAuth = MockAuthService()
        mockAuth.userToReturn = .stub()
        let viewModel = AuthViewModel(authService: mockAuth)
        viewModel.email = "student@university.edu"
        viewModel.password = "longenoughpassword"
        await viewModel.submit()
        XCTAssertNotNil(viewModel.currentUser)

        viewModel.logout()

        XCTAssertNil(viewModel.currentUser)
    }
}
