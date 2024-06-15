import SwiftUI

/// Browse/search screen: a searchable, filterable list of listings that's cache-first —
/// it shows whatever's stored locally instantly, then refreshes from the network.
struct ListingListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: ListingListViewModelBox = ListingListViewModelBox()
    @State private var isShowingFilters = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Listings")
                .searchable(text: searchBinding, prompt: "Search by name or address")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isShowingFilters = true
                        } label: {
                            Label("Filters", systemImage: viewModel.vm?.filter.isActive == true ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel("Filter listings")
                        .accessibilityHint(viewModel.vm?.filter.isActive == true ? "Filters are active" : "No filters applied")
                    }
                }
                .sheet(isPresented: $isShowingFilters) {
                    if let vm = viewModel.vm {
                        FilterView(filter: Binding(get: { vm.filter }, set: { vm.filter = $0 }))
                    }
                }
                .task {
                    if viewModel.vm == nil {
                        viewModel.vm = ListingListViewModel(syncManager: environment.syncManager)
                    }
                    await viewModel.vm?.loadListings()
                }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.vm?.filter.searchText ?? "" },
            set: { viewModel.vm?.filter.searchText = $0 }
        )
    }

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel.vm {
            switch vm.loadState {
            case .idle, .loading:
                ProgressView("Loading listings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableMessage(
                    title: "No Listings",
                    message: message,
                    systemImage: "wifi.slash"
                )
            case .loaded:
                listingList(vm: vm)
            }
        } else {
            ProgressView()
        }
    }

    private func listingList(vm: ListingListViewModel) -> some View {
        List {
            if vm.isShowingCachedData {
                Label("Showing saved results — connect to the internet to refresh", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Showing saved results. Connect to the internet to refresh.")
            }

            ForEach(vm.filteredListings) { listing in
                NavigationLink {
                    ListingDetailView(listing: listing)
                } label: {
                    ListingRowView(listing: listing)
                }
            }

            if vm.filteredListings.isEmpty {
                ContentUnavailableMessage(
                    title: "No Matches",
                    message: "Try adjusting your filters or search terms.",
                    systemImage: "magnifyingglass"
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.refresh() }
    }
}

/// `ObservableObject` box that lets us defer creating the view model until `environment`
/// is available from `@EnvironmentObject`, while keeping the view model itself injectable for tests.
@MainActor
private final class ListingListViewModelBox: ObservableObject {
    @Published var vm: ListingListViewModel?
}

/// Reusable empty/error state view, mirroring `ContentUnavailableView` for pre-iOS 17 compatibility
/// and consistent accessibility behavior (combined element so VoiceOver reads it as one message).
struct ContentUnavailableMessage: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ListingListView()
        .environmentObject(AppEnvironment.preview())
}
