# HANDOFF.md — FluffyList

## One-Paragraph Resume
FluffyList Beta (Build 92) has a complete Heirloom design system and all views rewritten from Figma. The app has four tabs (Meals/Recipes/Grocery/Settings) with per-tab section-colored tints (teal/amber/slate blue/muted). Recipe detail has a scaled servings stepper that adjusts ingredient quantities proportionally and a free-text notes field. The recipe browse view has a hero card, browse filter chips, a "Recently Added" horizontal scroll, and a two-column grid. The meal plan has an empty-week state with suggested recipes, and the grocery list has auto-categorization, Store Mode (dark high-contrast), and share. A custom AVCaptureSession recipe scanner replaces the old UIImagePickerController flow. First-launch onboarding (splash + household setup step 1) is gated by `@AppStorage("hasSeenOnboarding")`. Backend is Supabase with full service layer. The PROXY_KEY is in `Secrets.xcconfig` (gitignored). Next: create the Supabase project, add the `notes` column, and test end-to-end.

---

## Current Status
- **Build:** 92 (TestFlight, live — still CloudKit; Supabase path not yet deployed)
- **Branch:** main
- **Latest commit:** `1d0a87c` — scaled servings + notes field
- **Bundle ID:** com.highball71.fluffylist.beta
- **Display Name:** FluffyList Beta
- **Feature Flag:** `useSupabase = true` in Family_Meal_PlannerApp.swift
- **Proxy:** https://fluffylist-proxy.onrender.com (for Claude Vision API)
- **Design System:** Heirloom palette — all views use design tokens
- **Secrets:** `Secrets.xcconfig` (gitignored) — PROXY_KEY, SUPABASE_URL, SUPABASE_ANON_KEY

## Architecture
- **Source of truth:** Supabase (Postgres + RLS)
- **Auth:** Sign in with Apple via Supabase Auth
- **Sharing:** Join-code flow (6-char code per household)
- **Design System:** Color+FluffyList (palette), Font+FluffyList (typography), FluffyColor (section enum), FluffyFont (shared components)
- **Old CloudKit path:** Preserved behind `useSupabase = false`, not deleted

## What's Done

### Design System (Heirloom Palette)
- Color+FluffyList.swift — surfaces, text, borders, 3 section accents + light variants, semantic colors
- Font+FluffyList.swift — Playfair Display Bold (display) + Inter Regular/Semi Bold (body/headings)
- Fonts/ — 3 .ttf files bundled + registered in Info.plist
- FluffyColor.swift — `FluffySection` enum (accent colors per section)
- FluffyFont.swift — `FluffySectionHeader`, `FluffyBulletRow`, `FluffyPrimaryButton`, `FluffyMetadataChip`
- AppColors.swift — slimmed to `RecipeCategory.stripeColor` only

### Views
- **SupabaseRecipeListView** — hero card, browse filter chips (All/Chicken/Pasta/Fish/Vegetarian/Pork/Soups), "Recently Added" horizontal scroll (4 newest), two-column LazyVGrid, context menus
- **SupabaseRecipeDetailView** — Playfair bold title, metadata chips, **scaled servings stepper** (adjusts ingredient quantities proportionally), bullet-dot ingredients, bold ingredient highlighting in prep steps, **notes section**, "Add to This Week" button
- **SupabaseMealPlanView** — teal day cards, today left bar, **empty-week state** ("Your week is wide open" with frying pan icon, Browse Recipes / Add a Custom Meal buttons, suggested recipes list), Generate Shopping List switches to Grocery tab
- **SupabaseGroceryListView** — ruled lines, auto-categorized items (Produce/Protein/Dairy/Pantry/Other), **Store Mode** (dark high-contrast toggle with larger text/checkboxes), Share List via ShareLink
- **RecipeScanView** — custom AVCaptureSession camera with corner bracket guides, animated amber scan line, shutter button, thumbnail strip, page counter (fixed "0 pages" bug with PassthroughSubject)
- **SupabaseSettingsView** — initials avatar, grouped sections (Household/Recipes/Shopping/App), toggle/stepper/picker rows, Store Mode toggle wired to grocery view
- **AppRootView** — onboarding gate (hasSeenOnboarding), four-tab layout with per-tab section tints, selectedTab binding for cross-tab navigation
- **WelcomeSplashView** + **HouseholdSetupView** — first-launch onboarding (household size + dietary prefs)
- **HouseholdOnboardingView** — restyled with FluffyPrimaryButton + Heirloom tokens
- **SignInView** — restyled with Playfair Display + Fluffy tokens

### Data Model Additions
- `notes: String` on RecipeRow (fallback decoder) + RecipeInsert + RecipeService + ViewModel
- `@AppStorage` keys: hasSeenOnboarding, householdSize, dietaryPreferences, groceryStoreMode, defaultServings, autoAddGroceries, groupGroceriesByAisle, mealPlanStartDay

### Bug Fixes
- Scanner "0 pages" — replaced `@Published` + `onChange` with `PassthroughSubject` + `onReceive`; added `isRunning` guard + error logging
- Generate Shopping List race condition — fetch awaited before tab switch
- ShapeStyle compile errors — all bare `.fluffy*` prefixed with `Color.`

### Polish Pass
- All system fonts replaced with Fluffy tokens across all views
- All bare `.red/.green/.secondary` replaced with `.fluffyError/.fluffySuccess/.fluffySecondary`
- Empty states unified with illustrated circle treatment
- `.animation(.easeInOut)` transitions on conditional view swaps
- Consistent toast overlays (icon, font, color, timing)

### Supabase Backend
- SQL schema: `supabase/migrations/001_initial_schema.sql` (9 tables + RLS) — **needs `notes` column added to `recipes` table**
- SPM dependency: `supabase-swift` v2.43.1
- Config: `Secrets.xcconfig` (gitignored) with real keys
- Service layer: SupabaseManager, AuthService, HouseholdService, RecipeService, MealPlanService, GroceryService
- Models: SupabaseModels.swift (Codable Row/Insert structs)

## What's Not Done Yet
- Supabase project not created (no real URL/key)
- SQL migration for `notes` column on `recipes` table
- Sign in with Apple not configured in Supabase dashboard
- No recipe photos (cards use category gradient + SF Symbol placeholders)
- No offline/local cache
- No realtime subscriptions
- Old CloudKit code not yet removed

## Critical Files
- `Design/` — Color+FluffyList, Font+FluffyList, FluffyColor, FluffyFont, Fonts/
- `FluffyListBeta/Views/` — AppRootView, SupabaseRecipeListView, SupabaseRecipeDetailView, SupabaseMealPlanView, SupabaseGroceryListView, SupabaseSettingsView, RecipeScanView, WelcomeSplashView, HouseholdSetupView
- `FluffyListBeta/Models/SupabaseModels.swift` — includes `notes` field
- `FluffyListBeta/ViewModels/SupabaseRecipeFormViewModel.swift` — includes `notes`
- `FluffyListBeta/Services/RecipeService.swift` — `notes` in add/update
- `Family_Meal_PlannerApp.swift` — feature flag
- `Family-Meal-Planner-Info.plist` — font registration + proxy key
- `Secrets.xcconfig` — PROXY_KEY, SUPABASE_URL, SUPABASE_ANON_KEY (gitignored)

## Next Steps (In Order)
1. Create Supabase project at supabase.com
2. Run `001_initial_schema.sql` + add `notes TEXT DEFAULT ''` to `recipes` table
3. Enable Sign in with Apple in Supabase Auth settings
4. Add real URL + anon key to `Secrets.xcconfig`
5. Test sign-in → create household → add recipe → meal plan → grocery end-to-end
6. Add recipe photo support (camera/library → Supabase storage → card thumbnails)
7. Remove old CloudKit code after Supabase is validated
