import SwiftUI
import SwiftData

/// Shows all trips grouped by month, with running totals.
/// Swipe to delete, tap to edit/complete.
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @Query private var settings: [YearlySettings]

    @State private var selectedTrip: Trip?
    @State private var showingVoiceFlow = false

    private var irsRate: Double {
        let year = Calendar.current.component(.year, from: Date())
        return settings.first { $0.year == year }?.irsRate ?? 0.725
    }

    /// Group trips by month for display.
    private var tripsByMonth: [(String, [Trip])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: trips) { trip in
            formatter.string(from: trip.date)
        }
        return grouped.sorted { lhs, rhs in
            (lhs.value.first?.date ?? .distantPast) > (rhs.value.first?.date ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "car",
                        description: Text("Start logging trips to track your mileage deductions.")
                    )
                } else {
                    ForEach(tripsByMonth, id: \.0) { month, monthTrips in
                        Section {
                            ForEach(monthTrips) { trip in
                                TripRow(trip: trip, irsRate: irsRate)
                                    .onTapGesture {
                                        selectedTrip = trip
                                    }
                            }
                            .onDelete { offsets in
                                deleteTrips(monthTrips: monthTrips, at: offsets)
                            }
                        } header: {
                            let monthMiles = monthTrips.filter(\.isBusiness).reduce(0.0) { $0 + $1.miles }
                            HStack {
                                Text(month)
                                Spacer()
                                Text(String(format: "%.0f mi", monthMiles))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingVoiceFlow = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .fullScreenCover(isPresented: $showingVoiceFlow) {
                VoiceTripFlowView()
            }
        }
    }

    private func deleteTrips(monthTrips: [Trip], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(monthTrips[index])
        }
    }
}

// MARK: - Trip Row

private struct TripRow: View {
    let trip: Trip
    let irsRate: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: trip.category.icon)
                        .foregroundStyle(trip.isBusiness ? .blue : .secondary)
                        .font(.caption)
                    Text("\(trip.startLocationName) → \(trip.endLocationName)")
                        .font(.headline)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(trip.businessPurpose.isEmpty ? trip.category.rawValue : trip.businessPurpose)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !trip.isComplete {
                        Text("IN PROGRESS")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }

                Text(trip.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if trip.isComplete {
                    Text(String(format: "%.1f mi", trip.miles))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if trip.isBusiness {
                        Text(String(format: "$%.2f", trip.deduction(at: irsRate)))
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("—")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
