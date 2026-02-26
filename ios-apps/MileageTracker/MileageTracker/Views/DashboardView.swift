import SwiftUI
import SwiftData

/// The main screen — shows tax savings at a glance and a big "Start Trip" button.
/// Designed to be glanceable while driving (large text, high contrast).
///
/// Supports two Siri flows:
/// - "Start a trip" → launches Start Trip voice flow
/// - "End trip" → finds most recent in-progress trip and launches End Trip voice flow
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.date, order: .reverse) private var trips: [Trip]
    @Query private var settings: [YearlySettings]

    @State private var showingVoiceFlow = false
    @State private var showingEndTripFlow = false
    @State private var tripToEnd: Trip?
    @State private var showNoTripAlert = false

    @AppStorage("launchIntoVoiceFlow") private var launchIntoVoiceFlow = false
    @AppStorage("launchIntoEndTripFlow") private var launchIntoEndTripFlow = false

    private var currentSettings: YearlySettings? {
        let year = Calendar.current.component(.year, from: Date())
        return settings.first { $0.year == year }
    }

    private var irsRate: Double {
        currentSettings?.irsRate ?? 0.725
    }

    // Trips from the current year
    private var yearTrips: [Trip] {
        let year = Calendar.current.component(.year, from: Date())
        return trips.filter {
            Calendar.current.component(.year, from: $0.date) == year && $0.isComplete
        }
    }

    // Trips from the current month
    private var monthTrips: [Trip] {
        let now = Date()
        return yearTrips.filter {
            Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month)
        }
    }

    private var todayTrips: [Trip] {
        yearTrips.filter { Calendar.current.isDateInToday($0.date) }
    }

    /// In-progress trips, most recent first (already sorted by query).
    private var incompleteTrips: [Trip] {
        trips.filter { !$0.isComplete }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Big "Start Trip" button — the primary action
                    Button {
                        showingVoiceFlow = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 44))
                            VStack(alignment: .leading) {
                                Text("Start Trip")
                                    .font(.title2.bold())
                                Text("Voice-guided logging")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.title3)
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    // Tax savings card
                    let businessMilesYear = yearTrips.filter(\.isBusiness).reduce(0.0) { $0 + $1.miles }
                    let deductionYear = businessMilesYear * irsRate
                    let tollsYear = yearTrips.filter(\.isBusiness).reduce(0.0) { $0 + $1.tollAmount }
                    let parkingYear = yearTrips.filter(\.isBusiness).reduce(0.0) { $0 + $1.parkingAmount }

                    VStack(spacing: 16) {
                        Text("Tax Savings This Year")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "$%.2f", deductionYear + tollsYear + parkingYear))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)

                        HStack(spacing: 24) {
                            StatBubble(
                                label: "Business Miles",
                                value: String(format: "%.0f", businessMilesYear)
                            )
                            StatBubble(
                                label: "Trips",
                                value: "\(yearTrips.filter(\.isBusiness).count)"
                            )
                            StatBubble(
                                label: "Rate",
                                value: String(format: "$%.3f", irsRate)
                            )
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Quick stats row
                    HStack(spacing: 16) {
                        QuickStatCard(
                            title: "Today",
                            miles: todayTrips.reduce(0.0) { $0 + $1.miles },
                            trips: todayTrips.count,
                            color: .blue
                        )
                        QuickStatCard(
                            title: "This Month",
                            miles: monthTrips.reduce(0.0) { $0 + $1.miles },
                            trips: monthTrips.count,
                            color: .purple
                        )
                    }

                    // In-progress trips with "End Trip" buttons
                    if !incompleteTrips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("In Progress")
                                .font(.headline)
                            ForEach(incompleteTrips) { trip in
                                Button {
                                    tripToEnd = trip
                                    showingEndTripFlow = true
                                } label: {
                                    HStack {
                                        Image(systemName: "flag.checkered")
                                            .foregroundStyle(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(trip.startLocationName) → ?")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)
                                            Text(trip.date.formatted(date: .omitted, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("End Trip")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(.orange.gradient, in: Capsule())
                                    }
                                    .padding(12)
                                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("MileageTracker")
            .fullScreenCover(isPresented: $showingVoiceFlow) {
                VoiceTripFlowView(mode: .startTrip)
            }
            .fullScreenCover(isPresented: $showingEndTripFlow) {
                if let trip = tripToEnd {
                    VoiceTripFlowView(mode: .endTrip(trip))
                }
            }
            .alert("No Trip in Progress", isPresented: $showNoTripAlert) {
                Button("Start a Trip") {
                    showingVoiceFlow = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You don't have any trips in progress. Would you like to start one?")
            }
            .onAppear {
                handleSiriFlags()
            }
            .onChange(of: launchIntoVoiceFlow) { _, shouldLaunch in
                if shouldLaunch {
                    launchIntoVoiceFlow = false
                    showingVoiceFlow = true
                }
            }
            .onChange(of: launchIntoEndTripFlow) { _, shouldLaunch in
                if shouldLaunch {
                    launchIntoEndTripFlow = false
                    launchEndTripFromSiri()
                }
            }
        }
    }

    // MARK: - Siri Handling

    /// Check both Siri flags on appear (handles cold launch).
    private func handleSiriFlags() {
        if launchIntoVoiceFlow {
            launchIntoVoiceFlow = false
            showingVoiceFlow = true
        }
        if launchIntoEndTripFlow {
            launchIntoEndTripFlow = false
            launchEndTripFromSiri()
        }
    }

    /// Launch the End Trip flow from a Siri command.
    /// - If 1 in-progress trip: end it directly
    /// - If multiple: pick the most recent (query is already sorted by date desc)
    /// - If none: show alert offering to start one
    private func launchEndTripFromSiri() {
        if let mostRecent = incompleteTrips.first {
            tripToEnd = mostRecent
            showingEndTripFlow = true
        } else {
            showNoTripAlert = true
        }
    }
}

// MARK: - Supporting Views

private struct StatBubble: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuickStatCard: View {
    let title: String
    let miles: Double
    let trips: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(String(format: "%.1f mi", miles))
                .font(.title3.bold())
            Text("\(trips) trip\(trips == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
