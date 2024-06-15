import SwiftUI

/// Listing detail screen: photo carousel, amenities grid, and an inline booking flow
/// (date pickers, live price estimate, submit). Adapts to size classes so it reads well
/// in both portrait iPhone and landscape/iPad layouts.
struct ListingDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var box = ListingDetailViewModelBox()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let listing: Listing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photoCarousel
                titleBlock
                amenitiesSection
                if let vm = box.vm {
                    BookingFlowView(viewModel: vm)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(listing.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if box.vm == nil {
                box.vm = ListingDetailViewModel(listing: listing, syncManager: environment.syncManager, authService: environment.authService)
            }
        }
    }

    private var photoCarousel: some View {
        TabView {
            if listing.photoURLs.isEmpty {
                placeholderPhoto
            } else {
                ForEach(listing.photoURLs, id: \.self) { url in
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            placeholderPhoto
                        }
                    }
                    .clipped()
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo gallery for \(listing.title), \(listing.photoURLs.count) photos")
    }

    private var placeholderPhoto: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .overlay(Image(systemName: "house.fill").font(.system(size: 44)).foregroundStyle(.secondary))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(listing.title)
                .font(.title2.bold())

            Label(listing.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(listing.formattedPrice + "/mo", systemImage: "dollarsign.circle.fill")
                Label(listing.formattedDistance + " to campus", systemImage: "figure.walk")
                Label(String(format: "%.1f", listing.rating), systemImage: "star.fill")
            }
            .font(.subheadline)
            .labelStyle(.titleAndIcon)

            Text(listing.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amenities")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                ForEach(listing.amenities) { amenity in
                    Label(amenity.name, systemImage: amenity.symbolName)
                        .font(.subheadline)
                        .accessibilityLabel(amenity.name)
                }
            }
            .padding(.horizontal)
        }
    }

    private var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), alignment: .leading), count: count)
    }
}

/// Defers `ListingDetailViewModel` construction until `environment` is injected.
@MainActor
private final class ListingDetailViewModelBox: ObservableObject {
    @Published var vm: ListingDetailViewModel?
}

#Preview {
    NavigationStack {
        ListingDetailView(listing: .preview)
            .environmentObject(AppEnvironment.preview())
            .environmentObject(AuthViewModel(authService: AppEnvironment.preview().authService))
    }
}
