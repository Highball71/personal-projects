//
//  PlannedMealViewModel.swift
//  FluffyList
//
//  Phase 2 of multi-meal-per-day.
//  Loads PlannedMeals for the selected week and exposes them grouped as:
//
//      [Date: [PlannedMeal.MealType: [PlannedMeal]]]
//
//  UI is expected to iterate `weekDates` and, for each date, iterate
//  `PlannedMeal.MealType.displayOrder` to render sections in a stable
//  order.
//

import Combine
import Foundation
import os

@MainActor
final class PlannedMealViewModel: ObservableObject {
    /// First day of the week currently loaded. Changing this re-fetches.
    @Published var weekStart: Date

    /// Grouped view of `service.plannedMeals`, keyed by start-of-day
    /// (stripped of time) and then by mealType. Recomputed whenever the
    /// service's `plannedMeals` change.
    @Published private(set) var plansByDateByType: [Date: [PlannedMeal.MealType: [PlannedMeal]]] = [:]

    /// The 7 dates in the current week, each at start-of-day in the
    /// user's calendar. Convenient for ForEach.
    var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
        .map { Calendar.current.startOfDay(for: $0) }
    }

    var isLoading: Bool { service.isLoading }
    var errorMessage: String? { service.errorMessage }

    private let service: PlannedMealService
    private var cancellables: Set<AnyCancellable> = []

    init(service: PlannedMealService, weekStart: Date? = nil) {
        self.service = service
        self.weekStart = weekStart ?? DateHelper.startOfWeek(containing: Date())

        // Regroup whenever the underlying service's rows change. We
        // don't store the array locally — the service is the source of
        // truth; we only cache the grouped view.
        service.$plannedMeals
            .sink { [weak self] meals in
                self?.plansByDateByType = Self.group(meals)
            }
            .store(in: &cancellables)
    }

    // MARK: - Lookups

    /// Ordered PlannedMeals for a given date and meal type.
    /// Returns an empty array when the slot has nothing planned.
    func meals(on date: Date, type: PlannedMeal.MealType) -> [PlannedMeal] {
        let key = Calendar.current.startOfDay(for: date)
        return plansByDateByType[key]?[type] ?? []
    }

    /// All planned meals for a given date, across all meal types,
    /// in (mealType displayOrder, sortOrder) order. Handy for any
    /// flat rendering or counts.
    func meals(on date: Date) -> [PlannedMeal] {
        let key = Calendar.current.startOfDay(for: date)
        guard let byType = plansByDateByType[key] else { return [] }
        return PlannedMeal.MealType.displayOrder.flatMap { type in
            byType[type] ?? []
        }
    }

    // MARK: - Actions

    /// Load (or reload) the current week from Supabase.
    func load() async {
        await service.fetchPlans(weekStart: weekStart)
    }

    /// Move to a different week and reload.
    func setWeek(start: Date) async {
        weekStart = start
        await service.fetchPlans(weekStart: start)
    }

    /// Add a PlannedMeal and refresh. Defaults mealType to .dinner so
    /// the common "add to today" path doesn't force callers to pick.
    @discardableResult
    func add(recipeID: UUID, on date: Date, mealType: PlannedMeal.MealType = .dinner) async -> PlannedMeal? {
        let created = await service.addPlannedMeal(
            recipeID: recipeID,
            on: date,
            mealType: mealType
        )
        await service.fetchPlans(weekStart: weekStart)
        return created
    }

    /// Remove a single PlannedMeal and refresh.
    @discardableResult
    func remove(_ id: UUID) async -> Bool {
        let ok = await service.deletePlannedMeal(id)
        await service.fetchPlans(weekStart: weekStart)
        return ok
    }

    // MARK: - Grouping

    /// Group a flat array of PlannedMeals into [Date: [PlannedMeal.MealType: [PlannedMeal]]].
    /// Keyed on start-of-day so lookups by any Date on the same calendar
    /// day hit the same bucket. Inner arrays are sorted by sortOrder
    /// then createdAt for deterministic display.
    private static func group(_ meals: [PlannedMeal]) -> [Date: [PlannedMeal.MealType: [PlannedMeal]]] {
        var result: [Date: [PlannedMeal.MealType: [PlannedMeal]]] = [:]
        for meal in meals {
            let dayKey = Calendar.current.startOfDay(for: meal.date)
            result[dayKey, default: [:]][meal.mealType, default: []].append(meal)
        }
        for (day, byType) in result {
            for (type, items) in byType {
                result[day]?[type] = items.sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                    return lhs.createdAt < rhs.createdAt
                }
            }
        }
        return result
    }
}
