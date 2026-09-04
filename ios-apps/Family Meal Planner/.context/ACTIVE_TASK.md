# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-04 later — Claude Code, autonomous) **Empty-week retirement + one-time region prompt**, on branch `empty-week-and-region` (NOT merged to main — merge after its device pass).

1. **"Wide open" state deleted.** An empty week renders like any week: seven day rows, open slots tappable. The seasonal strip + "Copy last week" moved into a planning footer below the day rows — visible iff any slot (household OR member) is open on a today-or-later day and the week isn't past (new pure `Models/WeekFooter.swift` — the old `hasOpenFutureDay` breadth, restored on David's instruction after a first cut counted only open household nights; past weeks keep PASSED rows, no footer). Also deleted: "Popular in your kitchen", standalone Browse/Add links, `showingAddRecipe`.
2. **Region prompt.** New `Views/SeasonalRegionPrompt.swift` stands wherever a seasonal surface would render with no region set (tab shelf, picker section via `inList: true`, week footer): Press ruled card — region Menu (same `seasonalRegion` key as Settings) + "Use my location" + "Not now" (persists via `seasonalRegionPromptDismissed`, leaves a one-line Menu link). Location: `Utilities/RegionLocator.swift` — when-in-use once, one reduced-accuracy fix, **MKReverseGeocodingRequest** (CLGeocoder is deprecated at the real deployment target, iOS 26.2), state parsed from `cityWithContext`, `Models/StateRegionMap.swift` (50+DC; HI deliberately unmapped → manual). All failures fall back to the manual menu. Usage-description key added to both configs.

**Suite: 212 tests, 0 failures** (200 + 6 `WeekFooterTests` + 6 `StateRegionMapTests`). Zero warnings. Launch verified on iPhone 17 + iPad Pro 11" sims.

## Next up

1. **Device pass of empty-week + region prompt** (checklist in HANDOFF, 2026-09-04 later entry — includes the on-device location flow), then merge `empty-week-and-region` to main.
2. **iPad phase 2** (when David says go): week view, recipe list, grocery list on regular width.
3. Announcement email for the 113/116 rollout.
4. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
5. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic. Doc nit: RULES/CLAUDE.md still say "target iOS 17+" — the project's deployment target is 26.2.
