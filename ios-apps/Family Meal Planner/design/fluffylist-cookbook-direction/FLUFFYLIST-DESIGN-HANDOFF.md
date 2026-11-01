# FluffyList cookbook direction — design handoff

Status: visual direction for review; **not approved for implementation yet**.

This pass brings the three main screens closer to one family cookbook while keeping each screen useful for its job. The Concepts are HTML visual studies. They are not a replacement for SwiftUI, and their sample food treatments, names, quantities, counts, quotes, dates, and meal data are illustrative only.

## Review concepts

- [Recipes screen](fluffylist-cookbook-concept.html)
- [Meals screen](fluffylist-week-concept.html)
- [Grocery / Store Mode screen](fluffylist-grocery-concept.html)
- [Switchable review page](fluffylist-review.html)

## What should feel consistent

- A recognizable cookbook voice: warm paper, expressive serif display type, simple sans-serif utility text, and fine editorial rules.
- Color with a point of view. Keep the paper light and clean; use leafy green for primary actions and navigation, tomato for small moments of emphasis, and a clear blue as a restrained counterpoint. Avoid letting the whole interface drift into brown or beige. Seasonal accents remain part of the existing design system and should be evaluated separately from these base colors.
- Large, readable titles and controls. Keep secondary text legible; do not make functional information depend on low-contrast gray or tiny tracked capitals.
- Photos are welcome when they are actually saved recipe media. Family photos, cookbook photos, and other recipe images must retain the current media-role behavior. Never substitute decorative generated imagery for a user’s real recipe photo in the shipped app.
- Let each screen have one clear job. The family-cookbook identity should frame the task, not compete with it.

## Screen intent

### Recipes — the family’s recipe box

The current browse screen contains a hero, category shelf, recently added shelf, recipe list, and optional seasonal content. The study explores a quieter editorial hierarchy: the family’s saved recipe media and recipe names lead; search, filters, and adding a recipe remain easy to find; browsing sections should not read like a promotional storefront.

Preserve search by recipe and ingredient, favorites, filters, categories, seasonal suggestions, context actions, recipe detail navigation, and the current family/cookbook photo distinctions. Do not remove capabilities merely to match the mockup.

Implementation target: `SupabaseRecipeListView.swift` and `RecipeCardImage.swift`.

### Meals — plan the week at a glance

The planner should quickly answer: what is planned, for whom, and which nights remain open? Keep clear date navigation and tappable open slots. A day may contain multiple meals, including separate household and member meals; this behavior is central and must remain visible. Sample dates and meals in the concept are not canonical data.

Preserve week bounds and past-week read-only behavior, week summaries, meal assignment, add/replace/remove actions, copy-last-week, seasonal footer, and grocery-list navigation. Avoid adding fabricated meal photos or family quotations.

Implementation target: `SupabaseMealPlanView.swift` plus existing `DayPlan` and `WeekSummary` models.

### Grocery — a focused shopping tool

The dark Store Mode is intentional and useful in a bright store. Keep it high-contrast and fast to scan. The concept keeps the item name and checkbox primary, gives long prep notes room to wrap, keeps quantities distinct, and makes sure the bottom navigation does not obscure list items. The lighter paper mode should remain available as the calmer counterpart.

Preserve automatic category grouping, unchecked-first ordering, alternative wording, quantity formatting, checked-item state, clear-checked, refresh/error states, share, and the Store Mode toggle. Do not invent aisle ordering or recipe-to-item relationships that the data model does not provide.

Implementation target: `SupabaseGroceryListView.swift`, `GroceryItemRow`/shared row components as appropriate, and the existing root tab bar in `AppRootView.swift`.

## Before implementation

1. Review the three concepts together and decide whether this is the direction to implement.
2. If approved, work from the repository’s current `main` / build 130 baseline and use a separate design branch or worktree. Do not edit the live `main` branch directly.
3. Start with shared color/typography/surface tokens and the bottom-navigation safe-area behavior; then implement one screen at a time.
4. Keep the diff focused on presentation. Do not change Supabase schema, data services, recipe-media selection, or meal/grocery semantics for a visual pass.
5. Compare iPhone and iPad layouts, larger text, light/dark appearance, and Store Mode contrast using real app data or neutral fixtures. Mock values must not leak into production.

## Pairing workflow

- **Codex:** design critique, inspect current SwiftUI structure, identify regressions and behavioral constraints, review the implementation diff.
- **Claude:** implement the agreed screen/token changes in the working checkout and report changed files plus device/simulator results.
- Keep the working branch and a short handoff note in GitHub so both agents are reviewing the same revision. No merge or TestFlight upload is implied by this visual handoff.
