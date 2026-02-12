//
//  IngredientRowView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

/// Temporary data holder for an ingredient row in the recipe form.
/// This is NOT a SwiftData model — it's just a plain struct for form state.
/// We convert these to real Ingredient objects only when the user saves.
struct IngredientFormData: Identifiable {
    let id = UUID()
    var name: String = ""
    var quantity: Double = 1.0
    var unit: IngredientUnit = .piece

    /// Text representation of the quantity for the fraction-aware text field.
    var quantityText: String = "1"
}

/// A single row in the ingredient editing form.
/// Shows quantity (as fraction text), unit picker, and ingredient name.
struct IngredientRowView: View {
    @Binding var data: IngredientFormData

    var body: some View {
        HStack {
            if data.unit != .toTaste {
                // Quantity — text field that accepts fractions like "1/2" or "1 1/2"
                TextField("Qty", text: $data.quantityText)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(width: 55)
                    .onChange(of: data.quantityText) { _, newValue in
                        if let parsed = FractionFormatter.parseFraction(newValue) {
                            data.quantity = parsed
                        }
                    }
            }

            // Unit picker — compact menu style
            Picker("Unit", selection: $data.unit) {
                ForEach(IngredientUnit.pickerCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .labelsHidden()
            .frame(width: 80)

            // Ingredient name — takes remaining space
            TextField("Ingredient name", text: $data.name)
        }
    }
}

#Preview {
    @Previewable @State var data = IngredientFormData(name: "Flour", quantity: 2.0, unit: .cup, quantityText: "2")
    IngredientRowView(data: $data)
        .padding()
}
