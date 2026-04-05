# FluffyList — Current Status

## Build State
- TestFlight build uploaded: 1.0 (85)
- Bundle ID: com.highball71.fluffylist.beta
- App name: FluffyList Beta

## Core Features Working
- Add recipe
- Assign to tonight
- Recipe awareness (planned today/tomorrow)
- Editable meal slots (replace / clear / assign)
- Week view planning
- Empty state onboarding

## Architecture
- MealPlanningStore handles all writes
- Views use fetch for display
- No CloudKit yet

## Known Issues
- UI is rough
- No household sharing yet
- No smart filtering ("what do we have?")
- No leftovers planning

## Next Priorities
1. Improve planner UX based on real usage
2. Household sharing (CloudKit, single household model)
3. UI polish
4. Smart filtering

## Notes
- Focus on usability before adding features
- Do not start CloudKit until planner UX feels solid
