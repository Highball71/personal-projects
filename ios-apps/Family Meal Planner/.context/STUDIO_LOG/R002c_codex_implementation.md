Implemented the membership-routing hardening for the duplicate-household fix.

- Added an explicit household membership state on `SupabaseManager`: loading, noHousehold, hasHousehold(id), and failed(message).
- Updated `AuthService.loadHouseholdMembership` so a zero-row lookup becomes `.noHousehold`, but lookup failures become `.failed` instead of being swallowed.
- Updated `AppRootView` to show `HouseholdOnboardingView` only for `.noHousehold`; loading and failed states now show loading/retry UI.
- Updated `HouseholdService.createHousehold` to preflight existing membership/ownership before insert, and to recover from Postgres unique violations (`23505` / `one_owned_household_per_user`) by loading the existing household and routing into the app.

This keeps transient, slow, or failed household lookups from being interpreted as permission to create another household.
