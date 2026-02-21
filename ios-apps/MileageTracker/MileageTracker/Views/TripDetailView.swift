import SwiftUI
import SwiftData

/// View/edit a trip. Also used to complete an in-progress trip
/// by adding the ending odometer reading.
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var trip: Trip

    @State private var endOdometerText = ""
    @State private var tollText = ""
    @State private var parkingText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Info") {
                    DatePicker("Date", selection: $trip.date)

                    HStack {
                        Text("Category")
                        Spacer()
                        Picker("", selection: $trip.category) {
                            ForEach(TripCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .labelsHidden()
                    }

                    Toggle("Business Trip", isOn: $trip.isBusiness)
                }

                Section("Locations") {
                    TextField("Start Location", text: $trip.startLocationName)
                    TextField("Destination", text: $trip.endLocationName)
                }

                Section("Odometer") {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("Start", value: $trip.startOdometer, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if trip.isComplete {
                        HStack {
                            Text("End")
                            Spacer()
                            TextField("End", value: $trip.endOdometer, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(String(format: "%.1f miles", trip.miles))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Complete the trip
                        HStack {
                            Text("End")
                            Spacer()
                            TextField("Enter ending odometer", text: $endOdometerText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }

                        Button("Complete Trip") {
                            if let endOdo = Double(endOdometerText), endOdo > trip.startOdometer {
                                trip.endOdometer = endOdo
                                trip.isComplete = true
                            }
                        }
                        .disabled(endOdometerText.isEmpty)
                    }
                }

                Section("Purpose") {
                    TextField("Business Purpose", text: $trip.businessPurpose)
                }

                Section("Expenses") {
                    HStack {
                        Text("Tolls")
                        Spacer()
                        TextField("$0.00", value: $trip.tollAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Parking")
                        Spacer()
                        TextField("$0.00", value: $trip.parkingAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $trip.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(trip.isComplete ? "Trip Details" : "Complete Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
