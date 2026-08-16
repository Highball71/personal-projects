//
//  SupabaseMealPlanView.swift
//  FluffyList
//
//  "The Press" week view: masthead ("This Week"), an italic line of
//  state, one ruled row per day (day/date column in ink, meal name
//  over uppercase metadata), one meal per day (Beta rule),
//  tap-to-control action sheet (Replace / Remove / Cancel) on filled
//  slots, and the "Build the grocery list" text-link CTA.
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
    /// True when the last week fetch failed — drives the retry banner
    /// and stops the view from rendering a failed load as an empty week.
    @State private var fetchFailed = false
    /// Short human message for a failed write (add/remove meal).
    @State private var actionErrorMessage: String?

    private static let fetchErrorText =
        "Couldn't load your meal plan. Check your connection and tap Retry."

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
            VStack(spacing: 0) {
                if fetchFailed {
                    FluffyErrorBanner(
                        message: Self.fetchErrorText,
                        onRetry: { Task { await reloadWeek() } },
                        onDismiss: { fetchFailed = false }
                    )
                } else if let message = actionErrorMessage {
                    FluffyErrorBanner(
                        message: message,
                        onDismiss: { actionErrorMessage = nil }
                    )
                }

                Group {
                    if fetchFailed && mealPlanService.plansByDate.isEmpty {
                        // A failed load with nothing cached must not render
                        // as an empty week — the banner above explains it.
                        Color.clear
                    } else if mealPlanService.isLoading && mealPlanService.plansByDate.isEmpty {
                        // Never visually empty: masthead drawn, italic status line.
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                masthead
                                Text("Fetching your week\u{2026}")
                                    .font(.fluffyCallout)
                                    .foregroundStyle(Color.fluffySecondary)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 15)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if isWeekEmpty && !recipeService.recipes.isEmpty {
                        emptyWeekView
                    } else {
                        weekContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.25), value: mealPlanService.isLoading)
            .background(Color.fluffyBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
            .refreshable {
                await reloadWeek()
            }
            .task(id: selectedTab) {
                // Re-fires whenever the user switches into the Meals tab,
                // not just on cold start. Combined with .refreshable
                // (pull-to-refresh) and the fetch that runs after every
                // mutation, this means the view never relies on a stale
                // local cache: navigating away and back always reads
                // fresh from Supabase.
                guard selectedTab == .mealPlan else { return }
                await reloadWeek()
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

    // MARK: - Masthead & Week State

    private var masthead: some View {
        FluffyMasthead(title: "This Week", dateline: mastheadDateline)
            .padding(.horizontal, 22)
    }

    private var mastheadDateline: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "WEEK OF \(fmt.string(from: weekStart).uppercased())"
    }

    private var plannedCount: Int {
        weekDates.filter { !plans(for: $0).isEmpty }.count
    }

    private static let countWords = [
        "no", "one", "two", "three", "four", "five", "six", "seven"
    ]

    private func word(_ n: Int) -> String {
        (0...7).contains(n) ? Self.countWords[n] : "\(n)"
    }

    /// "Five dinners planned, two open." — the italic line of state
    /// under the masthead.
    private var stateLine: String {
        let planned = plannedCount
        let open = weekDates.count - planned
        if planned == 0 { return "Nothing planned yet." }
        if open == 0 { return "Every night is planned." }
        let dinners = planned == 1 ? "dinner" : "dinners"
        return "\(word(planned).capitalized) \(dinners) planned, \(word(open)) open."
    }

    /// Italic sentence after the closing rule naming what's still open.
    private var openNightsLine: String {
        let open = weekDates.count - plannedCount
        if open == 0 { return "The week is settled." }
        let nights = open == 1 ? "night is" : "nights are"
        return "\(word(open).capitalized) \(nights) still open."
    }

    // MARK: - Empty Week State

    private var emptyWeekView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead

                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "frying.pan")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.fluffyAccent)
                        .padding(.bottom, 30)

                    Text("Your week is\nwide open.")
                        .font(.fluffyDisplaySmall)
                        .fluffyTracking(-0.025, at: 30)
                        .foregroundStyle(Color.fluffyPrimary)
                        .padding(.bottom, 10)

                    Text("Plan a few dinners and the grocery list builds itself.")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 30)

                    VStack(alignment: .leading, spacing: 20) {
                        FluffyTextLink(title: "Browse recipes") {
                            selectedTab = .recipes
                        }
                        FluffyTextLink(title: "Add a custom meal") {
                            showingAddRecipe = true
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.top, 50)
                .padding(.horizontal, 22)

                // Suggested recipes
                if !suggestedRecipes.isEmpty {
                    suggestedSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Suggested Recipes

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHead(title: "Popular in your kitchen")
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            ForEach(suggestedRecipes) { recipe in
                VStack(spacing: 0) {
                    FluffyRule().padding(.horizontal, 22)
                    suggestedRow(recipe)
                }
            }
            FluffyRule().padding(.horizontal, 22)
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
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.name)
                        .font(.fluffyHeadline)
                        .fluffyTracking(-0.01, at: 19)
                        .foregroundStyle(Color.fluffyPrimary)
                        .lineLimit(1)
                    let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
                    FluffyMetadataLine(text: total > 0
                         ? "\(recipe.category) \u{00B7} \(total) min"
                         : recipe.category)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.fluffyAccent)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Content

    private var weekContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 10)

                Text(stateLine)
                    .font(.custom(FluffyFace.italic, size: 14))
                    .foregroundStyle(Color.fluffySecondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 15)

                VStack(spacing: 0) {
                    ForEach(weekDates, id: \.self) { date in
                        VStack(spacing: 0) {
                            FluffyRule().padding(.horizontal, 22)
                            dayRow(date)
                        }
                    }
                    FluffyRule().padding(.horizontal, 22)
                }

                Text(openNightsLine)
                    .font(.custom(FluffyFace.italic, size: 15))
                    .foregroundStyle(Color.fluffySecondary)
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 20)

                FluffyTextLink(title: "Build the grocery list") {
                    Task {
                        await groceryService.fetchItems()
                        selectedTab = .groceries
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Day Row

    @ViewBuilder
    private func dayRow(_ date: Date) -> some View {
        let meals = plans(for: date)

        if meals.isEmpty {
            emptyDayRow(date)
        } else {
            filledDayRow(date, meals: meals)
        }
    }

    /// Day row with no meal — tappable to open picker (past dates
    /// explain themselves via toast). "Nothing planned" / "TAP TO ADD"
    /// sit in the same slots as a planned meal — no placeholder art.
    private func emptyDayRow(_ date: Date) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())

        return Button {
            if isPast {
                withAnimation { toastMessage = "You can only plan meals for today or future days." }
            } else {
                pickerDate = date
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                dateColumn(date: date, today: today)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Nothing planned")
                        .font(.fluffyHeadline)
                        .fluffyTracking(-0.01, at: 19)
                        .foregroundStyle(Color.fluffyTertiary)
                    FluffyMetadataLine(
                        text: isPast ? "PASSED" : "TAP TO ADD",
                        color: isPast ? .fluffyTertiary : .fluffySecondary
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Day row with a meal — one meal per slot (Beta rule). The whole
    /// row is tappable and opens the Replace / Remove / Cancel action
    /// sheet. If legacy data has multiple rows for this date, only the
    /// first is displayed; Replace or Remove will collapse the slot
    /// back to a single row (or zero) via clearDayWithGroceries.
    private func filledDayRow(_ date: Date, meals: [MealPlanRow]) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        let plan = meals.first

        return Button {
            // Past slots are read-only; nothing to control.
            guard !isPast else { return }
            slotActionDate = date
        } label: {
            HStack(alignment: .center, spacing: 14) {
                dateColumn(date: date, today: today)

                if let plan, let recipe = recipeService.recipes.first(where: { $0.id == plan.recipeID }) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recipe.name)
                            .font(.fluffyHeadline)
                            .fluffyTracking(-0.01, at: 19)
                            .foregroundStyle(isPast ? Color.fluffyTertiary : Color.fluffyPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
                        FluffyMetadataLine(text: total > 0
                             ? "\(recipe.category) \u{00B7} \(total) min"
                             : recipe.category)
                    }
                } else {
                    // Plan row exists but its recipe isn't loaded
                    // (or was deleted). Show a hint so the user can
                    // still tap to Replace / Remove.
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tap to update")
                            .font(.fluffyHeadline)
                            .fluffyTracking(-0.01, at: 19)
                            .foregroundStyle(Color.fluffySecondary)
                        FluffyMetadataLine(text: "MEAL NEEDS ATTENTION")
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    // MARK: - Date Column

    /// Fixed 42pt left column: day abbreviation over the date numeral.
    /// Today's abbreviation takes full ink; other days sit in
    /// fluffySecondary. Numerals are always ink 1 territory — Bold,
    /// tight tracking.
    private func dateColumn(date: Date, today: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dayName(for: date).uppercased())
                .font(.custom(FluffyFace.regular, size: 10))
                .fluffyTracking(0.14, at: 10)
                .foregroundStyle(today ? Color.fluffyPrimary : Color.fluffySecondary)
            Text(dayNumber(for: date))
                .font(.custom(FluffyFace.bold, size: 26))
                .fluffyTracking(-0.03, at: 26)
                .foregroundStyle(Color.fluffyPrimary)
        }
        .frame(width: 42, alignment: .leading)
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
                .background(.ultraThinMaterial)
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
            .background(.ultraThinMaterial)
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

    /// Fetch the current week and record whether it succeeded, so a
    /// failed load shows the retry banner instead of an empty week.
    private func reloadWeek() async {
        let ok = await mealPlanService.fetchPlans(weekStart: weekStart)
        fetchFailed = !ok
    }

    private func addMeal(_ recipe: RecipeRow, to date: Date) async {
        isAssigning = true
        defer { isAssigning = false }

        let result = await mealPlanService.addMealWithGroceries(
            recipe: recipe,
            on: date,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else {
            actionErrorMessage = "Couldn't add that meal. Please try again."
            return
        }
        await reloadWeek()
        withAnimation { toastMessage = "Added to \(fullDayName(for: date))" }
    }

    /// Remove the meal assigned to a slot. Uses clearDayWithGroceries
    /// so legacy multi-row slots also collapse cleanly.
    private func removeSlot(date: Date) async {
        Logger.supabase.info("MealPlan removeSlot: date=\(MealPlanService.isoDate(from: date))")
        let cleared = await mealPlanService.clearDayWithGroceries(on: date, groceryService: groceryService)
        if !cleared {
            actionErrorMessage = "Couldn't remove that meal. Please try again."
        }
        await reloadWeek()
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
