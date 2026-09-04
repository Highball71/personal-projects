//
//  SupabaseRecipeListView.swift
//  FluffyList
//
//  "The Press" recipe browse. Masthead with the recipe count as
//  dateline, an underlined search rule, plain underlined-word
//  category chips, a full-width halftone hero with an ink-2 kicker,
//  and ruled vertical lists — the card grid is retired.
//

import os
import SwiftUI

struct SupabaseRecipeListView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var groceryService: GroceryService

    @State private var showingAddRecipe = false
    @State private var showingHouseholdInfo = false
    @State private var searchText = ""
    @State private var selectedTag: BrowseTag = .all
    @State private var showFavoritesOnly = false
    @State private var recipeToPlan: RecipeRow?
    @State private var toastMessage: String?
    @State private var recipeToDelete: RecipeRow?
    @State private var showDeleteBlockedAlert = false
    @State private var showDeleteConfirmAlert = false
    /// True when the last recipe fetch failed — drives the retry banner
    /// and stops a failed load from rendering as "No recipes yet."
    @State private var fetchFailed = false
    /// Short human message for a failed write (plan/favorite/delete).
    @State private var actionErrorMessage: String?

    private static let fetchErrorText =
        "Couldn't load your recipes. Check your connection and tap Retry."

    /// Seasonal Suggestions v1: region setting; "" = dormant.
    @AppStorage("seasonalRegion") private var seasonalRegionRaw = ""

    /// IDs of recipes in season right now — the small leaf badge on
    /// list rows. Empty (no badges anywhere) when the region is unset.
    private var seasonalIDs: Set<UUID> {
        SeasonalMatch.seasonalRecipeIDs(
            recipes: recipeService.recipes,
            ingredientsByRecipeID: recipeService.ingredientsByRecipeID,
            region: USRegion(rawValue: seasonalRegionRaw),
            month: Calendar.current.component(.month, from: Date())
        )
    }

    /// The "In season now" shelf at the top of the browse — the same
    /// computation as the picker's shelf (SeasonalMatch.inSeasonNow,
    /// best match first, capped at 8), keyed to the current month.
    /// Empty when dormant (region unset), which hides the shelf.
    private var seasonalShelfPicks: [SeasonalMatch.Pick] {
        SeasonalMatch.inSeasonNow(
            recipes: recipeService.recipes,
            ingredientsByRecipeID: recipeService.ingredientsByRecipeID,
            region: USRegion(rawValue: seasonalRegionRaw),
            month: Calendar.current.component(.month, from: Date())
        )
    }

    /// Collapsed state of the shelf, remembered for the session (not
    /// across launches — a new day may bring a new month's harvest,
    /// and the shelf should get to reintroduce itself).
    @State private var seasonalShelfCollapsed = SeasonalShelfSession.isCollapsed

    // MARK: - Filtering

    /// Recipes filtered by favorites toggle, browse tag, then search text.
    private var displayedRecipes: [RecipeRow] {
        var result = recipeService.recipes

        // Favorites filter
        if showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }

        // Browse tag filter
        if selectedTag != .all {
            result = result.filter { recipe in
                selectedTag.matches(
                    recipe,
                    ingredientNames: recipeService.ingredientsByRecipeID[recipe.id]
                )
            }
        }

        // Search text filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { recipe in
                if recipe.name.lowercased().contains(query) { return true }
                if let names = recipeService.ingredientsByRecipeID[recipe.id],
                   names.contains(where: { $0.contains(query) }) { return true }
                return false
            }
        }

        return result
    }

    /// The hero card recipe — first favorite, or newest recipe.
    private var heroRecipe: RecipeRow? {
        displayedRecipes.first { $0.isFavorite } ?? displayedRecipes.first
    }

    /// Grid recipes — everything except the hero and recently-added.
    private var gridRecipes: [RecipeRow] {
        let excludeIDs = Set(
            [heroRecipe?.id].compactMap { $0 } + recentlyAdded.map(\.id)
        )
        return displayedRecipes.filter { !excludeIDs.contains($0.id) }
    }

    /// The 4 most recently created recipes (by createdAt), excluding
    /// the hero, for the horizontal "Recently Added" strip.
    /// Deduplicated by `id` — when the same recipe appears more than
    /// once we keep the most-recently-created occurrence (which sorts
    /// first under our descending order).
    private var recentlyAdded: [RecipeRow] {
        let heroID = heroRecipe?.id
        let sorted = displayedRecipes
            .filter { $0.id != heroID }
            .sorted { $0.createdAt > $1.createdAt }

        var seen = Set<UUID>()
        var unique: [RecipeRow] = []
        for recipe in sorted where seen.insert(recipe.id).inserted {
            unique.append(recipe)
            if unique.count == 4 { break }
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
                        onRetry: { Task { await reloadRecipes() } },
                        onDismiss: { fetchFailed = false }
                    )
                } else if let message = actionErrorMessage {
                    FluffyErrorBanner(
                        message: message,
                        onDismiss: { actionErrorMessage = nil }
                    )
                }

                Group {
                    if fetchFailed && recipeService.recipes.isEmpty {
                        // A failed load with nothing cached must not render
                        // as "No recipes yet" — the banner above explains it.
                        Color.clear
                    } else if recipeService.isLoading && recipeService.recipes.isEmpty {
                        // Never visually empty: masthead + italic status.
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                masthead
                                Text("Fetching your recipes\u{2026}")
                                    .font(.fluffyCallout)
                                    .foregroundStyle(Color.fluffySecondary)
                                    .padding(.horizontal, 22)
                                    .padding(.top, 15)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if recipeService.recipes.isEmpty {
                        emptyState
                    } else if displayedRecipes.isEmpty {
                        noMatchesState
                    } else {
                        browseContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.25), value: recipeService.isLoading)
            .background(Color.fluffyBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
            .tint(Color.fluffyAccent)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingHouseholdInfo = true } label: {
                        Image(systemName: "house")
                            .foregroundStyle(Color.fluffyAccent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFavoritesOnly.toggle()
                            }
                        } label: {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .foregroundStyle(showFavoritesOnly ? Color.fluffyAccent : Color.fluffySecondary)
                        }
                        Button { showingAddRecipe = true } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.fluffyAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddRecipe) {
                SupabaseAddRecipeView()
            }
            .sheet(item: $recipeToPlan) { recipe in
                DayPickerSheet(
                    recipe: recipe,
                    members: householdService.members,
                    ingredientNames: recipeService.ingredientsByRecipeID[recipe.id],
                    onPick: { date, memberID in
                        recipeToPlan = nil
                        Task { await addToMealPlan(recipe: recipe, date: date, memberID: memberID) }
                    },
                    onCancel: { recipeToPlan = nil }
                )
            }
            .sheet(isPresented: $showingHouseholdInfo) {
                HouseholdInfoView()
            }
            .refreshable {
                await reloadRecipes()
            }
            .task {
                // The initial fetch runs from SupabaseContentView, which
                // can't surface a failure here. Re-fetch when this tab
                // first appears so a failed load shows the banner instead
                // of the empty state.
                await reloadRecipes()
            }
            .overlay { toastOverlay }
            .onChange(of: recipeService.infoMessage) { _, message in
                // Service-level info notices (e.g. duplicate-recipe
                // detection) get surfaced here as a toast. We clear
                // the service value immediately so it can't re-fire,
                // but defer the toast briefly so it doesn't appear
                // underneath the still-dismissing AddRecipeView sheet.
                guard let message else { return }
                recipeService.infoMessage = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation { toastMessage = message }
                }
            }
            .alert("Recipe In Use", isPresented: $showDeleteBlockedAlert) {
                Button("OK", role: .cancel) { recipeToDelete = nil }
            } message: {
                Text("\(recipeToDelete?.name ?? "This recipe") is on your meal plan. Remove it from the meal plan first before deleting.")
            }
            .alert("Delete Recipe?", isPresented: $showDeleteConfirmAlert) {
                Button("Delete", role: .destructive) {
                    if let recipe = recipeToDelete {
                        Task {
                            if !(await recipeService.deleteRecipe(recipe.id)) {
                                actionErrorMessage = "Couldn't delete that recipe. Please try again."
                            }
                        }
                        recipeToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { recipeToDelete = nil }
            } message: {
                Text("\"\(recipeToDelete?.name ?? "")\" will be permanently deleted.")
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        FluffyMasthead(
            title: "Recipes",
            dateline: "\(recipeService.recipes.count) RECIPES"
        )
        .padding(.horizontal, 22)
    }

    // MARK: - Browse Content

    private var browseContent: some View {
        ScrollView {
            // Computed once per body pass, not per row — scoring every
            // recipe from inside each row would be quadratic.
            let leafIDs = seasonalIDs
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 20)

                searchRule
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                chipBar
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                // "In season now" — the picker's shelf, surfaced
                // before any day is picked. Only in the default browse
                // (no search, ALL tag, favorites off): its picks
                // ignore the filters, and a shelf that contradicts an
                // active filter reads as broken. With no region set,
                // the one-time region prompt (or its one-line link)
                // stands in the shelf's place.
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && selectedTag == .all && !showFavoritesOnly {
                    if USRegion(rawValue: seasonalRegionRaw) == nil {
                        SeasonalRegionPrompt()
                            .padding(.bottom, 30)
                    } else {
                        let shelfPicks = seasonalShelfPicks
                        if !shelfPicks.isEmpty {
                            seasonalShelf(shelfPicks)
                                .padding(.bottom, 30)
                        }
                    }
                }

                // Hero — full-width halftone image, square corners, no
                // scrim; kicker, title, and metadata sit below it.
                if let hero = heroRecipe {
                    NavigationLink {
                        SupabaseRecipeDetailView(recipe: hero)
                    } label: {
                        heroBlock(hero)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { recipeContextMenu(hero) }
                    .padding(.bottom, 30)
                }

                // Recently added — a ruled vertical list, not a strip.
                if !recentlyAdded.isEmpty {
                    FluffySectionHead(title: "Recently added")
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    ruledRecipeList(recentlyAdded, leafIDs: leafIDs)
                        .padding(.bottom, 30)
                }

                // The rest of the box — same ruled list treatment.
                if !gridRecipes.isEmpty {
                    FluffySectionHead(title: "The recipe box")
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    ruledRecipeList(gridRecipes, leafIDs: leafIDs)
                        .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Search Rule

    /// Not a filled field: an italic placeholder with a magnifying
    /// glass on a single hairline bottom rule.
    private var searchRule: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.fluffySecondary)
                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text("Search name or ingredient")
                            .font(.fluffyCallout)
                            .foregroundStyle(Color.fluffyTertiary)
                    }
                    TextField("", text: $searchText)
                        .font(.custom(FluffyFace.regular, size: 15))
                        .foregroundStyle(Color.fluffyPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fluffySecondary)
                    }
                }
            }
            FluffyRule(weight: 1, color: .fluffyFieldRule)
        }
    }

    // MARK: - Chip Bar

    /// Category chips as plain uppercase words in a wrapping row —
    /// not capsules. The selected word takes ink 1 and a 2px
    /// underline; the rest sit in fluffySecondary with no rule.
    private var chipBar: some View {
        FluffyFlowLayout(hSpacing: 18, vSpacing: 12) {
            ForEach(BrowseTag.allCases) { tag in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTag = tag
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(tag.rawValue.uppercased())
                            .font(.custom(FluffyFace.regular, size: 14))
                            .fluffyTracking(0.06, at: 14)
                            .foregroundStyle(
                                selectedTag == tag ? Color.fluffyAccent : Color.fluffySecondary
                            )
                        FluffyRule(
                            weight: 2,
                            color: selectedTag == tag ? .fluffyAccent : .clear
                        )
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Seasonal Shelf

    /// The collapsible "In season now" section: a tappable section
    /// head (chevron shows the state) over the picker's own rows —
    /// FluffyRecipeRowLabel with the match line — as a ruled list.
    /// Rows navigate to the recipe like every other row on this tab.
    private func seasonalShelf(_ picks: [SeasonalMatch.Pick]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    seasonalShelfCollapsed.toggle()
                    SeasonalShelfSession.isCollapsed = seasonalShelfCollapsed
                }
            } label: {
                HStack {
                    FluffySectionHead(title: "In season now")
                    Spacer()
                    Image(systemName: seasonalShelfCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.fluffySecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(seasonalShelfCollapsed
                                ? "Show in season now" : "Hide in season now")
            .padding(.horizontal, 22)
            .padding(.bottom, 10)

            if !seasonalShelfCollapsed {
                ForEach(picks, id: \.recipe.id) { pick in
                    VStack(spacing: 0) {
                        FluffyRule().padding(.horizontal, 22)
                        NavigationLink {
                            SupabaseRecipeDetailView(recipe: pick.recipe)
                        } label: {
                            HStack(spacing: 14) {
                                FluffyRecipeRowLabel(
                                    recipe: pick.recipe,
                                    seasonalScore: pick.score,
                                    showsLeaf: true
                                )
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.fluffyAccent)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu { recipeContextMenu(pick.recipe) }
                    }
                }
                FluffyRule().padding(.horizontal, 22)
            }
        }
    }

    // MARK: - Hero

    private func heroBlock(_ recipe: RecipeRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeCardImage(recipe: recipe, height: 200)
                .clipped()
                .padding(.bottom, 15)

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.isFavorite ? "FAVOURITE" : "NEWEST")
                    .font(.fluffyMastheadLabel)
                    .fluffyTracking(0.16, at: 10)
                    .foregroundStyle(Color.fluffyInk2)

                Text(recipe.name)
                    .font(.custom(FluffyFace.bold, size: 27))
                    .fluffyTracking(-0.02, at: 27)
                    .foregroundStyle(Color.fluffyPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                FluffyMetadataLine(text: recipeSubtitle(recipe))
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Ruled Recipe List

    /// Vertical ruled list: 58\u{00D7}58 halftone thumbnail, title over
    /// uppercase metadata, a persimmon chevron at the trailing edge.
    private func ruledRecipeList(_ recipes: [RecipeRow], leafIDs: Set<UUID> = []) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(recipes) { recipe in
                VStack(spacing: 0) {
                    FluffyRule().padding(.horizontal, 22)
                    NavigationLink {
                        SupabaseRecipeDetailView(recipe: recipe)
                    } label: {
                        listRow(recipe, showsLeaf: leafIDs.contains(recipe.id))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { recipeContextMenu(recipe) }
                }
            }
            FluffyRule().padding(.horizontal, 22)
        }
    }

    private func listRow(_ recipe: RecipeRow, showsLeaf: Bool = false) -> some View {
        HStack(spacing: 14) {
            RecipeCardImage(recipe: recipe, height: 58)
                .frame(width: 58, height: 58)
                .clipped()

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(recipe.name)
                        .font(.custom(FluffyFace.semibold, size: 18))
                        .fluffyTracking(-0.01, at: 18)
                        .foregroundStyle(Color.fluffyPrimary)
                        .lineLimit(1)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.fluffyInk2)
                    }
                    // Seasonal Suggestions v1: in season in the
                    // household's region this month. Never shown when
                    // the region is unset.
                    if showsLeaf {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.fluffyInk2)
                    }
                }
                FluffyMetadataLine(text: recipeSubtitle(recipe))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.fluffyAccent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Card Helpers

    private func recipeSubtitle(_ recipe: RecipeRow) -> String {
        let total = recipe.prepTimeMinutes + recipe.cookTimeMinutes
        if total > 0 {
            return "\(recipe.category) \u{00B7} \(total) min"
        }
        return recipe.category
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func recipeContextMenu(_ recipe: RecipeRow) -> some View {
        Button {
            recipeToPlan = recipe
        } label: {
            Label("Add to Meal Plan", systemImage: "calendar.badge.plus")
        }
        Button {
            Task {
                if !(await recipeService.toggleFavorite(recipe)) {
                    actionErrorMessage = "Couldn't update favorites. Please try again."
                }
            }
        } label: {
            Label(
                recipe.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: recipe.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button(role: .destructive) {
            Task { await confirmDeleteRecipe(recipe) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty / No-Matches

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead

                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.fluffyAccent)
                        .padding(.bottom, 30)

                    Text("The box is empty.")
                        .font(.fluffyDisplaySmall)
                        .fluffyTracking(-0.025, at: 30)
                        .foregroundStyle(Color.fluffyPrimary)
                        .padding(.bottom, 10)

                    Text("Add your first recipe and it will take the front page.")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 30)

                    FluffyTextLink(title: "Add a recipe") {
                        showingAddRecipe = true
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noMatchesState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 20)

                searchRule
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                chipBar
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)

                Text("Nothing matches.")
                    .font(.fluffyDisplaySmall)
                    .fluffyTracking(-0.025, at: 30)
                    .foregroundStyle(Color.fluffyPrimary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)

                Text("Try a different search or filter.")
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffySecondary)
                    .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Toast

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
            .background(.ultraThinMaterial)
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - Reload

    /// Fetch recipes and record whether it succeeded, so a failed load
    /// shows the retry banner instead of "No recipes yet."
    private func reloadRecipes() async {
        let ok = await recipeService.fetchRecipes()
        fetchFailed = !ok
    }

    // MARK: - Add to Meal Plan

    private func addToMealPlan(recipe: RecipeRow, date: Date, memberID: UUID? = nil) async {
        Logger.supabase.info("Recipe list: addToMealPlan recipe=\(recipe.id.uuidString) date=\(MealPlanService.isoDate(from: date)) member=\(memberID?.uuidString ?? "household")")

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

        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let day = f.string(from: date)
        let memberName = memberID.flatMap { id in
            householdService.members.first { $0.id == id }?.displayName
        }
        withAnimation {
            toastMessage = memberName.map { "Added for \($0) \u{2014} \(day)" }
                ?? "Added to \(day)"
        }
    }

    /// Check if the recipe is scheduled before allowing deletion.
    /// If scheduled, show a blocked alert. If not, show a confirmation.
    private func confirmDeleteRecipe(_ recipe: RecipeRow) async {
        recipeToDelete = recipe
        let isScheduled = await mealPlanService.isRecipeScheduled(recipe.id)
        if isScheduled {
            showDeleteBlockedAlert = true
        } else {
            showDeleteConfirmAlert = true
        }
    }
}

// MARK: - Seasonal Shelf Session

/// Session-scoped memory for the shelf's collapsed state. A plain
/// static (not @AppStorage) on purpose: the choice should survive the
/// view being recreated — tab switches, navigation pushes — but reset
/// on the next launch, when a new session (maybe a new month) gets
/// the expanded shelf again. MainActor-safe under the project's
/// default isolation.
enum SeasonalShelfSession {
    static var isCollapsed = false
}

// MARK: - Browse Tags

/// Cuisine / ingredient-based filter tags for the recipe browse view.
/// Matches recipes by scanning their name and ingredient list for keywords.
private enum BrowseTag: String, CaseIterable, Identifiable {
    case all        = "All"
    case chicken    = "Chicken"
    case pasta      = "Pasta"
    case fish       = "Fish"
    case vegetarian = "Vegetarian"
    case pork       = "Pork"
    case soups      = "Soups"

    var id: String { rawValue }

    /// Whether a recipe matches this tag based on its name and ingredients.
    func matches(_ recipe: RecipeRow, ingredientNames: [String]?) -> Bool {
        let nameLower = recipe.name.lowercased()
        let ingredients = ingredientNames ?? []

        func containsAny(_ keywords: [String]) -> Bool {
            keywords.contains { kw in
                nameLower.contains(kw) || ingredients.contains { $0.contains(kw) }
            }
        }

        switch self {
        case .all:
            return true
        case .chicken:
            return containsAny(["chicken", "poultry"])
        case .pasta:
            return containsAny([
                "pasta", "spaghetti", "penne", "linguine", "fettuccine",
                "macaroni", "noodle", "lasagna", "rigatoni", "orzo",
                "tortellini", "ravioli", "gnocchi"
            ])
        case .fish:
            return containsAny([
                "fish", "salmon", "tuna", "cod", "tilapia", "shrimp",
                "seafood", "prawn", "crab", "lobster", "scallop",
                "halibut", "mahi", "swordfish", "anchov"
            ])
        case .vegetarian:
            // Negative match: no common meat/fish keywords
            let meatKeywords = [
                "chicken", "beef", "pork", "turkey", "lamb", "bacon",
                "sausage", "ham", "steak", "prosciutto", "fish",
                "salmon", "tuna", "shrimp", "prawn", "crab",
                "lobster", "scallop", "anchov"
            ]
            return !containsAny(meatKeywords)
        case .pork:
            return containsAny([
                "pork", "bacon", "ham", "prosciutto", "pancetta"
            ])
        case .soups:
            return containsAny([
                "soup", "stew", "chowder", "bisque", "broth", "chili"
            ])
        }
    }
}

// MARK: - Day Picker Sheet

/// Lightweight sheet that lets the user pick one of the 7 days of the
/// current week to assign a recipe to — and, with per-person meals,
/// who it's for (assignment chips; EVERYONE by default).
struct DayPickerSheet: View {
    let recipe: RecipeRow
    /// Household members for the assignment chips. Empty hides the row.
    var members: [HouseholdMemberRow] = []
    /// Lowercased ingredient names for the dietary hint under the chips.
    var ingredientNames: [String]? = nil
    let onPick: (Date, UUID?) -> Void
    let onCancel: () -> Void

    /// nil = EVERYONE (the household slot) — the default.
    @State private var selectedMemberID: UUID?

    /// Seasonal Suggestions v1: leaf on the recipe being planned when
    /// it's in season in the household's region. "" = dormant.
    @AppStorage("seasonalRegion") private var seasonalRegionRaw = ""

    private var recipeIsSeasonal: Bool {
        !SeasonalMatch.seasonalRecipeIDs(
            recipes: [recipe],
            ingredientsByRecipeID: ingredientNames.map { [recipe.id: $0] } ?? [:],
            region: USRegion(rawValue: seasonalRegionRaw),
            month: Calendar.current.component(.month, from: Date())
        ).isEmpty
    }

    private let weekStart: Date = DateHelper.startOfWeek(containing: Date())

    private var weekDates: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var selectedMember: HouseholdMemberRow? {
        selectedMemberID.flatMap { id in members.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 6) {
                        Text(recipe.name)
                            .font(.fluffyHeadline)
                            .foregroundStyle(Color.fluffyPrimary)
                        if recipeIsSeasonal {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.fluffyInk2)
                        }
                    }
                } header: {
                    Text("Plan this recipe")
                }

                if !members.isEmpty {
                    Section("Who is it for?") {
                        VStack(alignment: .leading, spacing: 8) {
                            FluffyAssignmentChips(
                                members: members,
                                selection: $selectedMemberID
                            )
                            // Keyword-only dietary hint — a gentle
                            // flag, never a block. A selected person
                            // gets their own check; EVERYONE checks
                            // the whole household and names the first
                            // affected member ("... FOR MAYA +1").
                            if let member = selectedMember {
                                if let conflict = DietaryMatch.conflict(
                                    for: member,
                                    recipe: recipe,
                                    ingredientNames: ingredientNames
                                ) {
                                    FluffyMetadataLine(
                                        text: DietaryMatch.hintText(for: conflict),
                                        color: .fluffyAccent
                                    )
                                }
                            } else if let household = DietaryMatch.householdConflict(
                                members: members,
                                recipe: recipe,
                                ingredientNames: ingredientNames
                            ) {
                                FluffyMetadataLine(
                                    text: DietaryMatch.hintText(for: household),
                                    color: .fluffyAccent
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Choose a Day") {
                    ForEach(weekDates, id: \.self) { date in
                        let isPast = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
                        Button {
                            onPick(date, selectedMemberID)
                        } label: {
                            HStack {
                                Text(dayName(for: date))
                                    .font(.fluffyCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isPast ? Color.fluffyTertiary : Color.fluffySecondary)
                                    .frame(width: 40, alignment: .leading)
                                Text(fullDate(for: date))
                                    .font(.fluffyBody)
                                    .foregroundStyle(isPast ? Color.fluffyTertiary : Color.fluffyPrimary)
                                Spacer()
                                if !isPast {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.fluffyTertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .tint(Color.fluffyPrimary)
                        .disabled(isPast)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }

    private func dayName(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func fullDate(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - Flow Layout

/// Minimal left-aligned wrapping layout for the underlined-word
/// category chips. iOS 16+ Layout protocol; the project targets 17+.
struct FluffyFlowLayout: Layout {
    var hSpacing: CGFloat = 18
    var vSpacing: CGFloat = 12

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth,
                      height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: .unspecified
            )
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
