import SwiftUI
import MapKit
import Combine

/// MapKit browse experience: every listing is plotted as a price-tag annotation; tapping
/// one focuses the map and reveals a detail card with a link into the full detail screen.
struct ListingMapView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var box = MapViewModelBox()

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 37.8719, longitude: -122.2585)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if let vm = box.vm {
                    mapContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if box.vm == nil {
                    let publisher = environment.syncManager.cachedListingsPublisher()
                    box.vm = MapViewModel(listingsPublisher: publisher, initialCenter: Self.defaultCenter)
                    await environment.syncManager.syncAll()
                }
            }
        }
    }

    private func mapContent(vm: MapViewModel) -> some View {
        ZStack(alignment: .bottom) {
            Map(position: Binding(get: { vm.cameraPosition }, set: { vm.cameraPosition = $0 }), selection: Binding(
                get: { vm.selectedListingID },
                set: { newValue in
                    if let newValue, let annotation = vm.annotations.first(where: { $0.id == newValue }) {
                        vm.select(annotation)
                    } else {
                        vm.clearSelection()
                    }
                }
            )) {
                ForEach(vm.annotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        ListingMapPin(annotation: annotation, isSelected: annotation.id == vm.selectedListingID)
                            .onTapGesture { vm.select(annotation) }
                            .accessibilityLabel("\(annotation.title), \(annotation.formattedPrice) per month")
                            .accessibilityAddTraits(.isButton)
                    }
                    .tag(annotation.id)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            if let selected = vm.selectedListing, let listing = environment.syncManager.cachedListings().first(where: { $0.id == selected.id }) {
                NavigationLink {
                    ListingDetailView(listing: listing)
                } label: {
                    SelectedListingCard(listing: listing)
                }
                .buttonStyle(.plain)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: vm.selectedListingID)
    }
}

/// Custom map pin showing the price; scales up and changes tint when selected.
private struct ListingMapPin: View {
    let annotation: ListingAnnotation
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(annotation.formattedPrice)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(.systemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1))

            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(180))
                .foregroundStyle(isSelected ? Color.accentColor : Color(.systemBackground))
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
    }
}

/// Bottom sheet-style summary card for the selected annotation, linking into the detail screen.
private struct SelectedListingCard: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "house.fill").foregroundStyle(.secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("\(listing.formattedPrice)/mo · \(listing.formattedDistance) to campus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(listing.title), \(listing.formattedPrice) per month, \(listing.formattedDistance) from campus. Double tap to view details.")
    }
}

@MainActor
private final class MapViewModelBox: ObservableObject {
    @Published var vm: MapViewModel?
}

extension SyncManager {
    /// Republishes the cached-listings snapshot whenever CoreData saves, so the map
    /// (and other read-through consumers) update reactively without polling.
    func cachedListingsPublisher() -> AnyPublisher<[Listing], Never> {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .map { [weak self] _ in self?.cachedListings() ?? [] }
            .prepend(cachedListings())
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

#Preview {
    ListingMapView()
        .environmentObject(AppEnvironment.preview())
}
