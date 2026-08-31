//
//  SupabaseMealPlanView.swift
//  FluffyList
//
//  "The Press" week view: masthead ("This Week"), an italic line of
//  state, one ruled row per day (day/date column in ink, meal name
//  over uppercase metadata), one household meal plus up to one meal
//  per member per day (per-person meals, Phase 3) — member meals as
//  indented lines with a small-caps name kicker — tap-to-control
//  action sheet (Replace / Remove / Cancel) on each meal, and the
//  "Build the grocery list" text-link CTA.
//

import os
import SwiftUI

/// What the recipe picker is being opened for: a day, and who the
/// meal should default to (nil = EVERYONE / the household slot).
struct MealPickerContext: Identifiable {
    let id = UUID()
    let date: Date
    let memberID: UUID?
}

/// The meal a tapped day-row line controls: drives the
/// Replace / Remove action sheet.
struct MealActionTarget: Identifiable {
    let id = UUID()
    let date: Date
    let plan: MealPlanRow
    /// Resolved assignment — nil for household meals AND for orphaned
    /// rows whose member no longer exists (they render as household).
    let memberID: UUID?
    let memberName: String?
    /// Meals on this date, so the sheet can offer "Clear the whole
    /// day" when there's more than one.
    let dayMealCount: Int
}

struct SupabaseMealPlanView: View {
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var groceryService: GroceryService
    @EnvironmentObject private var householdService: HouseholdService

    @Binding var selectedTab: AppTab

    @State private var weekStart: Date = DateHelper.startOfWeek(containing: Date())
    @State private var pickerContext: MealPickerContext?
    /// When set, shows the Replace / Remove / Cancel action sheet
    /// for one specific meal on a date.
    @State private var mealAction: MealActionTarget?
    @State private var isAssigning = false
    /// Line shown in the assigning overlay — the copy-week action
    /// reuses the overlay with its own wording.
    @State private var assigningText = "Adding to meal plan..."
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
            .sheet(item: $pickerContext) { context in
                RecipePickerSheet(
                    recipes: recipeService.recipes,
                    members: householdService.members,
                    initialMemberID: context.memberID,
                    ingredientsByRecipeID: recipeService.ingredientsByRecipeID,
                    onPick: { recipe, memberID in
                        pickerContext = nil
                        Task { await addMeal(recipe, to: context.date, for: memberID) }
                    },
                    onCancel: { pickerContext = nil }
                )
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
            }
            .confirmationDialog(
                mealActionTitle,
                isPresented: mealActionBinding,
                titleVisibility: .visible,
                presenting: mealAction
            ) { target in
                Button("Replace Meal") {
                    mealAction = nil
                    pickerContext = MealPickerContext(date: target.date, memberID: target.memberID)
                }
                Button("Remove Meal", role: .destructive) {
                    mealAction = nil
                    Task { await removeMeal(target) }
                }
                if target.dayMealCount > 1 {
                    Button("Clear the Whole Day", role: .destructive) {
                        mealAction = nil
                        Task { await removeSlot(date: target.date) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    mealAction = nil
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
                        FluffyTextLink(title: "Copy last week") {
                            Task { await copyLastWeek() }
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

                VStack(alignment: .leading, spacing: 20) {
                    if hasOpenFutureDay {
                        FluffyTextLink(title: "Copy last week") {
                            Task { await copyLastWeek() }
                        }
                    }
                    FluffyTextLink(title: "Build the grocery list") {
                        Task {
                            await groceryService.fetchItems()
                            selectedTab = .groceries
                        }
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
        let dayPlan = DayPlan.build(from: plans(for: date), members: householdService.members)

        if dayPlan.isEmpty {
            emptyDayRow(date)
        } else {
            filledDayRow(date, dayPlan: dayPlan)
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
                pickerContext = MealPickerContext(date: date, memberID: nil)
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

    /// Day row with at least one meal. The household meal is the
    /// primary line; member meals render as indented lines beneath it
    /// with a small-caps name kicker. Each line is its own tap target
    /// opening the Replace / Remove action sheet for exactly that
    /// meal. Legacy multi-row household slots render every row (they
    /// collapse on the next assign); meals orphaned by a member delete
    /// arrive here with member_id NULL (013 trigger) and render as
    /// household meals.
    private func filledDayRow(_ date: Date, dayPlan: DayPlan) -> some View {
        let today = Calendar.current.isDateInToday(date)
        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())

        return HStack(alignment: .top, spacing: 14) {
            dateColumn(date: date, today: today)

            VStack(alignment: .leading, spacing: 12) {
                // Household slot: the primary line. When only member
                // meals exist, hold its place with a tappable
                // "Nothing for everyone" so the household meal can
                // still be added (future days only).
                if dayPlan.householdMeals.isEmpty {
                    if !isPast {
                        emptyHouseholdLine(date)
                    }
                } else {
                    ForEach(dayPlan.householdMeals) { plan in
                        mealLine(plan, member: nil, date: date, isPast: isPast,
                                 dayMealCount: dayPlan.mealCount)
                    }
                }

                ForEach(dayPlan.memberMeals, id: \.plan.id) { memberMeal in
                    mealLine(memberMeal.plan, member: memberMeal.member,
                             date: date, isPast: isPast,
                             dayMealCount: dayPlan.mealCount)
                        .padding(.leading, 14)
                }
            }

            Spacer()

            // Add another meal (a person's, or replace via chips).
            // Hidden on past days — they're read-only.
            if !isPast {
                Button {
                    pickerContext = MealPickerContext(
                        date: date,
                        memberID: defaultPickerMember(for: dayPlan)
                    )
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.fluffyAccent)
                        .padding(.top, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    /// One tappable meal line: optional small-caps member kicker, the
    /// recipe title, and (household meals only) the category/time
    /// metadata line.
    private func mealLine(
        _ plan: MealPlanRow,
        member: HouseholdMemberRow?,
        date: Date,
        isPast: Bool,
        dayMealCount: Int
    ) -> some View {
        Button {
            guard !isPast else { return }
            mealAction = MealActionTarget(
                date: date,
                plan: plan,
                memberID: member?.id,
                memberName: member?.displayName,
                dayMealCount: dayMealCount
            )
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if let member {
                    FluffyMetadataLine(text: member.displayName)
                }
                if let recipe = recipeService.recipes.first(where: { $0.id == plan.recipeID }) {
                    Text(recipe.name)
                        .font(.fluffyHeadline)
                        .fluffyTracking(-0.01, at: 19)
                        .foregroundStyle(isPast ? Color.fluffyTertiary : Color.fluffyPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if member == nil {
                        let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
                        FluffyMetadataLine(text: total > 0
                             ? "\(recipe.category) \u{00B7} \(total) min"
                             : recipe.category)
                    }
                } else {
                    // Plan row exists but its recipe isn't loaded
                    // (or was deleted). Show a hint so the user can
                    // still tap to Replace / Remove.
                    Text("Tap to update")
                        .font(.fluffyHeadline)
                        .fluffyTracking(-0.01, at: 19)
                        .foregroundStyle(Color.fluffySecondary)
                    FluffyMetadataLine(text: "MEAL NEEDS ATTENTION")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    /// The household slot's placeholder when a day holds only member
    /// meals — tappable to add the whole-family meal.
    private func emptyHouseholdLine(_ date: Date) -> some View {
        Button {
            pickerContext = MealPickerContext(date: date, memberID: nil)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing for everyone")
                    .font(.fluffyHeadline)
                    .fluffyTracking(-0.01, at: 19)
                    .foregroundStyle(Color.fluffyTertiary)
                FluffyMetadataLine(text: "TAP TO ADD")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Default assignment when the day row's "+" opens the picker:
    /// EVERYONE while the household slot is open; otherwise the first
    /// member without a meal that day (so the plus naturally walks
    /// through the family); EVERYONE again when the day is saturated.
    private func defaultPickerMember(for dayPlan: DayPlan) -> UUID? {
        guard !dayPlan.householdMeals.isEmpty else { return nil }
        let planned = Set(dayPlan.memberMeals.map(\.member.id))
        return householdService.members.first { !planned.contains($0.id) }?.id
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
                    Text(assigningText)
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

    /// Title shown above the Replace / Remove action sheet —
    /// "Pasta Primavera" or "Pasta Primavera — for Maya".
    private var mealActionTitle: String {
        guard let target = mealAction,
              let recipe = recipeService.recipes.first(where: { $0.id == target.plan.recipeID })
        else { return "This Meal" }
        if let name = target.memberName {
            return "\(recipe.name) \u{2014} for \(name)"
        }
        return recipe.name
    }

    /// Bool binding driving the confirmationDialog from `mealAction`.
    private var mealActionBinding: Binding<Bool> {
        Binding(
            get: { mealAction != nil },
            set: { if !$0 { mealAction = nil } }
        )
    }

    // MARK: - Actions

    /// True when at least one future day has an open slot — household
    /// or member — i.e. copy-last-week could actually land something.
    /// (Whether last week can fill a given open slot isn't knowable
    /// here; the copy itself applies the exact per-slot skip rules.)
    private var hasOpenFutureDay: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let slotCapacity = 1 + householdService.members.count
        return weekDates.contains { date in
            plans(for: date).count < slotCapacity &&
            Calendar.current.startOfDay(for: date) >= today
        }
    }

    /// Copy the previous week's meals forward. Days already planned
    /// are kept and past days are skipped silently (decided
    /// 2026-08-27) — see MealPlanService.copyPreviousWeek.
    private func copyLastWeek() async {
        assigningText = "Copying last week..."
        isAssigning = true
        defer {
            isAssigning = false
            assigningText = "Adding to meal plan..."
        }

        guard let result = await mealPlanService.copyPreviousWeek(
            weekStart: weekStart,
            recipeService: recipeService,
            groceryService: groceryService
        ) else {
            actionErrorMessage = "Couldn't copy last week. Please try again."
            return
        }

        await reloadWeek()

        if result.failed > 0 {
            actionErrorMessage = "Copied \(result.copied) meal\(result.copied == 1 ? "" : "s"), but \(result.failed) didn't make it. Please try again."
            return
        }

        withAnimation { toastMessage = copyToastText(result) }
    }

    /// Press-voice summary line for the copy toast.
    private func copyToastText(_ result: CopyWeekResult) -> String {
        if result.sourceEmpty { return "Last week was empty." }
        let copied = result.copied
        if copied == 0 {
            if result.skippedFilled > 0 { return "Those days are already planned." }
            if result.skippedPast > 0 { return "Those days have passed." }
            return "Nothing to copy."
        }
        let dinners = copied == 1 ? "dinner" : "dinners"
        if result.skippedFilled > 0 {
            let kept = result.skippedFilled == 1 ? "day you'd planned" : "days you'd planned"
            return "Copied \(word(copied)) \(dinners); kept the \(kept)."
        }
        return "Copied \(word(copied)) \(dinners) from last week."
    }

    /// Fetch the current week and record whether it succeeded, so a
    /// failed load shows the retry banner instead of an empty week.
    private func reloadWeek() async {
        let ok = await mealPlanService.fetchPlans(weekStart: weekStart)
        fetchFailed = !ok
    }

    private func addMeal(_ recipe: RecipeRow, to date: Date, for memberID: UUID? = nil) async {
        isAssigning = true
        defer { isAssigning = false }

        let result = await mealPlanService.addMealWithGroceries(
            recipe: recipe,
            on: date,
            memberID: memberID,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else {
            actionErrorMessage = "Couldn't add that meal. Please try again."
            return
        }
        await reloadWeek()
        let day = fullDayName(for: date)
        let memberName = memberID.flatMap { id in
            householdService.members.first { $0.id == id }?.displayName
        }
        withAnimation {
            toastMessage = memberName.map { "Added for \($0) \u{2014} \(day)" }
                ?? "Added to \(day)"
        }
    }

    /// Remove one specific meal (unwind-first, per-row).
    private func removeMeal(_ target: MealActionTarget) async {
        Logger.supabase.info("MealPlan removeMeal: plan=\(target.plan.id.uuidString)")
        let removed = await mealPlanService.removeMeal(target.plan.id, groceryService: groceryService)
        if !removed {
            actionErrorMessage = "Couldn't remove that meal. Please try again."
        }
        await reloadWeek()
    }

    /// Remove ALL meals on a date — the "Clear the Whole Day" action.
    /// clearDayWithGroceries settles groceries for every removed meal.
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
    /// Household members for the assignment chips. Empty hides the row
    /// (the pick is a household meal, exactly the pre-Phase-3 flow).
    var members: [HouseholdMemberRow] = []
    /// Preselected assignment — set when the picker opens from a
    /// specific meal line ("Replace" on Maya's meal preselects MAYA).
    var initialMemberID: UUID? = nil
    /// Lowercased ingredient names per recipe, for the dietary hint.
    var ingredientsByRecipeID: [UUID: [String]] = [:]
    let onPick: (RecipeRow, UUID?) -> Void
    let onCancel: () -> Void

    /// nil = EVERYONE (the household slot) — the default.
    @State private var selectedMemberID: UUID?

    private var selectedMember: HouseholdMemberRow? {
        selectedMemberID.flatMap { id in members.first { $0.id == id } }
    }

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
                        if !members.isEmpty {
                            Section("Who is this meal for?") {
                                FluffyAssignmentChips(
                                    members: members,
                                    selection: $selectedMemberID
                                )
                                .padding(.vertical, 4)
                            }
                        }

                        Section {
                            Button {
                                if let pick = recipes.randomElement() {
                                    Logger.supabase.info("Surprise Me: picked \"\(pick.name)\" id=\(pick.id.uuidString)")
                                    onPick(pick, selectedMemberID)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "dice.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.fluffyAccent)
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
                                    onPick(recipe, selectedMemberID)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(recipe.name)
                                                .font(.fluffyHeadline)
                                                .foregroundStyle(Color.fluffyPrimary)
                                            Text(recipe.category.capitalized)
                                                .font(.fluffyCaption)
                                                .foregroundStyle(Color.fluffySecondary)
                                            // Keyword-only dietary hint for
                                            // the selected person — a gentle
                                            // flag, never a block.
                                            if let member = selectedMember,
                                               let conflict = DietaryMatch.conflict(
                                                   for: member,
                                                   recipe: recipe,
                                                   ingredientNames: ingredientsByRecipeID[recipe.id]
                                               ) {
                                                FluffyMetadataLine(
                                                    text: DietaryMatch.hintText(for: conflict),
                                                    color: .fluffyAccent
                                                )
                                            }
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
        .onAppear { selectedMemberID = initialMemberID }
    }
}

// MARK: - Date Identifiable

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
