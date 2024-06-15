import SwiftUI

/// A single row in the listings list. Uses `AsyncImage` for the thumbnail and composes
/// VoiceOver content into one coherent announcement instead of reading each label separately.
struct ListingRowView: View {
    let listing: Listing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(listing.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(listing.formattedPrice + "/mo", systemImage: "dollarsign.circle")
                    Label(listing.formattedDistance, systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

                HStack(spacing: 6) {
                    statusBadge
                    Text(listing.roomType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var thumbnail: some View {
        AsyncImage(url: listing.photoURLs.first) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholderThumbnail
            case .empty:
                placeholderThumbnail.overlay(ProgressView())
            @unknown default:
                placeholderThumbnail
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay(Image(systemName: "house.fill").foregroundStyle(.secondary))
    }

    private var statusBadge: some View {
        Label(listing.isAvailable ? "Available" : "Unavailable", systemImage: listing.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.caption2)
            .foregroundStyle(listing.isAvailable ? .green : .red)
            .labelStyle(.titleAndIcon)
    }

    private var accessibilitySummary: String {
        let availability = listing.isAvailable ? "Available" : "Currently unavailable"
        return "\(listing.title), \(listing.roomType.displayName), \(listing.formattedPrice) per month, \(listing.formattedDistance) from campus. \(availability)."
    }
}

#Preview {
    List {
        ListingRowView(listing: .preview)
    }
}

extension Listing {
    static let preview = Listing(
        id: "preview-1",
        title: "Sunny Studio Near Campus",
        summary: "A bright studio five minutes from the quad, fully furnished with everything you need.",
        pricePerMonth: 950,
        currencyCode: "USD",
        roomType: .studio,
        latitude: 37.8719,
        longitude: -122.2585,
        address: "123 University Ave, Berkeley, CA",
        distanceToCampusMeters: 450,
        amenities: [
            Amenity(id: "wifi", name: "WiFi", symbolName: "wifi"),
            Amenity(id: "laundry", name: "Laundry", symbolName: "washer"),
            Amenity(id: "furnished", name: "Furnished", symbolName: "sofa.fill")
        ],
        photoURLs: [],
        isAvailable: true,
        availableFrom: .now,
        rating: 4.6,
        updatedAt: .now
    )
}
