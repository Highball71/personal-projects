# HANDOFF.md — FluffyList

## One-Paragraph Resume
FluffyList Beta (Build 92) has completed a full Figma-to-code design pass using the Heirloom palette (near-white #FAFAF7 background, near-black #1C1C1A text, three section accent colors: Amber #F59B00 for Recipes, Teal #0F6E6E for Meal Plan, Slate Blue #2E5DA8 for Grocery). Custom fonts (Playfair Display Bold for display titles, Inter Regular/Semi Bold for body) are bundled and registered. All four main views — Recipe Browse, Meal Plan, Grocery List, and Settings — have been rewritten to match the Figma design, plus a new Recipe Detail view. The app has a four-tab layout with per-tab section-colored tints. Backend is Supabase with full service layer (Auth, Household, Recipe, MealPlan, Grocery). Next: Supabase project setup + end-to-end testing.

---

## Current Status
- **Build:** 92 (TestFlight, live — still CloudKit; Supabase path not yet deployed)
- **Branch:** main
- **Bundle ID:** com.highball71.fluffylist.beta
- **Display Name:** FluffyList Beta
- **Feature Flag:** `useSupabase = true` in Family_Meal_PlannerApp.swift
- **Proxy:** https://fluffylist-proxy.onrender.com (for Claude Vision API, unchanged)
- **Design System:** Heirloom palette implemented — all views use design tokens

## Architecture
- **Source of truth:** Supabase (Postgres + RLS)
- **Auth:** Sign in with Apple via Supabase Auth
- **Sharing:** Join-code flow (6-char code per household)
- **Design System:** Color+FluffyList.swift (palette), Font+FluffyList.swift (typography), FluffyColor.swift (section enum), FluffyFont.swift (shared components)
- **Old CloudKit path:** Preserved behind `useSupabase = false`, not deleted

## What's Done

### Design System (Heirloom Palette)
- **Color+FluffyList.swift** — core palette: surfaces (#FAFAF7, #FFFFFF, #F4F4F0), text (#1C1C1A, #6B6B68, #9E9E9A), borders (#E2E2DD, #EDEDEA), section accents (amber, teal, slate blue + light variants), semantic (error red, success green)
- **Font+FluffyList.swift** — typography scale: Playfair Display Bold (34/28/22pt display), Inter Semi Bold (20/17/15pt headings), Inter Regular (16/15/13/12pt body), button + tab label
- **Fonts/** — PlayfairDisplay-Bold.ttf, Inter-Regular.ttf, Inter-SemiBold.ttf bundled + registered in Info.plist
- **FluffyColor.swift** — `FluffySection` enum mapping recipes/mealPlan/grocery to accent color pairs + icons
- **FluffyFont.swift** — shared components: `FluffySectionHeader`, `FluffyBulletRow`, `FluffyPrimaryButton`, `FluffyMetadataChip`
- **AppColors.swift** — slimmed to just `RecipeCategory.stripeColor` extension

### Views (Figma Design Pass)
- **SupabaseRecipeListView** — recipe browse with amber accent, horizontal category filter chips (All/Chicken/Pasta/Fish/Vegetarian/Pork/Soups), featured hero card with category gradient + SF Symbol placeholder, two-column LazyVGrid of recipe cards, context menus for plan/favorite/delete
- **SupabaseRecipeDetailView** (NEW) — read-only detail: Playfair Display bold title, metadata chips, amber "INGREDIENTS" section header with bullet-dot rows, bold ingredient names highlighted in preparation steps via AttributedString, "Add to This Week" amber button
- **SupabaseMealPlanView** — teal accent, white day cards in ScrollView, teal left bar for today, "+ Add a meal" in teal for empty days, context menu to clear, "Generate Shopping List" slate blue button that switches to Grocery tab
- **SupabaseGroceryListView** — slate blue accent, cream background with ruled lines, auto-categorized by ingredient keywords (Produce/Protein/Dairy & Eggs/Pantry/Other), checkboxes with strikethrough, right-aligned quantities, Share List button via ShareLink
- **SupabaseSettingsView** (NEW) — household info, join code with copy, members list, sign out, app version
- **AppRootView** — four-tab layout (Meals/Recipes/Grocery/Settings) with per-tab section-colored tints via dynamic `.tint()`, `$selectedTab` binding for cross-tab navigation

### Supabase Backend (unchanged from prior session)
- SQL schema: `supabase/migrations/001_initial_schema.sql` (9 tables + RLS)
- SPM dependency: `supabase-swift` v2.43.1
- Config: `Secrets.xcconfig` with `SUPABASE_URL` / `SUPABASE_ANON_KEY` placeholders
- Service layer: `SupabaseManager`, `AuthService`, `HouseholdService`, `RecipeService`, `MealPlanService`, `GroceryService`
- Models: `SupabaseModels.swift` (Codable Row/Insert structs for all 9 tables)
- Views: `SignInView`, `HouseholdOnboardingView`, `SupabaseAddRecipeView`, `HouseholdInfoView`

## What's Not Done Yet
- Supabase project not created (no real URL/key)
- Sign in with Apple not configured in Supabase dashboard
- No recipe photos (cards use category gradient + SF Symbol placeholders)
- No offline/local cache
- No realtime subscriptions
- Old CloudKit code not yet removed
- DayPickerSheet and RecipePickerSheet could be styled with Heirloom tokens

## Critical Files
- `Design/Color+FluffyList.swift` — color tokens
- `Design/Font+FluffyList.swift` — typography tokens
- `Design/FluffyColor.swift` — section enum
- `Design/FluffyFont.swift` — shared view components
- `Design/Fonts/` — bundled .ttf files
- `FluffyListBeta/Views/AppRootView.swift` — tab bar + AppTab enum
- `FluffyListBeta/Views/SupabaseRecipeListView.swift` — recipe browse + BrowseTag + DayPickerSheet
- `FluffyListBeta/Views/SupabaseRecipeDetailView.swift` — recipe detail
- `FluffyListBeta/Views/SupabaseMealPlanView.swift` — meal plan + RecipePickerSheet + Date:Identifiable
- `FluffyListBeta/Views/SupabaseGroceryListView.swift` — grocery list + GroceryCategory
- `FluffyListBeta/Views/SupabaseSettingsView.swift` — settings tab
- `Family_Meal_PlannerApp.swift` — feature flag + both paths
- `Family-Meal-Planner-Info.plist` — font registration (UIAppFonts)

## Next Steps (In Order)
1. Create Supabase project at supabase.com
2. Run `001_initial_schema.sql` in SQL editor
3. Enable Sign in with Apple in Supabase Auth settings
4. Add real URL + anon key to `Secrets.xcconfig`
5. Test sign-in → create household → add recipe → meal plan → grocery end-to-end
6. Add recipe photo support (camera/library → storage → card thumbnails)
7. Remove old CloudKit code after Supabase is validated
