import SwiftUI

/// Inline booking widget shown on the listing detail screen: date pickers, a live price
/// estimate, and a submit button that surfaces success/failure with VoiceOver-friendly alerts.
struct BookingFlowView: View {
    @ObservedObject var viewModel: ListingDetailViewModel
    @State private var isShowingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Book this place")
                .font(.headline)

            DatePicker(
                "Check-in",
                selection: $viewModel.checkInDate,
                in: viewModel.listing.availableFrom...,
                displayedComponents: .date
            )
            DatePicker(
                "Check-out",
                selection: $viewModel.checkOutDate,
                in: viewModel.checkInDate...,
                displayedComponents: .date
            )

            summaryRow

            submitButton

            if case .failed(let message) = viewModel.submissionState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel(message)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .onChange(of: viewModel.submissionState) { _, newValue in
            if case .succeeded = newValue {
                isShowingConfirmation = true
            }
        }
        .alert("Booking Confirmed", isPresented: $isShowingConfirmation, presenting: confirmedBooking) { _ in
            Button("OK") { viewModel.resetSubmissionState() }
        } message: { booking in
            Text("Your stay at \(booking.listingTitle) from \(booking.dateRangeDescription) has been requested.")
        }
    }

    private var confirmedBooking: Booking? {
        if case .succeeded(let booking) = viewModel.submissionState { return booking }
        return nil
    }

    private var nightCountDescription: String {
        "\(viewModel.nightCount) night\(viewModel.nightCount == 1 ? "" : "s")"
    }

    private var summaryRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(nightCountDescription)
                    .font(.subheadline)
                Text("Estimated total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(viewModel.formattedEstimatedTotal)
                .font(.title3.bold())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nightCountDescription), estimated total \(viewModel.formattedEstimatedTotal)")
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.submitBooking() }
        } label: {
            HStack {
                Spacer()
                if viewModel.submissionState == .submitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Request to Book")
                        .font(.headline)
                }
                Spacer()
            }
            .padding()
            .background(viewModel.isDateRangeValid ? Color.accentColor : Color.gray.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!viewModel.isDateRangeValid || viewModel.submissionState == .submitting)
        .accessibilityLabel("Request to book")
        .accessibilityHint(viewModel.isDateRangeValid ? "Submits a booking request for the selected dates" : "Select a valid date range first")
    }
}

#Preview {
    BookingFlowView(
        viewModel: ListingDetailViewModel(
            listing: .preview,
            syncManager: AppEnvironment.preview().syncManager,
            authService: AppEnvironment.preview().authService
        )
    )
}
