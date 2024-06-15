import Foundation
import Combine

/// Drives the listing detail screen, including the inline booking flow:
/// date selection, price calculation, validation, and submission via the sync manager
/// (so a booking made offline is queued and shown immediately).
@MainActor
final class ListingDetailViewModel: ObservableObject {
    enum BookingSubmissionState: Equatable {
        case idle
        case submitting
        case succeeded(Booking)
        case failed(String)
    }

    let listing: Listing

    @Published var checkInDate: Date
    @Published var checkOutDate: Date
    @Published private(set) var submissionState: BookingSubmissionState = .idle

    private let syncManager: SyncManager
    private let authService: AuthServiceProtocol

    init(listing: Listing, syncManager: SyncManager, authService: AuthServiceProtocol) {
        self.listing = listing
        self.syncManager = syncManager
        self.authService = authService

        let calendar = Calendar.current
        let start = max(listing.availableFrom, .now)
        self.checkInDate = start
        self.checkOutDate = calendar.date(byAdding: .day, value: 7, to: start) ?? start
    }

    var nightCount: Int {
        max(Calendar.current.dateComponents([.day], from: checkInDate, to: checkOutDate).day ?? 0, 0)
    }

    var isDateRangeValid: Bool {
        nightCount > 0 && checkInDate >= Calendar.current.startOfDay(for: .now)
    }

    var estimatedTotal: Decimal {
        guard nightCount > 0 else { return 0 }
        let monthlyAsDaily = listing.pricePerMonth / 30
        return (monthlyAsDaily * Decimal(nightCount)).rounded(scale: 2)
    }

    var formattedEstimatedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = listing.currencyCode
        return formatter.string(from: estimatedTotal as NSDecimalNumber) ?? "\(estimatedTotal)"
    }

    func submitBooking() async {
        guard isDateRangeValid else {
            submissionState = .failed("Choose a valid date range of at least one night.")
            return
        }
        guard let userID = authService.currentSession?.userID else {
            submissionState = .failed("Please log in to book a listing.")
            return
        }

        submissionState = .submitting
        let request = BookingRequest(listingID: listing.id, checkIn: checkInDate, checkOut: checkOutDate)

        do {
            let booking = try await syncManager.createBooking(request, listingTitle: listing.title, userID: userID)
            submissionState = .succeeded(booking)
        } catch {
            submissionState = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't complete the booking. It will retry automatically when you're back online.")
        }
    }

    func resetSubmissionState() {
        submissionState = .idle
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var mutableSelf = self
        NSDecimalRound(&result, &mutableSelf, scale, .plain)
        return result
    }
}
