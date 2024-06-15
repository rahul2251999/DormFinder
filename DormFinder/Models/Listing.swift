import Foundation
import CoreLocation

/// Type of room offered by a listing.
enum RoomType: String, Codable, CaseIterable, Identifiable {
    case privateRoom = "private"
    case sharedRoom = "shared"
    case studio = "studio"
    case apartment = "apartment"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .privateRoom: return "Private Room"
        case .sharedRoom: return "Shared Room"
        case .studio: return "Studio"
        case .apartment: return "Apartment"
        }
    }
}

/// An amenity badge shown on listing detail (also drives SF Symbol + accessibility label).
struct Amenity: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String

    static let knownSymbols: [String: String] = [
        "wifi": "wifi",
        "laundry": "washer",
        "parking": "car.fill",
        "gym": "dumbbell.fill",
        "kitchen": "fork.knife",
        "air_conditioning": "wind",
        "furnished": "sofa.fill",
        "security": "lock.shield.fill",
        "pet_friendly": "pawprint.fill",
        "study_room": "books.vertical.fill"
    ]
}

/// Core domain model representing a housing listing returned by the API and cached locally.
struct Listing: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let pricePerMonth: Decimal
    let currencyCode: String
    let roomType: RoomType
    let latitude: Double
    let longitude: Double
    let address: String
    let distanceToCampusMeters: Double
    let amenities: [Amenity]
    let photoURLs: [URL]
    let isAvailable: Bool
    let availableFrom: Date
    let rating: Double
    let updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: pricePerMonth as NSDecimalNumber) ?? "\(pricePerMonth)"
    }

    var formattedDistance: String {
        let measurement = Measurement(value: distanceToCampusMeters, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        return formatter.string(from: measurement)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary
        case pricePerMonth = "price_per_month"
        case currencyCode = "currency_code"
        case roomType = "room_type"
        case latitude, longitude, address
        case distanceToCampusMeters = "distance_to_campus_meters"
        case amenities
        case photoURLs = "photo_urls"
        case isAvailable = "is_available"
        case availableFrom = "available_from"
        case rating
        case updatedAt = "updated_at"
    }
}

/// Filter criteria applied to the listing search/browse experience.
struct ListingFilter: Equatable {
    var maxPricePerMonth: Decimal?
    var maxDistanceMeters: Double?
    var roomTypes: Set<RoomType> = []
    var availableOnly: Bool = false
    var searchText: String = ""

    static let `default` = ListingFilter()

    var isActive: Bool {
        self != .default
    }

    func matches(_ listing: Listing) -> Bool {
        if let maxPrice = maxPricePerMonth, listing.pricePerMonth > maxPrice { return false }
        if let maxDistance = maxDistanceMeters, listing.distanceToCampusMeters > maxDistance { return false }
        if !roomTypes.isEmpty && !roomTypes.contains(listing.roomType) { return false }
        if availableOnly && !listing.isAvailable { return false }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = searchText.lowercased()
            let haystack = "\(listing.title) \(listing.address) \(listing.summary)".lowercased()
            if !haystack.contains(needle) { return false }
        }
        return true
    }
}
