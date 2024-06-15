import CoreData
import Foundation

/// Bridges between the network/domain `Listing` model and its CoreData cache representation.
/// Arrays (`amenities`, `photoURLs`) are stored as encoded JSON blobs since they're small,
/// read-only payloads that don't need to be queried — avoiding a relationship explosion.
extension CachedListing {
    func apply(_ listing: Listing) {
        id = listing.id
        title = listing.title
        summary = listing.summary
        pricePerMonth = listing.pricePerMonth as NSDecimalNumber
        currencyCode = listing.currencyCode
        roomType = listing.roomType.rawValue
        latitude = listing.latitude
        longitude = listing.longitude
        address = listing.address
        distanceToCampusMeters = listing.distanceToCampusMeters
        amenitiesData = (try? JSONEncoder().encode(listing.amenities)) ?? Data()
        photoURLsData = (try? JSONEncoder().encode(listing.photoURLs)) ?? Data()
        isAvailable = listing.isAvailable
        availableFrom = listing.availableFrom
        rating = listing.rating
        updatedAt = listing.updatedAt
        lastSyncedAt = .now
    }

    func toDomain() -> Listing? {
        guard
            let id, let title, let summary, let currencyCode,
            let roomTypeRaw = roomType, let roomType = RoomType(rawValue: roomTypeRaw),
            let address, let availableFrom, let updatedAt
        else { return nil }

        let amenities = (try? JSONDecoder().decode([Amenity].self, from: amenitiesData ?? Data())) ?? []
        let photoURLs = (try? JSONDecoder().decode([URL].self, from: photoURLsData ?? Data())) ?? []

        return Listing(
            id: id,
            title: title,
            summary: summary,
            pricePerMonth: (pricePerMonth ?? 0) as Decimal,
            currencyCode: currencyCode,
            roomType: roomType,
            latitude: latitude,
            longitude: longitude,
            address: address,
            distanceToCampusMeters: distanceToCampusMeters,
            amenities: amenities,
            photoURLs: photoURLs,
            isAvailable: isAvailable,
            availableFrom: availableFrom,
            rating: rating,
            updatedAt: updatedAt
        )
    }
}
