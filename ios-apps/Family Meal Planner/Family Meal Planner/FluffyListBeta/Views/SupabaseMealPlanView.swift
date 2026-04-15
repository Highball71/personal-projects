//
//  SupabaseMealPlanView.swift
//  FluffyList
//
//  Week view with white day cards, teal accent for today,
//  "+ Add a meal" for empty days, Generate Shopping List button,
//  and a "Your week is wide open" empty state with suggested
//  recipes. Figma Heirloom design.
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
        !weekDates.contains { plan(for: $0) != nil }
    }

    /// A handful of recipes to suggest in the empty state.
    /// Picks favorites first, then newest, up to 4.
    private var suggestedRecipes: [RecipeRow] {
        let favorites = recipeService.recipes.filter(\.isFavorite)
        let rest = recipeService.recipes.filter { !$0.isFavorite }
        return Array((favorites + rest).prefix(4))
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
            .task {
                await mealPlanService.fetchPlans(weekStart: weekStart)
                if recipeService.recipes.isEmpty {
                    await recipeService.fetchRecipes()
                }
            }
            .sheet(item: $pickerDate) { date in
                RecipePickerSheet(
                    recipes: recipeService.recipes,
                    onPick: { recipe in
                        pickerDate = nil
                        Task { await assignRecipe(recipe, to: date) }
                    },
                    onCancel: { pickerDate = nil }
                )
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
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
            // Assign to the first empty day
            if let emptyDate = weekDates.first(where: { plan(for: $0) == nil }) {
                Task { await assignRecipe(recipe, to: emptyDate) }
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

    // MARK: - Week Content (existing)

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

    private func dayCard(_ date: Date) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let recipe = recipeFor(date: date)

        return Button {
            pickerDate = date
        } label: {
            HStack(spacing: 0) {
                if today {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.fluffyTeal)
                        .frame(width: 4)
                }

                HStack(spacing: 14) {
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

                    if let recipe {
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
        .contextMenu {
            if recipe != nil {
                Button(role: .destructive) {
                    if let planID = plan(for: date)?.id {
                        Task { await clearDay(date: date, planID: planID) }
                    }
                } label: {
                    Label("Clear Day", systemImage: "trash")
                }
            }
        }
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
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffySuccess)
                Text(message)
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
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

    private func plan(for date: Date) -> MealPlanRow? {
        mealPlanService.plansByDate[MealPlanService.isoDate(from: date)]
    }

    private func recipeFor(date: Date) -> RecipeRow? {
        guard let plan = plan(for: date),
              let recipeID = plan.recipeID else { return nil }
        return recipeService.recipes.first { $0.id == recipeID }
    }

    // MARK: - Actions

    private func assignRecipe(_ recipe: RecipeRow, to date: Date) async {
        isAssigning = true
        defer { isAssigning = false }

        let existingPlanID = plan(for: date)?.id

        let result = await mealPlanService.assignRecipeWithGroceries(
            recipe: recipe,
            on: date,
            existingPlanID: existingPlanID,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else { return }
        await mealPlanService.fetchPlans(weekStart: weekStart)
        withAnimation { toastMessage = "Added to \(fullDayName(for: date))" }
    }

    private func clearDay(date: Date, planID: UUID) async {
        Logger.supabase.info("MealPlan clearDay: planID=\(planID.uuidString)")
        _ = await groceryService.removeContributions(forMealPlan: planID)
        _ = await mealPlanService.clearSlot(on: date)
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
