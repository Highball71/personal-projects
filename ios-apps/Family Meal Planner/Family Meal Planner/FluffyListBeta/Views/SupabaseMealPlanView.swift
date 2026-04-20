//
//  SupabaseMealPlanView.swift
//  FluffyList
//
//  Week view with white day cards, teal accent for today,
//  one meal per day (Beta rule), tap-to-control action sheet
//  (Replace / Remove / Cancel) on filled slots, "+ Add a meal" on
//  empty slots, Generate Shopping List button, and a "Your week is
//  wide open" empty state with suggested recipes. Figma Heirloom design.
//

import os
import SwiftUI

struct SupabaseMealPlanView: View {
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var groceryService: GroceryService

    @Binding var selectedTab: AppTab

    @State private var weekStart: Date = DateHelper.startOfWeek(containing: Date())
    @State private var pickerDate: Date?
    /// When set, shows the Replace / Remove / Cancel action sheet
    /// for the meal currently assigned to this date.
    @State private var slotActionDate: Date?
    @State private var isAssigning = false
    @State private var toastMessage: String?
    @State private var showingAddRecipe = false

    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    /// True when no day in the current week has a meal assigned.
    private var isWeekEmpty: Bool {
        !weekDates.contains { !plans(for: $0).isEmpty }
    }

    /// A handful of recipes to suggest in the empty state.
    ///
    /// Dedup is keyed on the recipe's **normalized name** (trimmed +
    /// lowercased), not on `id`. Two `recipes` rows with different
    /// UUIDs but the same name (a known consequence of repeat imports)
    /// are the same recipe to the user, so we keep just one occurrence.
    /// When a name has multiple rows we keep the most recent (newest
    /// `createdAt`), favoring user-marked favorites first.
    private var suggestedRecipes: [RecipeRow] {
        // Sort once: favorites first, then newest createdAt. The first
        // row we encounter for each name is therefore both "most
        // important" (favorite) and "most recent" within its priority.
        let sorted = recipeService.recipes.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.createdAt > rhs.createdAt
        }

        var seenNames = Set<String>()
        var unique: [RecipeRow] = []
        for recipe in sorted {
            let key = recipe.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty else { continue }
            if seenNames.insert(key).inserted {
                unique.append(recipe)
                if unique.count == 4 { break }
            }
        }
        return unique
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if mealPlanService.isLoading && mealPlanService.plansByDate.isEmpty {
                    ProgressView("Loading meal plan...")
                } else if isWeekEmpty && !recipeService.recipes.isEmpty {
                    emptyWeekView
                } else {
                    weekContent
                }
            }
            .animation(.easeInOut(duration: 0.25), value: mealPlanService.isLoading)
            .background(Color.fluffyBackground)
            .navigationTitle("This Week")
            .refreshable {
                await mealPlanService.fetchPlans(weekStart: weekStart)
            }
            .task(id: selectedTab) {
                // Re-fires whenever the user switches into the Meals tab,
                // not just on cold start. Combined with .refreshable
                // (pull-to-refresh) and the fetch that runs after every
                // mutation, this means the view never relies on a stale
                // local cache: navigating away and back always reads
                // fresh from Supabase.
                guard selectedTab == .mealPlan else { return }
                await mealPlanService.fetchPlans(weekStart: weekStart)
                await recipeService.fetchRecipes()
            }
            .sheet(item: $pickerDate) { date in
                RecipePickerSheet(
                    recipes: recipeService.recipes,
                    onPick: { recipe in
                        pickerDate = nil
                        Task { await addMeal(recipe, to: date) }
                    },
                    onCancel: { pickerDate = nil }
                )
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
            }
            .confirmationDialog(
                slotActionTitle,
                isPresented: slotActionBinding,
                titleVisibility: .visible,
                presenting: slotActionDate
            ) { date in
                Button("Replace Meal") {
                    slotActionDate = nil
                    pickerDate = date
                }
                Button("Remove Meal", role: .destructive) {
                    let target = date
                    slotActionDate = nil
                    Task { await removeSlot(date: target) }
                }
                Button("Cancel", role: .cancel) {
                    slotActionDate = nil
                }
            }
            .overlay { assigningOverlay }
            .overlay { toastOverlay }
        }
    }

    // MARK: - Empty Week State

    private var emptyWeekView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Illustration
                ZStack {
                    Circle()
                        .fill(Color.fluffyTealLight)
                        .frame(width: 120, height: 120)
                    Image(systemName: "frying.pan.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.fluffyTeal)
                }
                .padding(.bottom, 24)

                // Headline
                Text("Your week is\nwide open")
                    .font(.fluffyDisplay)
                    .foregroundStyle(Color.fluffyPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Plan some meals and we'll build\nyour shopping list automatically.")
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffySecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                // Action buttons
                VStack(spacing: 12) {
                    FluffyPrimaryButton(
                        "Browse Recipes",
                        icon: "book",
                        section: .recipes
                    ) {
                        selectedTab = .recipes
                    }

                    Button {
                        showingAddRecipe = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("Add a Custom Meal")
                        }
                        .font(.fluffyButton)
                        .foregroundStyle(Color.fluffyTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.fluffyTeal, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 36)

                // Suggested recipes
                if !suggestedRecipes.isEmpty {
                    suggestedSection
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Suggested Recipes

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FluffySectionHeader(title: "Popular in your kitchen", section: .mealPlan)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(suggestedRecipes) { recipe in
                    VStack(spacing: 0) {
                        suggestedRow(recipe)
                        if recipe.id != suggestedRecipes.last?.id {
                            Rectangle()
                                .fill(Color.fluffyDivider)
                                .frame(height: 1)
                                .padding(.leading, 56)
                                .padding(.trailing, 20)
                        }
                    }
                }
            }
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 32)
    }

    private func suggestedRow(_ recipe: RecipeRow) -> some View {
        Button {
            // Assign to the first empty day that is today or later
            let today = Calendar.current.startOfDay(for: Date())
            if let emptyDate = weekDates.first(where: {
                plans(for: $0).isEmpty && Calendar.current.startOfDay(for: $0) >= today
            }) {
                Task { await addMeal(recipe, to: emptyDate) }
            }
        } label: {
            HStack(spacing: 12) {
                // Category color dot
                Circle()
                    .fill(recipe.recipeCategory.stripeColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.fluffyHeadline)
                        .foregroundStyle(Color.fluffyPrimary)
                        .lineLimit(1)
                    let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
                    Text(total > 0
                         ? "\(recipe.category.capitalized) · \(total) min"
                         : recipe.category.capitalized)
                        .font(.fluffyCaption)
                        .foregroundStyle(Color.fluffySecondary)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(Color.fluffyTeal)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Content

    private var weekContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                weekHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                VStack(spacing: 12) {
                    ForEach(weekDates, id: \.self) { date in
                        dayCard(date)
                    }
                }
                .padding(.horizontal, 20)

                FluffyPrimaryButton(
                    "Generate Shopping List",
                    icon: "cart",
                    section: .grocery
                ) {
                    Task {
                        await groceryService.fetchItems()
                        selectedTab = .groceries
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Week Header

    private var weekHeaderText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = fmt.string(from: weekStart)
        let end = fmt.string(from: weekDates.last ?? weekStart)
        return "\(start) – \(end)"
    }

    private var weekHeader: some View {
        Text(weekHeaderText)
            .font(.fluffyHeadline)
            .foregroundStyle(Color.fluffyTeal)
    }

    // MARK: - Day Card

    @ViewBuilder
    private func dayCard(_ date: Date) -> some View {
        let meals = plans(for: date)

        if meals.isEmpty {
            emptyDayCard(date)
        } else {
            filledDayCard(date, meals: meals)
        }
    }

    /// Day card with no meals — tappable to open picker (or shows
    /// "No meal planned" for past dates).
    private func emptyDayCard(_ date: Date) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())

        return Button {
            if isPast {
                withAnimation { toastMessage = "You can only plan meals for today or future days." }
            } else {
                pickerDate = date
            }
        } label: {
            HStack(spacing: 0) {
                if today {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.fluffyTeal)
                        .frame(width: 4)
                }

                HStack(spacing: 14) {
                    dateColumn(date: date, today: today)

                    if isPast {
                        Text("No meal planned")
                            .font(.fluffyCallout)
                            .foregroundStyle(Color.fluffyTertiary)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.fluffyCaption)
                            Text("Add a meal")
                                .font(.fluffyCallout)
                        }
                        .foregroundStyle(Color.fluffyTeal)
                    }

                    Spacer()
                }
                .padding(.horizontal, today ? 12 : 16)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// Day card with a meal — one meal per slot (Beta rule). The
    /// whole row is tappable and opens the Replace / Remove / Cancel
    /// action sheet. If legacy data has multiple rows for this date,
    /// only the first is displayed; Replace or Remove will collapse
    /// the slot back to a single row (or zero) via clearDayWithGroceries.
    private func filledDayCard(_ date: Date, meals: [MealPlanRow]) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        let plan = meals.first

        return Button {
            // Past slots are read-only; nothing to control.
            guard !isPast else { return }
            slotActionDate = date
        } label: {
            HStack(spacing: 0) {
                if today {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.fluffyTeal)
                        .frame(width: 4)
                }

                HStack(alignment: .center, spacing: 14) {
                    dateColumn(date: date, today: today)

                    if let plan, let recipe = recipeService.recipes.first(where: { $0.id == plan.recipeID }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.fluffyHeadline)
                                .foregroundStyle(Color.fluffyPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(recipe.category.capitalized)
                                .font(.fluffyCaption)
                                .foregroundStyle(Color.fluffySecondary)
                        }
                    } else {
                        // Plan row exists but its recipe isn't loaded
                        // (or was deleted). Show a hint so the user can
                        // still tap to Replace / Remove.
                        Text("Tap to update")
                            .font(.fluffyCallout)
                            .foregroundStyle(Color.fluffySecondary)
                    }

                    Spacer()

                    if !isPast {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(Color.fluffyTeal)
                    }
                }
                .padding(.horizontal, today ? 12 : 16)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    // MARK: - Date Column

    private func dateColumn(date: Date, today: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayName(for: date))
                .font(.fluffyCaption)
                .foregroundStyle(today ? Color.fluffyTeal : Color.fluffySecondary)
                .textCase(.uppercase)
            Text(dayNumber(for: date))
                .font(.fluffyTitle)
                .foregroundStyle(today ? Color.fluffyTeal : Color.fluffyPrimary)
        }
        .frame(width: 44, alignment: .leading)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var assigningOverlay: some View {
        if isAssigning {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.3)
                    Text("Adding to meal plan...")
                        .font(.fluffyHeadline)
                        .foregroundStyle(Color.fluffyPrimary)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            let isSuccess = !message.contains("only plan meals")
            VStack(spacing: 8) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "calendar.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(isSuccess ? Color.fluffySuccess : Color.fluffySecondary)
                Text(message)
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - Helpers

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func fullDayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    /// All meal plan rows for a given date, filtering out orphan rows
    /// (NULL recipe_id from past SET NULL cascades). Beta rule is one
    /// meal per slot; if legacy data has multiple rows, callers should
    /// treat `.first` as the slot's meal.
    private func plans(for date: Date) -> [MealPlanRow] {
        (mealPlanService.plansByDate[MealPlanService.isoDate(from: date)] ?? [])
            .filter { $0.recipeID != nil }
    }

    /// Title shown above the Replace / Remove action sheet.
    private var slotActionTitle: String {
        guard let date = slotActionDate,
              let plan = plans(for: date).first,
              let recipe = recipeService.recipes.first(where: { $0.id == plan.recipeID })
        else { return "This Meal" }
        return recipe.name
    }

    /// Bool binding driving the confirmationDialog from `slotActionDate`.
    private var slotActionBinding: Binding<Bool> {
        Binding(
            get: { slotActionDate != nil },
            set: { if !$0 { slotActionDate = nil } }
        )
    }

    // MARK: - Actions

    private func addMeal(_ recipe: RecipeRow, to date: Date) async {
        isAssigning = true
        defer { isAssigning = false }

        let result = await mealPlanService.addMealWithGroceries(
            recipe: recipe,
            on: date,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else { return }
        await mealPlanService.fetchPlans(weekStart: weekStart)
        withAnimation { toastMessage = "Added to \(fullDayName(for: date))" }
    }

    /// Remove the meal assigned to a slot. Uses clearDayWithGroceries
    /// so legacy multi-row slots also collapse cleanly.
    private func removeSlot(date: Date) async {
        Logger.supabase.info("MealPlan removeSlot: date=\(MealPlanService.isoDate(from: date))")
        _ = await mealPlanService.clearDayWithGroceries(on: date, groceryService: groceryService)
        await mealPlanService.fetchPlans(weekStart: weekStart)
    }
}

// MARK: - Recipe Picker Sheet

struct RecipePickerSheet: View {
    let recipes: [RecipeRow]
    let onPick: (RecipeRow) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.fluffyPrimary.opacity(0.7))
                        Text("No recipes yet")
                            .font(.fluffyHeadline)
                            .foregroundStyle(Color.fluffyPrimary)
                        Text("Add recipes in the Recipes tab first.")
                            .font(.fluffyCallout)
                            .foregroundStyle(Color.fluffySecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Button {
                                if let pick = recipes.randomElement() {
                                    Logger.supabase.info("Surprise Me: picked \"\(pick.name)\" id=\(pick.id.uuidString)")
                                    onPick(pick)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "dice.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.fluffyTeal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Surprise Me")
                                            .font(.fluffyHeadline)
                                            .foregroundStyle(Color.fluffyPrimary)
                                        Text("Pick a random recipe")
                                            .font(.fluffyCaption)
                                            .foregroundStyle(Color.fluffySecondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .tint(Color.fluffyPrimary)
                        }

                        Section("All Recipes") {
                            ForEach(recipes) { recipe in
                                Button {
                                    onPick(recipe)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(recipe.name)
                                                .font(.fluffyHeadline)
                                                .foregroundStyle(Color.fluffyPrimary)
                                            Text(recipe.category.capitalized)
                                                .font(.fluffyCaption)
                                                .foregroundStyle(Color.fluffySecondary)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .tint(Color.fluffyPrimary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Choose a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

// MARK: - Date Identifiable

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
