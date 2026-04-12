//
//  MealPlanView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// Captures the date + meal type for a tapped slot so the recipe picker
/// sheet always has valid data when it renders.
struct MealSlotSelection: Identifiable {
    let id = UUID()
    let date: Date
    let mealType: MealType
}

/// Tracks which sheet to present from the meal plan view.
/// Using a single enum avoids conflicts from multiple .sheet modifiers.
enum MealPlanSheet: Identifiable {
    case pickRecipe(MealSlotSelection)
    case surpriseMe(MealSlotSelection)
    case suggestWeek

    var id: String {
        switch self {
        case .pickRecipe(let s): return "pick-\(s.id)"
        case .surpriseMe(let s): return "surprise-\(s.id)"
        case .suggestWeek: return "suggest"
        }
    }

    /// The slot this sheet action is targeting (nil for week-level suggestions)
    var slot: MealSlotSelection? {
        switch self {
        case .pickRecipe(let s), .surpriseMe(let s): return s
        case .suggestWeek: return nil
        }
    }
}

/// The weekly meal planning view. Shows 7 days in a vertical scroll,
/// each with breakfast/lunch/dinner slots. Navigate between weeks
/// with the arrow buttons at the top.
///
/// When a Head Cook is set, non-Head-Cook users create suggestions
/// instead of directly filling meal slots. The Head Cook sees
/// approve/reject controls next to each suggestion.
struct MealPlanView: View {
    @FetchRequest(
        entity: CDMealPlan.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMealPlan.date, ascending: true)]
    ) private var allMealPlans: FetchedResults<CDMealPlan>

    @FetchRequest(
        entity: CDMealSuggestion.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMealSuggestion.date, ascending: true)]
    ) private var allSuggestions: FetchedResults<CDMealSuggestion>

    @FetchRequest(
        entity: CDHouseholdMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDHouseholdMember.name, ascending: true)]
    ) private var members: FetchedResults<CDHouseholdMember>

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(MealPlanningStore.self) private var mealPlanningStore
    @Environment(\.scenePhase) private var scenePhase

    // Device-local identity — matches the "You are" picker in Settings
    @AppStorage("currentUserName") private var currentUserName: String = ""

    // The first day of the currently displayed week.
    // Initialized once to today's week; we also auto-resync it when the view
    // appears or the app returns to the foreground so it can't go stale if
    // the app was left open across a day boundary.
    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())

    // The slot the user just tapped — drives the confirmation dialog
    @State private var selectedSlot: MealSlotSelection?
    @State private var showingSlotOptions = false

    // Drives whichever sheet is currently presented
    @State private var activeSheet: MealPlanSheet?

    /// The 7 days of the currently displayed week
    var weekDays: [Date] {
        DateHelper.weekDays(startingFrom: weekStartDate)
    }

    /// The designated Head Cook, if one is set
    private var headCook: CDHouseholdMember? {
        members.first(where: { $0.isHeadCook })
    }

    /// Whether the current device user is the Head Cook
    private var isCurrentUserHeadCook: Bool {
        guard let headCook else { return false }
        return !currentUserName.isEmpty
            && headCook.name.lowercased() == currentUserName.lowercased()
    }

    /// Whether the approval flow is active (Head Cook is set)
    private var approvalFlowActive: Bool {
        headCook != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    weekNavigationHeader

                    ForEach(weekDays, id: \.self) { day in
                        DayColumnView(
                            date: day,
                            mealPlans: mealPlans(for: day),
                            suggestions: suggestions(for: day),
                            isHeadCook: isCurrentUserHeadCook,
                            approvalFlowActive: approvalFlowActive,
                            onSlotTapped: { mealType in
                                selectedSlot = MealSlotSelection(date: day, mealType: mealType)
                                showingSlotOptions = true
                            },
                            onApproveSuggestion: { suggestion in
                                mealPlanningStore.approveSuggestion(suggestion)
                            },
                            onRejectSuggestion: { suggestion in
                                mealPlanningStore.rejectSuggestion(suggestion)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.fluffyBackground)
            .navigationTitle("Meal Plan")
            .onAppear {
                resyncWeekIfStale()
                // Heal any duplicate CDMealPlan / CDMealSuggestion rows
                // left behind by earlier builds. Gated behind a UserDefaults
                // flag so it only runs once per install. Key is `V2` because
                // the V1 pass used a floating-point timeIntervalSince1970
                // key which could miss some duplicates; V2 uses an ISO
                // yyyy-MM-dd string key that's always stable.
                let dedupeKey = "hasRunDedupeV2"
                if !UserDefaults.standard.bool(forKey: dedupeKey) {
                    mealPlanningStore.dedupeMealPlans()
                    mealPlanningStore.dedupeSuggestions()
                    UserDefaults.standard.set(true, forKey: dedupeKey)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resyncWeekIfStale() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Labeled button (icon + text) so it's obvious this plans the week,
                    // rather than a bare dice icon.
                    Button {
                        activeSheet = .suggestWeek
                    } label: {
                        Label("Suggest Week", systemImage: "wand.and.stars")
                    }
                    .accessibilityLabel("Suggest meals for the whole week")
                }
            }
            // Different options depending on whether the slot already has a recipe
            .confirmationDialog(
                confirmationDialogTitle,
                isPresented: $showingSlotOptions,
                titleVisibility: .visible,
                presenting: selectedSlot
            ) { slot in
                if slotHasRecipe(slot) {
                    Button("Pick a Different Recipe") {
                        activeSheet = .pickRecipe(slot)
                    }
                    Button("Surprise Me") {
                        activeSheet = .surpriseMe(slot)
                    }
                    Button("Remove from Plan", role: .destructive) {
                        mealPlanningStore.clearMealSlot(date: slot.date, mealType: slot.mealType)
                    }
                } else {
                    Button("Pick a Recipe") {
                        activeSheet = .pickRecipe(slot)
                    }
                    Button("Surprise Me") {
                        activeSheet = .surpriseMe(slot)
                    }
                }
            } message: { slot in
                if let name = recipeName(for: slot) {
                    Text("Currently assigned: \(name)")
                } else {
                    Text("Choose how to fill this slot.")
                }
            }
            // Single sheet modifier handles all presentation
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .pickRecipe(let slot):
                    RecipePickerView { recipe in
                        handleRecipeSelection(recipe, for: slot)
                    }
                case .surpriseMe(let slot):
                    SurpriseMealView { recipe in
                        handleRecipeSelection(recipe, for: slot)
                    }
                case .suggestWeek:
                    SuggestMealsView(weekStartDate: weekStartDate) { suggestions in
                        for (date, recipe) in suggestions {
                            let slot = MealSlotSelection(date: date, mealType: .dinner)
                            handleRecipeSelection(recipe, for: slot)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Week Navigation

    private var weekNavigationHeader: some View {
        HStack {
            Button(action: goToPreviousWeek) {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(weekRangeText)
                .font(.headline)

            Spacer()

            Button(action: goToNextWeek) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    /// Displays something like "Feb 3 - Feb 9"
    private var weekRangeText: String {
        let start = DateHelper.dayMonth(for: weekStartDate)
        let end = DateHelper.dayMonth(for: weekDays.last ?? weekStartDate)
        return "\(start) – \(end)"
    }

    private func goToPreviousWeek() {
        weekStartDate = Calendar.current.date(
            byAdding: .weekOfYear, value: -1, to: weekStartDate
        ) ?? weekStartDate
    }

    private func goToNextWeek() {
        weekStartDate = Calendar.current.date(
            byAdding: .weekOfYear, value: 1, to: weekStartDate
        ) ?? weekStartDate
    }

    /// Snaps `weekStartDate` forward to the week containing today if the
    /// currently visible week no longer contains today. This prevents an
    /// @State value that was initialized on a previous day from silently
    /// writing meal-plan dates into the wrong week. Respects intentional
    /// in-session navigation: if the user chevroned to an adjacent week
    /// that still contains today, nothing changes.
    private func resyncWeekIfStale() {
        let today = DateHelper.stripTime(from: Date())
        let visibleStart = DateHelper.stripTime(from: weekStartDate)
        guard let visibleEnd = Calendar.current.date(byAdding: .day, value: 7, to: visibleStart) else {
            return
        }
        let todayIsInVisibleWeek = today >= visibleStart && today < visibleEnd
        if !todayIsInVisibleWeek {
            weekStartDate = DateHelper.startOfWeek(containing: Date())
        }
    }

    // MARK: - Meal Plan Data

    /// Get just the meal plans for a specific day
    private func mealPlans(for date: Date) -> [CDMealPlan] {
        let dayStart = DateHelper.stripTime(from: date)
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        // Half-open [dayStart, nextDayStart) — tolerant of any sub-second
        // drift in plan.date (same fix applied to the grocery filter).
        return Array(allMealPlans).filter { plan in
            plan.date >= dayStart && plan.date < nextDayStart
        }
    }

    /// Get pending suggestions for a specific day
    private func suggestions(for date: Date) -> [CDMealSuggestion] {
        let dayStart = DateHelper.stripTime(from: date)
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        return Array(allSuggestions).filter { suggestion in
            suggestion.date >= dayStart && suggestion.date < nextDayStart
        }
    }

    // MARK: - Slot State Helpers

    /// Whether the selected slot already has a recipe assigned.
    private func slotHasRecipe(_ slot: MealSlotSelection) -> Bool {
        let dayStart = DateHelper.stripTime(from: slot.date)
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        return allMealPlans.contains { plan in
            plan.date >= dayStart
                && plan.date < nextDayStart
                && plan.mealTypeRaw == slot.mealType.rawValue
        }
    }

    /// The recipe assigned to a specific slot, if any.
    private func recipeName(for slot: MealSlotSelection) -> String? {
        let dayStart = DateHelper.stripTime(from: slot.date)
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        return allMealPlans.first(where: { plan in
            plan.date >= dayStart
                && plan.date < nextDayStart
                && plan.mealTypeRaw == slot.mealType.rawValue
        })?.recipe?.name
    }

    /// Title for the slot confirmation dialog — "Monday Dinner" style so the
    /// user knows which slot they tapped before choosing an action.
    private var confirmationDialogTitle: String {
        guard let slot = selectedSlot else { return "" }
        let day = DateHelper.shortDayName(for: slot.date)
        let meal = slot.mealType.rawValue
        return "\(day) \(meal)"
    }

    // MARK: - Recipe Selection Logic

    /// Decides whether to assign directly or create a suggestion based on
    /// whether a Head Cook is set and who the current user is.
    private func handleRecipeSelection(_ recipe: CDRecipe, for slot: MealSlotSelection) {
        if approvalFlowActive && !isCurrentUserHeadCook {
            mealPlanningStore.createSuggestion(
                recipe, on: slot.date, mealType: slot.mealType, suggestedBy: currentUserName
            )
        } else {
            mealPlanningStore.assignRecipe(recipe, on: slot.date, mealType: slot.mealType)
        }
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    MealPlanView()
        .environment(\.managedObjectContext, context)
}
