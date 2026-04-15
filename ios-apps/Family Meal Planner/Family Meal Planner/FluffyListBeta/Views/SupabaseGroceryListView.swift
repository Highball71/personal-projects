//
//  SupabaseGroceryListView.swift
//  FluffyList
//
//  Grocery list with slate blue accent, cream background with subtle
//  ruled lines, items grouped by category, checkboxes with
//  strikethrough, right-aligned quantities, Share List button, and
//  a Store Mode toggle for high-contrast dark shopping experience.
//  Figma Heirloom design.
//

import SwiftUI

struct SupabaseGroceryListView: View {
    @EnvironmentObject private var groceryService: GroceryService
    @AppStorage("groceryStoreMode") private var storeMode = false

    /// Items grouped by auto-detected category, sorted with unchecked
    /// items first within each group.
    private var groupedItems: [(GroceryCategory, [SupabaseGroceryItem])] {
        var buckets: [GroceryCategory: [SupabaseGroceryItem]] = [:]
        for item in groceryService.items {
            let cat = GroceryCategory.classify(item.name)
            buckets[cat, default: []].append(item)
        }
        for key in buckets.keys {
            buckets[key]?.sort { a, b in
                if a.isChecked != b.isChecked { return !a.isChecked }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
        return GroceryCategory.allCases.compactMap { cat in
            guard let items = buckets[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    /// Plain-text version of unchecked items for sharing.
    private var shareText: String {
        var lines: [String] = ["FluffyList — Grocery List", ""]
        for (cat, items) in groupedItems {
            let unchecked = items.filter { !$0.isChecked }
            guard !unchecked.isEmpty else { continue }
            lines.append(cat.rawValue.uppercased())
            for item in unchecked {
                lines.append("  \(quantityText(item)) \(item.name)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasCheckedItems: Bool {
        groceryService.items.contains { $0.isChecked }
    }

    // MARK: - Store Mode Colors

    private var bgColor: Color { storeMode ? Color(hex: "141414") : Color.fluffyBackground }
    private var textColor: Color { storeMode ? .white : Color.fluffyPrimary }
    private var secondaryTextColor: Color { storeMode ? .white.opacity(0.6) : Color.fluffySecondary }
    private var dimTextColor: Color { storeMode ? .white.opacity(0.35) : Color.fluffyTertiary }
    private var lineColor: Color { storeMode ? .white.opacity(0.1) : Color.fluffyDivider }
    private var accentColor: Color { storeMode ? Color(hex: "6B9FE8") : Color.fluffySlateBlue }
    private var checkboxOff: Color { storeMode ? .white.opacity(0.3) : Color.fluffyBorder }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if groceryService.isLoading && groceryService.items.isEmpty {
                    ProgressView("Loading groceries...")
                } else if groceryService.items.isEmpty {
                    emptyState
                } else {
                    groceryList
                }
            }
            .animation(.easeInOut(duration: 0.25), value: groceryService.isLoading)
            .animation(.easeInOut(duration: 0.25), value: storeMode)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Groceries")
            .toolbarColorScheme(storeMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            storeMode.toggle()
                        }
                    } label: {
                        Image(systemName: storeMode ? "sun.max.fill" : "flashlight.on.fill")
                            .foregroundStyle(accentColor)
                    }
                    .accessibilityLabel(storeMode ? "Exit Store Mode" : "Store Mode")
                }

                if hasCheckedItems {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Checked") {
                            Task { await groceryService.clearChecked() }
                        }
                        .foregroundStyle(accentColor)
                    }
                }
            }
            .refreshable {
                await groceryService.fetchItems()
            }
            .task {
                await groceryService.fetchItems()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(storeMode ? accentColor.opacity(0.15) : Color.fluffySlateBlueLight)
                    .frame(width: 120, height: 120)
                Image(systemName: "cart")
                    .font(.system(size: 48))
                    .foregroundStyle(accentColor)
            }
            .padding(.bottom, 24)
            Text("Nothing to buy yet")
                .font(.fluffyDisplay)
                .foregroundStyle(textColor)
                .padding(.bottom, 8)
            Text("Assign recipes to your Meal Plan\nto build your grocery list.")
                .font(.fluffyBody)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Grocery List

    private var groceryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Store mode banner
                if storeMode {
                    HStack(spacing: 8) {
                        Image(systemName: "flashlight.on.fill")
                            .font(.system(size: 14))
                        Text("Store Mode")
                            .font(.fluffySubheadline)
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                ForEach(groupedItems, id: \.0) { category, items in
                    categorySection(category, items: items)
                }

                // Share List button
                ShareLink(item: shareText) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share List")
                    }
                    .font(.fluffyButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(
        _ category: GroceryCategory,
        items: [SupabaseGroceryItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(category.rawValue.uppercased())
                .font(.fluffySubheadline)
                .foregroundStyle(accentColor)
                .tracking(1.2)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            ForEach(items) { item in
                VStack(spacing: 0) {
                    ruledLine
                    itemRow(item)
                }
            }
            ruledLine
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: SupabaseGroceryItem) -> some View {
        Button {
            Task { await groceryService.toggleChecked(item) }
        } label: {
            HStack(spacing: storeMode ? 16 : 12) {
                // Checkbox
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: storeMode ? 28 : 22))
                    .foregroundStyle(item.isChecked ? accentColor : checkboxOff)

                // Item name
                Text(item.name)
                    .font(storeMode
                        ? .custom("Inter-Regular", size: 18)
                        : .fluffyBody)
                    .foregroundStyle(item.isChecked ? dimTextColor : textColor)
                    .strikethrough(item.isChecked, color: dimTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Right-aligned quantity
                Text(quantityText(item))
                    .font(storeMode
                        ? .custom("Inter-Regular", size: 16)
                        : .fluffyFootnote)
                    .foregroundStyle(item.isChecked ? dimTextColor : secondaryTextColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, storeMode ? 16 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await groceryService.deleteItem(item.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Ruled Line

    private var ruledLine: some View {
        Rectangle()
            .fill(lineColor)
            .frame(height: 1)
            .padding(.leading, storeMode ? 64 : 54)
            .padding(.trailing, 20)
    }

    // MARK: - Quantity Formatting

    private func quantityText(_ item: SupabaseGroceryItem) -> String {
        if item.unit == IngredientUnit.toTaste.rawValue {
            return "to taste"
        }
        let qty = FractionFormatter.formatAsFraction(item.quantity)
        if item.unit == IngredientUnit.none.rawValue {
            return qty
        }
        return "\(qty) \(item.unit)"
    }
}

// MARK: - Grocery Category Classification

/// Client-side classification of grocery items into aisle-style
/// categories based on ingredient name keywords.
private enum GroceryCategory: String, CaseIterable, Identifiable {
    case produce = "Produce"
    case protein = "Protein"
    case dairy   = "Dairy & Eggs"
    case pantry  = "Pantry"
    case other   = "Other"

    var id: String { rawValue }

    static func classify(_ name: String) -> GroceryCategory {
        let lower = name.lowercased()
        for (category, words) in keywordMap {
            if words.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }

    private static let keywordMap: [(GroceryCategory, [String])] = [
        (.protein, [
            "chicken", "beef", "pork", "turkey", "fish", "salmon",
            "shrimp", "prawn", "tofu", "lamb", "sausage", "bacon",
            "steak", "ham", "prosciutto", "tuna", "cod", "tilapia",
            "scallop", "crab", "lobster", "tempeh", "seitan",
            "ground meat", "meatball", "anchov"
        ]),
        (.dairy, [
            "milk", "butter", "cheese", "cream", "yogurt", "yoghurt",
            "sour cream", "egg", "parmesan", "mozzarella", "cheddar",
            "ricotta", "feta", "cream cheese", "buttermilk",
            "half and half", "mascarpone", "brie", "gruyere",
            "gouda", "provolone"
        ]),
        (.produce, [
            "lettuce", "tomato", "onion", "garlic", "pepper", "carrot",
            "celery", "potato", "avocado", "lemon", "lime", "apple",
            "banana", "berry", "blueberr", "strawberr", "raspberr",
            "spinach", "kale", "broccoli", "cucumber", "zucchini",
            "mushroom", "basil", "cilantro", "parsley", "thyme",
            "rosemary", "dill", "mint", "ginger", "scallion",
            "green onion", "jalapeño", "jalapeno", "corn", "pea",
            "cabbage", "squash", "sweet potato", "beet", "radish",
            "arugula", "asparagus", "eggplant", "leek", "shallot",
            "chive", "sage", "orange", "grape", "pear", "peach",
            "mango", "pineapple", "melon", "watermelon", "plum",
            "cherry", "fig", "pomegranate", "artichoke", "fennel",
            "bok choy", "sprout", "turnip", "okra"
        ]),
        (.pantry, [
            "flour", "sugar", "salt", "oil", "olive oil", "vinegar",
            "soy sauce", "pasta", "spaghetti", "penne", "linguine",
            "rice", "bean", "lentil", "canned", "broth", "stock",
            "sauce", "cumin", "paprika", "oregano", "bread",
            "cracker", "nut", "almond", "walnut", "pecan",
            "honey", "maple", "vanilla", "baking", "yeast",
            "cornstarch", "cocoa", "chocolate", "oat", "cereal",
            "granola", "noodle", "tortilla", "wrap", "peanut butter",
            "jam", "jelly", "ketchup", "mustard", "mayo",
            "mayonnaise", "sriracha", "hot sauce", "worcestershire",
            "cinnamon", "nutmeg", "clove", "chili", "cayenne",
            "turmeric", "curry", "breadcrumb", "panko", "sesame",
            "coconut", "condensed", "evaporated", "tomato paste",
            "tomato sauce", "diced tomato", "crushed tomato"
        ])
    ]
}
