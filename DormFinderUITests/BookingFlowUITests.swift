import XCTest

/// End-to-end UI test covering the core booking journey: log in, browse listings,
/// open a detail screen, request a booking, and confirm it appears in My Bookings.
///
/// Requires the app to be launched with the `UI-TESTING` argument, which the app uses
/// (see `DormFinderApp`) to wire up an in-memory CoreData stack and mock services seeded
/// with deterministic fixture data — so the test doesn't depend on a live backend.
final class BookingFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["UI-TESTING"]
        app.launch()
    }

    func test_loginBrowseAndBookListing_appearsInMyBookings() throws {
        logIn()
        openFirstListing()
        requestBooking()
        verifyBookingAppearsInMyBookings()
    }

    // MARK: - Steps

    private func logIn() {
        let emailField = app.textFields["Email address"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("student@university.edu")

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")

        let loginButton = app.buttons["Log in"]
        XCTAssertTrue(loginButton.isEnabled)
        loginButton.tap()
    }

    private func openFirstListing() {
        let browseTab = app.tabBars.buttons["Browse listings"]
        XCTAssertTrue(browseTab.waitForExistence(timeout: 5))
        browseTab.tap()

        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
    }

    private func requestBooking() {
        let bookButton = app.buttons["Request to book"]
        XCTAssertTrue(bookButton.waitForExistence(timeout: 5))
        XCTAssertTrue(bookButton.isEnabled)
        bookButton.tap()

        let confirmationAlert = app.alerts["Booking Confirmed"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 5))
        confirmationAlert.buttons["OK"].tap()
    }

    private func verifyBookingAppearsInMyBookings() {
        let bookingsTab = app.tabBars.buttons["My bookings"]
        bookingsTab.tap()

        let firstBookingRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstBookingRow.waitForExistence(timeout: 5))
        XCTAssertTrue(firstBookingRow.label.contains("status Pending") || firstBookingRow.label.contains("status Confirmed"))
    }
}
