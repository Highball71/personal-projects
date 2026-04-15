# ACTIVE_TASK.md — FluffyList

**Session Focus:** Figma Heirloom design pass — complete. All views rewritten.

---

## Completed This Session
1. Color+FluffyList.swift — Heirloom color palette (surfaces, text, borders, 3 section accents)
2. Font+FluffyList.swift — typography scale (Playfair Display Bold + Inter)
3. Bundled 3 Google Fonts (.ttf) + registered in Info.plist
4. FluffyColor.swift — FluffySection enum (accent colors per section)
5. FluffyFont.swift — shared components (section header, bullet row, primary button, metadata chip)
6. SupabaseRecipeDetailView (NEW) — Figma recipe detail with ingredient highlighting
7. SupabaseRecipeListView — rewritten as browse view with hero card + grid + filter chips
8. SupabaseMealPlanView — rewritten with teal cards, today highlight, Generate Shopping List
9. SupabaseGroceryListView — rewritten with ruled lines, auto-categorized items, share button
10. SupabaseSettingsView (NEW) — household info, members, sign out, version
11. AppRootView — four-tab layout with per-tab section colors + selectedTab binding
12. Updated HANDOFF.md and SESSION_LOG.md

## Next Objective
**Create Supabase project and test end-to-end.**

### Steps
1. Go to supabase.com, create new project
2. Run `supabase/migrations/001_initial_schema.sql` in SQL editor
3. Configure Sign in with Apple in Supabase Auth settings
4. Copy project URL and anon key into `Secrets.xcconfig`
5. Build and run on device
6. Test: sign in → create household → add recipe → assign to meal plan → verify groceries
7. Test: second user joins by code, sees shared data

## Not In Scope
- Recipe photo support (cards use gradient placeholders)
- Offline caching
- Realtime subscriptions
- Removing old CloudKit code
- App Store submission
