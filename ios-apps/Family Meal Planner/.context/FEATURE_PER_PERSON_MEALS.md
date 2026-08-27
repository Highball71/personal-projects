# FEATURE — Per-Person Meals (design only, not yet built)

Drafted 2026-08-27 (chat session) from tester feedback triage (Kristin).
Status: **APPROVED 2026-08-27 (all four decisions below). Phase 1
(migration 013 + model decode, shipped dark) implemented 2026-08-27;
Phases 2–3 not yet built.**
Companion to the dietary-preferences promise onboarding makes but doesn't keep
(POLISH list in HANDOFF).

---

## Goal

A meal plan row can belong to one household member ("Maya gets the pasta")
or to the whole household (today's behavior). `member_id NULL = everyone`.
Fold in dietary preferences: they become **per-member** data that the recipe
picker actually uses, instead of a device-local string nothing reads.

## The one hard problem: members require accounts

`household_members.user_id` is `NOT NULL REFERENCES auth.users` — a member
*is* an Apple-ID account. Per-person planning is mostly about kids, who
don't have accounts. Decision required before any schema work:

**Recommended — Option 1: relax `user_id` to nullable.**
"Profile members" are rows with `user_id IS NULL`, created by any member
from a new "People" screen. Why it's safe:
- `is_household_member()` matches on `auth.uid()` = `user_id`; NULL never
  matches, so profile members can't authenticate as anyone — RLS unchanged.
- `unique(household_id, user_id)` — Postgres treats NULLs as distinct, so
  multiple profile members per household are allowed without touching the
  constraint.
- Head-cook / join-code flows only ever create account members; untouched.

Option 2 (rejected for now): a separate `household_people` table. Cleaner
conceptually but duplicates display_name handling, and every future
per-person feature (ratings, portions) would need to join two tables.

## Migration `013_member_meals.sql` (additive, re-runnable like 004/006)

1. `alter table household_members alter column user_id drop not null;`
2. `alter table household_members add column if not exists dietary_preferences text[] not null default '{}';`
   - Values are the raw strings of the existing `DietaryOption` enum
     ("Vegetarian", "Nut-Free", …) so the Swift enum round-trips.
3. `create unique index if not exists household_members_id_household_key on household_members (id, household_id);`
   - Enables the composite FK below.
4. `alter table meal_plans add column if not exists member_id uuid;`
5. Composite FK — this is the tenant-safety mechanism:
   `alter table meal_plans add constraint meal_plans_member_same_household_fk
    foreign key (member_id, household_id)
    references household_members (id, household_id)
    on delete set null;`
   - A meal can only reference a member **of its own household**. Without
     this, RLS alone would let a member attach someone else's household
     member id (insert policy only checks `is_household_member(household_id)`).
   - CAUTION: `ON DELETE SET NULL` on a composite FK nulls **both**
     columns, and `household_id` is `NOT NULL` — so that clause is wrong
     here. Use `on delete no action` on the FK and rely on the existing
     member-delete path… except there isn't one yet (members are only
     removed by auth cascade, which cascades the whole membership).
     **Resolution:** trigger instead — `before delete on household_members`
     → `update meal_plans set member_id = null where member_id = old.id`.
     Keep the composite FK with `on delete no action` for insert/update
     safety; the trigger handles cleanup. Flag this in review — easy to
     get wrong.

## RLS changes

**None to the four meal_plans policies.** Scoping stays household-wide:
any member can see and edit everyone's meals (family model, matches
groceries). The composite FK above is what prevents cross-household
member references — declarative, no policy rewrite, nothing for the
R00x-style audit to re-verify beyond the FK + trigger.

If David later wants "only I can edit my meals," that's a policy change
(`member_id is null or member_id in (select id from household_members
where user_id = auth.uid())` on UPDATE/DELETE) — explicitly out of scope
for v1; it would break the head-cook-plans-for-everyone flow.

## App model + service changes

- `MealPlanRow`: add `let memberID: UUID?`; custom decoder gets
  `memberID = try? c.decode(UUID.self, forKey: .memberID)` — old rows and
  old app versions stay compatible both directions (unknown key is
  ignored on decode; column default NULL on insert).
- `MealPlanInsert`: optional `member_id`.
- **Slot semantics** (the real design work — `addMealWithGroceries`
  clears the whole day today):
  - Slot key becomes `(date, member_id)` with NULL = the household slot.
  - Assigning a **household** meal to a day: clears only the household
    slot (member meals survive). Assigning a **member** meal: clears only
    that member's slot.
  - `clearDayWithGroceries` keeps its current meaning (nuke the day) for
    the day-level "Remove" action; add a member-scoped variant.
  - Copy-last-week copies rows with their `member_id`, skip rules applied
    per (day, member) slot.
- `HouseholdService` (or wherever members load): fetch members with
  dietary prefs; add create/rename/delete for profile members.

## UI (Press language)

- **People screen** (Settings → "The household"): ruled rows, member name
  in Source Serif, dietary prefs as the existing underlined word chips,
  "Add a person →" text link. Profile members get no join-code machinery.
- **Assignment**: in RecipePickerSheet (and detail-view "Add to the
  week"), a small-caps chip row above the confirm — `EVERYONE · MAYA ·
  SAM` — defaulting to EVERYONE. One tap, no new sheet.
- **Week view day row**: member meals render as an indented second line
  under the day — small-caps name as kicker before the recipe title.
  Household meal stays the primary line. (Multi-line day rows are new;
  Dynamic Type pass required.)
- **Dietary in the picker**: recipes conflicting with the selected
  person's prefs get a `FluffyMetadataLine` warning ("CONTAINS DAIRY —
  MAYA AVOIDS DAIRY" is aspirational; v1 realistically can only match
  category/ingredient keywords — start with keyword match on ingredient
  names, be honest about misses). Never block, only flag.

## Onboarding promise, kept

- HouseholdSetupView's dietary chips stop writing to
  `@AppStorage("dietaryPreferences")` and instead write to the creating
  member's `dietary_preferences` column (they're the first member).
- Settings' dietary section moves under the person, not the device.
- Migration of existing device-local prefs: on first launch post-update,
  if `dietaryPrefsRaw` is non-empty and my member row's array is empty,
  push it up, then clear the AppStorage key.

## Phasing

1. `013` migration + models decode (ships dark — no UI reads member_id).
2. People screen + profile members + per-member dietary storage +
   AppStorage migration. (Promise kept even before per-person meals ship.)
3. Slot-semantics rework in MealPlanService + assignment chips + day-row
   rendering.
Each phase is independently shippable; 3 is the risky one.

## Open decisions for David — ALL DECIDED 2026-08-27

1. **DECIDED: Option 1** (nullable `user_id`). Profile members are
   `user_id IS NULL` rows; Option 2 (separate table) rejected.
2. **DECIDED: Yes** — member meals contribute groceries identically to
   household meals (same `addMealWithGroceries` path).
3. **DECIDED: One meal per day per person.** The household slot and each
   member's slot are separate slots on the same day, but no person (and
   not the household) gets two meals on one day. No multi-meal-per-person.
4. **DECIDED: Yes** — keyword-only dietary matching is fine for v1.
   Flag, never block; be honest about misses.
