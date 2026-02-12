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
}

/// A single row in the ingredient editing form.
/// Shows quantity, unit picker, and ingredient name in a compact layout.
struct IngredientRowView: View {
    @Binding var data: IngredientFormData

    var body: some View {
        HStack {
            // Quantity — narrow field for numbers
            TextField("Qty", value: $data.quantity, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 50)

            // Unit picker — compact menu style so it doesn't take much space
            Picker("Unit", selection: $data.unit) {
                ForEach(IngredientUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
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
    @Previewable @State var data = IngredientFormData(name: "Flour", quantity: 2.0, unit: .cup)
    IngredientRowView(data: $data)
        .padding()
}
