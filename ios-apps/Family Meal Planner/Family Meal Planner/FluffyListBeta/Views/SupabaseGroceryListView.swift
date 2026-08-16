//
//  SupabaseGroceryListView.swift
//  FluffyList
//
//  "The Press" grocery list. Paper ground, masthead, category heads
//  as tracked uppercase section labels, square checkboxes, ruled
//  rows, quantities right-aligned in tabular numerals, and the share
//  affordance as an underlined text link. Store Mode is the one
//  screen with an ink ground.
//

import SwiftUI

struct SupabaseGroceryListView: View {
    @EnvironmentObject private var groceryService: GroceryService
    @AppStorage("groceryStoreMode") private var storeMode = false

    /// Lets the empty state's "Plan a night" link jump to the Meals tab.
    @Binding var selectedTab: AppTab

    /// True when the last grocery fetch failed — drives the retry banner
    /// and stops a failed load from rendering as an empty list.
    @State private var fetchFailed = false
    /// Short human message for a failed write (check/delete/clear).
    @State private var actionErrorMessage: String?

    private static let fetchErrorText =
        "Couldn't load your grocery list. Check your connection and tap Retry."

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

    private var checkedCount: Int {
        groceryService.items.filter { $0.isChecked }.count
    }

    // MARK: - Press / Store Mode Colors

    private var bgColor: Color { storeMode ? .fluffyInkGround : .fluffyBackground }
    private var textColor: Color { storeMode ? .fluffyPaperOnInk : .fluffyPrimary }
    private var secondaryTextColor: Color { storeMode ? .fluffyPaperDimOnInk : .fluffySecondary }
    private var dimTextColor: Color { storeMode ? .fluffyPaperDimOnInk : .fluffyTertiary }
    private var lineColor: Color { storeMode ? .fluffyRuleOnInk : .fluffyDivider }
    private var headColor: Color { storeMode ? .fluffyAccentPale : .fluffySecondary }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if fetchFailed {
                    FluffyErrorBanner(
                        message: Self.fetchErrorText,
                        onRetry: { Task { await reloadGroceries() } },
                        onDismiss: { fetchFailed = false }
                    )
                } else if let message = actionErrorMessage {
                    FluffyErrorBanner(
                        message: message,
                        onDismiss: { actionErrorMessage = nil }
                    )
                }

                Group {
                    if fetchFailed && groceryService.items.isEmpty {
                        // A failed load with nothing cached must not render
                        // as an empty list — the banner explains it.
                        loadingOrFailedShell(line: nil)
                    } else if groceryService.isLoading && groceryService.items.isEmpty {
                        loadingOrFailedShell(line: "Fetching your groceries\u{2026}")
                    } else if groceryService.items.isEmpty {
                        emptyState
                    } else {
                        groceryList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.25), value: groceryService.isLoading)
            .animation(.easeInOut(duration: 0.25), value: storeMode)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarColorScheme(storeMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            storeMode.toggle()
                        }
                    } label: {
                        Image(systemName: storeMode ? "sun.max.fill" : "flashlight.on.fill")
                            .foregroundStyle(storeMode ? Color.fluffyAccentPale : Color.fluffyAccent)
                    }
                    .accessibilityLabel(storeMode ? "Exit Store Mode" : "Store Mode")
                }

                if hasCheckedItems {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear checked") {
                            Task {
                                if !(await groceryService.clearChecked()) {
                                    actionErrorMessage = "Couldn't clear checked items. Please try again."
                                }
                            }
                        }
                        .font(.fluffyButton)
                        .foregroundStyle(storeMode ? Color.fluffyAccentPale : Color.fluffyAccent)
                    }
                }
            }
            .refreshable {
                await reloadGroceries()
            }
            .task {
                await reloadGroceries()
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        FluffyMasthead(
            title: storeMode ? "Aisle by aisle" : "Grocery",
            dateline: storeMode
                ? "\(groceryService.items.count) ITEMS"
                : "\(checkedCount) IN THE CART",
            onInk: storeMode,
            brand: storeMode ? "STORE MODE" : "FLUFFYLIST"
        )
        .padding(.horizontal, 22)
    }

    // MARK: - Reload

    /// Fetch grocery items and record whether it succeeded, so a failed
    /// load shows the retry banner instead of an empty state.
    private func reloadGroceries() async {
        let ok = await groceryService.fetchItems()
        fetchFailed = !ok
    }

    // MARK: - Loading / Failed Shell

    /// The page is never visually empty: masthead already drawn, plus an
    /// optional italic status line while fetching.
    private func loadingOrFailedShell(line: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                if let line {
                    Text(line)
                        .font(.fluffyCallout)
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 22)
                        .padding(.top, 15)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead

                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "cart")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.fluffyAccent)
                        .padding(.bottom, 30)

                    Text("The list writes itself.")
                        .font(.fluffyDisplaySmall)
                        .fluffyTracking(-0.025, at: 30)
                        .foregroundStyle(textColor)
                        .padding(.bottom, 10)

                    Text("Plan a few dinners and every ingredient lands here, sorted by aisle.")
                        .font(.fluffyCallout)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 30)

                    FluffyTextLink(title: "Plan a night") {
                        selectedTab = .mealPlan
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Grocery List

    private var groceryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead

                ForEach(groupedItems, id: \.0) { category, items in
                    categorySection(category, items: items)
                }

                // Share affordance — an underlined text link, not a
                // filled button.
                ShareLink(item: shareText) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Share the list \u{2192}")
                            .font(.fluffyButton)
                            .foregroundStyle(storeMode ? Color.fluffyAccentPale : Color.fluffyAccent)
                        FluffyRule(weight: 2, color: storeMode ? .fluffyAccentPale : .fluffyAccent)
                    }
                    .fixedSize()
                }
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Category Section

    private func categorySection(
        _ category: GroceryCategory,
        items: [SupabaseGroceryItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHead(title: category.rawValue, color: headColor)
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 10)

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
            Task {
                if !(await groceryService.toggleChecked(item)) {
                    actionErrorMessage = "Couldn't update that item. Please try again."
                }
            }
        } label: {
            HStack(spacing: storeMode ? 16 : 14) {
                FluffyCheckbox(
                    isChecked: item.isChecked,
                    size: storeMode ? 30 : 20,
                    onInk: storeMode
                )

                Text(item.name)
                    .font(.custom(FluffyFace.regular, size: storeMode ? 21 : 17))
                    .foregroundStyle(item.isChecked ? dimTextColor : textColor)
                    .strikethrough(item.isChecked, color: dimTextColor)
                    .animation(.easeInOut(duration: 0.18), value: item.isChecked)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(quantityText(item))
                    .font(.custom(FluffyFace.regular, size: storeMode ? 16 : 13))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundStyle(item.isChecked ? dimTextColor : secondaryTextColor)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, storeMode ? 16 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    if !(await groceryService.deleteItem(item.id)) {
                        actionErrorMessage = "Couldn't delete that item. Please try again."
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Ruled Line

    private var ruledLine: some View {
        FluffyRule(weight: 1, color: lineColor)
            .padding(.horizontal, 22)
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
