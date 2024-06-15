import CoreData
import Foundation

/// Local sync state for a cached booking — tracks whether a row reflects the server,
/// has unsynced local edits, or is a local creation/deletion still awaiting upload.
enum SyncState: String {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}

/// Bridges between the network/domain `Booking` model and its CoreData cache representation.
extension CachedBooking {
    /// Overwrites all server-owned fields. Used when applying a remote `Booking` — either
    /// from a fresh fetch or as the resolution of a sync conflict.
    func applyServerState(_ booking: Booking) {
        id = booking.id
        listingID = booking.listingID
        listingTitle = booking.listingTitle
        userID = booking.userID
        checkIn = booking.checkIn
        checkOut = booking.checkOut
        totalPrice = booking.totalPrice as NSDecimalNumber
        currencyCode = booking.currencyCode
        status = booking.status.rawValue
        createdAt = booking.createdAt
        updatedAt = booking.updatedAt
        version = Int32(booking.version)
        syncState = SyncState.synced.rawValue
        isPendingDeletion = false
        localUpdatedAt = .now
    }

    func toDomain() -> Booking? {
        guard
            let id, let listingID, let listingTitle, let userID,
            let checkIn, let checkOut, let currencyCode,
            let statusRaw = status, let status = BookingStatus(rawValue: statusRaw),
            let createdAt, let updatedAt
        else { return nil }

        return Booking(
            id: id,
            listingID: listingID,
            listingTitle: listingTitle,
            userID: userID,
            checkIn: checkIn,
            checkOut: checkOut,
            totalPrice: (totalPrice ?? 0) as Decimal,
            currencyCode: currencyCode,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: Int(version)
        )
    }

    var resolvedSyncState: SyncState {
        SyncState(rawValue: syncState ?? SyncState.synced.rawValue) ?? .synced
    }
}
