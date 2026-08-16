# ACTIVE_TASK.md — FluffyList

**Session Focus:** "The Press" visual overhaul — implemented on branch `press-overhaul`, awaiting compile + device verification.

---

## Completed This Session (August 16, 2026)

Implemented per `design_handoff_press_overhaul/README.md` (the zip bundle; HTML prototype "1a — The Press"). Presentation layer only; all services, view models, @AppStorage keys, and navigation unchanged.

1. **Tokens**: `Color+FluffyList.swift` → paper/ink/persimmon palette (ink 2 spruce, ink 3 reserved); retired amber/teal/slate accents kept as compile aliases → persimmon. `Font+FluffyList.swift` → Source Serif 4 everywhere + em-tracking helpers.
2. **Fonts**: Source Serif 4 Regular/Semibold/Bold/It TTFs bundled (Adobe 4.005 release, OFL) + registered in Info.plist. **Actual PostScript names differ from the design README**: `SourceSerif4-Semibold` (lowercase b), `SourceSerif4-It` (not -Italic). Old Playfair/Inter files retained (RULES: no deletions) — remove font files + registration in a later cleanup once confirmed dead.
3. **Components** (`FluffyFont.swift`): FluffyMasthead, FluffyRule, FluffySectionHead, FluffyMetadataLine, FluffyTextLink, FluffyFilledButton, FluffyCheckbox, halftone modifier; legacy shims for old component names.
4. **Screens**: Grocery + Store Mode (ink ground, pale-persimmon heads), Meals (ruled day rows, state line, CTA text link), Settings (label/value rules), Recipe detail (kicker, ruled ingredients, METHOD numerals, sticky "Add to the week"), Recipes (search rule, underlined word chips, halftone hero, ruled lists — grid removed), Add/edit recipe (header rule, toolbar Save, ink-outlined scan box, label-over-rule fields), Welcome/SignIn ("Dinner, decided.", numbered value rows), HouseholdSetup + HouseholdOnboarding (ink-rule fields, six-cell code, OR JOIN ONE divider).
5. **Chrome**: Tab bar via UITabBarAppearance (paper, 1px ink top rule, serif 10pt uppercase, active persimmon / inactive #7D7979). FluffyErrorBanner → PROBLEM band. Toasts/overlays squared.

## Deliberate deviations from the design README (flag if wrong)
- **Save also kept as a filled button at the end of the Add Recipe form** (in addition to the header Save) — long form, avoids scroll-back. Delete `saveButton` from formContent if unwanted.
- **Icons are SF Symbols throughout** (spec permits substitution); Phosphor SVGs not bundled.
- **Store Mode toggle + Clear checked stay in the (inline, paper-tinted) nav bar** — spec doesn't place them.
- **Grocery empty-state "Plan a night →"** required passing `selectedTab` binding into `SupabaseGroceryListView` (same pattern as Meals).
- **Detail-screen kicker** uses FAVOURITE/category (no cook-count data exists).

## Verification checklist (on a Mac, before merge)
1. `git fetch && git checkout press-overhaul` (or apply the patch bundle), build for device.
2. Confirm the four Source Serif faces render (wrong PS name = silent system-font fallback).
3. Dynamic Type pass at largest supported size — grocery rows, ingredient rows (Source Serif sets wider than Inter).
4. Store Mode cross-fade, checkbox animation, code-entry cells with hardware + software keyboard.
5. Tab bar appearance on scroll edge (iOS 26 behavior).
