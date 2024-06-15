import SwiftUI

/// Modal sheet for adjusting search filters: max price, max distance, room type, and availability.
/// All controls use system components so Dynamic Type and VoiceOver behavior come for free.
struct FilterView: View {
    @Binding var filter: ListingFilter
    @Environment(\.dismiss) private var dismiss

    @State private var maxPrice: Double
    @State private var maxDistanceKilometers: Double
    @State private var selectedRoomTypes: Set<RoomType>
    @State private var availableOnly: Bool

    private static let priceRange: ClosedRange<Double> = 200...5000
    private static let distanceRangeKm: ClosedRange<Double> = 0.5...20

    init(filter: Binding<ListingFilter>) {
        _filter = filter
        let current = filter.wrappedValue
        _maxPrice = State(initialValue: Double(truncating: (current.maxPricePerMonth ?? 5000) as NSDecimalNumber))
        _maxDistanceKilometers = State(initialValue: (current.maxDistanceMeters ?? 20_000) / 1000)
        _selectedRoomTypes = State(initialValue: current.roomTypes)
        _availableOnly = State(initialValue: current.availableOnly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Price") {
                    Stepper(value: $maxPrice, in: Self.priceRange, step: 50) {
                        Text("Up to \(Int(maxPrice).formatted(.currency(code: "USD").precision(.fractionLength(0))))/mo")
                    }
                    .accessibilityValue("Up to \(Int(maxPrice)) dollars per month")
                }

                Section("Distance from campus") {
                    Stepper(value: $maxDistanceKilometers, in: Self.distanceRangeKm, step: 0.5) {
                        Text("Within \(maxDistanceKilometers.formatted(.number.precision(.fractionLength(1)))) km")
                    }
                    .accessibilityValue("Within \(maxDistanceKilometers.formatted(.number.precision(.fractionLength(1)))) kilometers")
                }

                Section("Room type") {
                    ForEach(RoomType.allCases) { type in
                        Toggle(type.displayName, isOn: binding(for: type))
                    }
                }

                Section {
                    Toggle("Available now only", isOn: $availableOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { resetToDefaults() }
                        .accessibilityHint("Clears all filters")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func binding(for roomType: RoomType) -> Binding<Bool> {
        Binding(
            get: { selectedRoomTypes.contains(roomType) },
            set: { isOn in
                if isOn { selectedRoomTypes.insert(roomType) } else { selectedRoomTypes.remove(roomType) }
            }
        )
    }

    private func resetToDefaults() {
        maxPrice = Self.priceRange.upperBound
        maxDistanceKilometers = Self.distanceRangeKm.upperBound
        selectedRoomTypes = []
        availableOnly = false
    }

    private func applyAndDismiss() {
        filter.maxPricePerMonth = maxPrice >= Self.priceRange.upperBound ? nil : Decimal(maxPrice)
        filter.maxDistanceMeters = maxDistanceKilometers >= Self.distanceRangeKm.upperBound ? nil : maxDistanceKilometers * 1000
        filter.roomTypes = selectedRoomTypes
        filter.availableOnly = availableOnly
        dismiss()
    }
}

#Preview {
    FilterView(filter: .constant(.default))
}
