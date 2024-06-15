import SwiftUI

/// Shows the signed-in user's reservations, synced offline-first via `SyncManager`.
/// Surfaces a connectivity banner and supports swipe-to-cancel with confirmation.
struct MyBookingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var box = MyBookingsViewModelBox()
    @State private var bookingPendingCancellation: Booking?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Bookings")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Log Out") { authViewModel.logout() }
                            .accessibilityHint("Signs you out of DormFinder")
                    }
                }
                .task {
                    if box.vm == nil {
                        box.vm = MyBookingsViewModel(syncManager: environment.syncManager, networkMonitor: environment.networkMonitor)
                    }
                    await box.vm?.loadBookings()
                }
                .confirmationDialog(
                    "Cancel this booking?",
                    isPresented: Binding(get: { bookingPendingCancellation != nil }, set: { if !$0 { bookingPendingCancellation = nil } }),
                    presenting: bookingPendingCancellation
                ) { booking in
                    Button("Cancel Booking", role: .destructive) {
                        Task { await box.vm?.cancelBooking(booking) }
                        bookingPendingCancellation = nil
                    }
                    Button("Keep Booking", role: .cancel) { bookingPendingCancellation = nil }
                } message: { booking in
                    Text("This will cancel your stay at \(booking.listingTitle) for \(booking.dateRangeDescription).")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm = box.vm {
            VStack(spacing: 0) {
                if vm.isOffline {
                    Label("Offline — showing your saved bookings", systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .accessibilityLabel("You're offline. Showing your saved bookings.")
                }

                if let error = vm.cancellationError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                switch vm.loadState {
                case .idle, .loading:
                    ProgressView("Loading bookings…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableMessage(
                        title: "No Bookings Yet",
                        message: "Find a place you like and request to book it — it'll show up here.",
                        systemImage: "calendar.badge.plus"
                    )
                case .loaded:
                    bookingsList(vm: vm)
                }
            }
        } else {
            ProgressView()
        }
    }

    private func bookingsList(vm: MyBookingsViewModel) -> some View {
        List {
            ForEach(vm.bookings) { booking in
                BookingRowView(booking: booking)
                    .swipeActions(edge: .trailing) {
                        if booking.status != .cancelled {
                            Button("Cancel", role: .destructive) {
                                bookingPendingCancellation = booking
                            }
                            .accessibilityLabel("Cancel booking at \(booking.listingTitle)")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .refreshable { await vm.refresh() }
    }
}

/// A single reservation row showing listing, dates, price and status.
private struct BookingRowView: View {
    let booking: Booking

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(booking.listingTitle)
                .font(.headline)

            Text(booking.dateRangeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(booking.status.displayName, systemImage: booking.status.symbolName)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Spacer()
                Text(booking.formattedTotalPrice)
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(booking.listingTitle), \(booking.dateRangeDescription), status \(booking.status.displayName), total \(booking.formattedTotalPrice)")
    }

    private var statusColor: Color {
        switch booking.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .cancelled: return .red
        case .completed: return .secondary
        }
    }
}

@MainActor
private final class MyBookingsViewModelBox: ObservableObject {
    @Published var vm: MyBookingsViewModel?
}

#Preview {
    MyBookingsView()
        .environmentObject(AppEnvironment.preview())
        .environmentObject(AuthViewModel(authService: AppEnvironment.preview().authService))
}
