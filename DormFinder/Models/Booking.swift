import Foundation

/// Status of a booking, mirrored from the backend and used to drive UI state and sync.
enum BookingStatus: String, Codable, CaseIterable {
    case pending
    case confirmed
    case cancelled
    case completed

    var displayName: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .pending: return "clock.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .completed: return "flag.checkered"
        }
    }
}

/// A user's reservation for a listing over a date range.
struct Booking: Codable, Identifiable, Hashable {
    let id: String
    let listingID: String
    let listingTitle: String
    let userID: String
    let checkIn: Date
    let checkOut: Date
    let totalPrice: Decimal
    let currencyCode: String
    let status: BookingStatus
    let createdAt: Date
    let updatedAt: Date

    /// Monotonic version used for last-write-wins conflict resolution during sync.
    let version: Int

    var formattedTotalPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: totalPrice as NSDecimalNumber) ?? "\(totalPrice)"
    }

    var dateRangeDescription: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: checkIn, to: checkOut)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case listingID = "listing_id"
        case listingTitle = "listing_title"
        case userID = "user_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
        case totalPrice = "total_price"
        case currencyCode = "currency_code"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case version
    }
}

/// Payload sent to the API to create a new booking.
struct BookingRequest: Codable {
    let listingID: String
    let checkIn: Date
    let checkOut: Date

    enum CodingKeys: String, CodingKey {
        case listingID = "listing_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
    }
}
