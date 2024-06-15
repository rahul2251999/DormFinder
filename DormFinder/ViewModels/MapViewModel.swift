import Foundation
import MapKit
import SwiftUI
import Combine

/// Drives the map browse experience: positions the camera, exposes listings as annotations,
/// and tracks the selected annotation for tap-to-detail navigation.
@MainActor
final class MapViewModel: ObservableObject {
    @Published var cameraPosition: MapCameraPosition
    @Published private(set) var annotations: [ListingAnnotation] = []
    @Published var selectedListingID: String?

    private var cancellables = Set<AnyCancellable>()

    init(listingsPublisher: AnyPublisher<[Listing], Never>, initialCenter: CLLocationCoordinate2D) {
        self.cameraPosition = .region(
            MKCoordinateRegion(center: initialCenter, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        )

        listingsPublisher
            .map { listings in listings.map(ListingAnnotation.init) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$annotations)
    }

    var selectedListing: ListingAnnotation? {
        annotations.first { $0.id == selectedListingID }
    }

    func select(_ annotation: ListingAnnotation) {
        selectedListingID = annotation.id
        cameraPosition = .region(
            MKCoordinateRegion(center: annotation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        )
    }

    func clearSelection() {
        selectedListingID = nil
    }
}

/// Lightweight, `Identifiable`/`Hashable` projection of `Listing` for use as a map annotation.
struct ListingAnnotation: Identifiable, Hashable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let formattedPrice: String

    init(listing: Listing) {
        self.id = listing.id
        self.title = listing.title
        self.coordinate = listing.coordinate
        self.formattedPrice = listing.formattedPrice
    }

    static func == (lhs: ListingAnnotation, rhs: ListingAnnotation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
