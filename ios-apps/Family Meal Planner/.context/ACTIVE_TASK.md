# ACTIVE_TASK.md — FluffyList

**Session Focus:** Feature additions + bug fixes — complete. Ready for Supabase integration testing.

---

## Completed This Session (April 15, 2026)

### Design System Foundation
1. Color+FluffyList.swift — Heirloom color palette
2. Font+FluffyList.swift — typography scale (Playfair Display Bold + Inter)
3. Bundled 3 Google Fonts + registered in Info.plist
4. FluffyColor.swift — FluffySection enum
5. FluffyFont.swift — shared components (section header, bullet row, primary button, metadata chip)

### View Rewrites (Figma Design Pass)
6. SupabaseRecipeListView — hero card, browse chips, Recently Added, two-column grid
7. SupabaseRecipeDetailView (NEW) — scaled servings stepper, ingredient highlighting, notes section
8. SupabaseMealPlanView — teal day cards, empty-week state with suggested recipes
9. SupabaseGroceryListView — ruled lines, auto-categorized items, Store Mode, Share List
10. RecipeScanView (NEW) — custom AVCaptureSession camera with bracket guides + scan line
11. SupabaseSettingsView (NEW) — initials avatar, grouped settings sections
12. WelcomeSplashView + HouseholdSetupView (NEW) — first-launch onboarding
13. AppRootView — four-tab layout with onboarding gate + per-tab tints

### Features
14. Scaled servings stepper on recipe detail (proportional ingredient adjustment)
15. Notes field on recipes (model, service, form, detail view)
16. Recently Added horizontal scroll section on recipe browse
17. Store Mode toggle on grocery list (dark high-contrast)
18. Empty-week state on meal plan with Browse Recipes + Add a Custom Meal buttons

### Bug Fixes
19. Scanner "0 pages" — PassthroughSubject replaces fragile onChange pattern
20. Generate Shopping List race condition — await fetch before tab switch
21. ShapeStyle compile errors — Color. prefix on all .fluffy* references

### Polish
22. Full font/color audit — all system fonts → Fluffy tokens, all bare colors → Fluffy colors
23. Unified empty states with illustrated circle treatment
24. Added .animation(.easeInOut) transitions on conditional view swaps
25. Restyled HouseholdOnboardingView + SignInView with Heirloom tokens

## Next Objective
**Create Supabase project and test end-to-end.**

### Steps
1. Go to supabase.com, create new project
2. Run `supabase/migrations/001_initial_schema.sql` in SQL editor
3. Add `notes TEXT DEFAULT ''` column to `recipes` table
4. Configure Sign in with Apple in Supabase Auth settings
5. Copy project URL and anon key into `Secrets.xcconfig`
6. Build and run on device
7. Test: sign in → create household → add recipe → assign to meal plan → verify groceries
8. Test: second user joins by code, sees shared data
9. Test: recipe notes save and display correctly

## Not In Scope (Future Sessions)
- Recipe photo support (cards use gradient placeholders)
- Offline caching
- Realtime subscriptions
- Removing old CloudKit code
- App Store submission
