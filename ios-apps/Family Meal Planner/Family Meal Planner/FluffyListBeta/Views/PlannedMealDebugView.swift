//
//  PlannedMealDebugView.swift
//  FluffyList
//
//  TEMPORARY — debug-only screen for sanity-checking the multi-meal
//  data layer (PlannedMeal + PlannedMealService + PlannedMealViewModel).
//  Not intended for production. Removed once Phase 3 UI lands.
//
//  Uses the real services from the environment:
//    - SupabaseManager for the current household ID
//    - RecipeService for real recipe IDs (no manual UUIDs)
//    - PlannedMealService for CRUD
//    - PlannedMealViewModel for grouped state
//

#if DEBUG

import SwiftUI
import os

struct PlannedMealDebugView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var supabaseManager: SupabaseManager

    /// View model is built from the injected PlannedMealService so we
    /// reuse the same instance wired up in Family_Meal_PlannerApp.
    @StateObject private var viewModel: PlannedMealViewModel

    @State private var lastAction: String = "—"

    init(service: PlannedMealService) {
        _viewModel = StateObject(wrappedValue: PlannedMealViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                contextSection
                actionsSection
                stateSection
            }
            .padding(16)
        }
        .navigationTitle("PlannedMeal Debug")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Make sure we have recipes loaded for the "pick an existing
            // recipe" buttons below.
            if recipeService.recipes.isEmpty {
                await recipeService.fetchRecipes()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(.orange)
                Text("DEBUG — remove before ship")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text("Phase 1/2 sanity check for PlannedMeal")
                .font(.headline)
            Text("Week of \(iso(viewModel.weekStart))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Context (household + recipes)

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Context")
            row("Household ID", supabaseManager.currentHouseholdID?.uuidString ?? "—")
            row("Recipes loaded", "\(recipeService.recipes.count)")
            if let first = recipeService.recipes.first {
                row("Recipe #1", "\(first.name) (\(first.id.uuidString.prefix(8))…)")
            }
            if recipeService.recipes.count >= 2 {
                let second = recipeService.recipes[1]
                row("Recipe #2", "\(second.name) (\(second.id.uuidString.prefix(8))…)")
            }
            if let error = viewModel.errorMessage {
                row("Last error", error, tint: .red)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Actions")

            Button {
                Task {
                    Logger.supabase.info("[debug] Load week")
                    await viewModel.load()
                    lastAction = "Loaded week (service.count=\(currentServiceCount))"
                }
            } label: {
                Label("1. Load planned meals for this week", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button {
                Task {
                    guard let recipe = recipeService.recipes.first else {
                        lastAction = "No recipes available — can't add"
                        return
                    }
                    let today = Calendar.current.startOfDay(for: Date())
                    Logger.supabase.info("[debug] Add dinner #1 — \(recipe.name) on \(self.iso(today))")
                    let created = await viewModel.add(
                        recipeID: recipe.id,
                        on: today,
                        mealType: .dinner
                    )
                    if let created {
                        lastAction = "Added #1 id=\(created.id.uuidString.prefix(8))… for \(recipe.name)"
                    } else {
                        lastAction = "Add #1 failed — see error row"
                    }
                }
            } label: {
                Label("2. Add dinner for today (recipe #1)", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(recipeService.recipes.isEmpty || viewModel.isLoading)

            Button {
                Task {
                    guard recipeService.recipes.count >= 2 else {
                        lastAction = "Only \(recipeService.recipes.count) recipe(s) — need a second"
                        return
                    }
                    let recipe = recipeService.recipes[1]
                    let today = Calendar.current.startOfDay(for: Date())
                    Logger.supabase.info("[debug] Add dinner #2 — \(recipe.name) on \(self.iso(today))")
                    let created = await viewModel.add(
                        recipeID: recipe.id,
                        on: today,
                        mealType: .dinner
                    )
                    if let created {
                        lastAction = "Added #2 id=\(created.id.uuidString.prefix(8))… for \(recipe.name)"
                    } else {
                        lastAction = "Add #2 failed — see error row"
                    }
                }
            } label: {
                Label("3. Add a second dinner for today (recipe #2)", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(recipeService.recipes.count < 2 || viewModel.isLoading)

            Button {
                printGroupedState()
                lastAction = "Printed grouped state to console"
            } label: {
                Label("4. Print grouped state to console", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            row("Last action", lastAction)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Grouped state

    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Grouped state (viewModel.plansByDateByType)")

            if viewModel.plansByDateByType.isEmpty {
                Text("No planned meals loaded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.weekDates, id: \.self) { day in
                    dayBlock(day)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func dayBlock(_ day: Date) -> some View {
        let mealsByType = viewModel.plansByDateByType[day] ?? [:]
        VStack(alignment: .leading, spacing: 4) {
            Text(iso(day))
                .font(.subheadline.weight(.semibold))

            if mealsByType.isEmpty {
                Text("  (no meals)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(PlannedMeal.MealType.displayOrder) { type in
                    let meals = mealsByType[type] ?? []
                    if !meals.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("  \(type.displayName) (\(meals.count))")
                                .font(.footnote.weight(.medium))
                            ForEach(meals) { meal in
                                mealRow(meal)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        let name = recipeService.recipes.first(where: { $0.id == meal.recipeId })?.name ?? "(unknown recipe)"
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("    • \(name)")
                .font(.footnote)
            Spacer(minLength: 8)
            Text("sort=\(meal.sortOrder)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Button {
                Task {
                    Logger.supabase.info("[debug] Delete \(meal.id.uuidString)")
                    let ok = await viewModel.remove(meal.id)
                    lastAction = ok
                        ? "Deleted \(meal.id.uuidString.prefix(8))…"
                        : "Delete failed — see error row"
                }
            } label: {
                Image(systemName: "trash")
                    .font(.footnote)
            }
            .buttonStyle(.borderless)
            .tint(.red)
        }
    }

    // MARK: - Helpers

    private var currentServiceCount: Int {
        viewModel.plansByDateByType.values
            .flatMap { $0.values }
            .reduce(0) { $0 + $1.count }
    }

    private func iso(_ date: Date) -> String {
        PlannedMealService.isoDate(from: date)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func row(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.footnote)
                .foregroundStyle(tint)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func printGroupedState() {
        Logger.supabase.info("[debug] ===== PlannedMealViewModel state =====")
        Logger.supabase.info("[debug] weekStart=\(iso(self.viewModel.weekStart)), isLoading=\(self.viewModel.isLoading)")
        for day in viewModel.weekDates {
            let byType = viewModel.plansByDateByType[day] ?? [:]
            if byType.isEmpty { continue }
            Logger.supabase.info("[debug] \(self.iso(day)):")
            for type in PlannedMeal.MealType.displayOrder {
                guard let meals = byType[type], !meals.isEmpty else { continue }
                for meal in meals {
                    let name = recipeService.recipes.first(where: { $0.id == meal.recipeId })?.name ?? "?"
                    Logger.supabase.info("[debug]   \(type.rawValue) sort=\(meal.sortOrder) id=\(meal.id.uuidString) recipe=\"\(name)\"")
                }
            }
        }
        Logger.supabase.info("[debug] ======================================")
    }
}

#endif
