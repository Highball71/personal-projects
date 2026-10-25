# Photo policy validation

These SQL files are for a disposable local Supabase PostgreSQL container, never production. They use synthetic identities and no real household data.

Using the official `public.ecr.aws/supabase/postgres:17.6.1.111` image with networking disabled and a disposable local password, run psql with `ON_ERROR_STOP=1` as the local `supabase_admin` role, in this order:

1. `../migrations/001_initial_schema.sql`
2. `020_local_storage_fixture.sql`
3. `../migrations/020_family_recipe_photos.sql`
4. `020_family_photos_test.sql`
5. Reapply migration 020 to verify idempotence.

The fixture supplies the minimal Storage SQL table/function surface and a database marker required by the tests. This validates PostgreSQL permissions and triggers, not Storage HTTP uploads or signed URL delivery. Destroy only the container and volumes created for this test when done.

For the optional cookbook-photo step, then run `../migrations/021_cookbook_photo.sql`, `021_cookbook_photo_test.sql`, and reapply migration 021. This verifies a separate private bucket, recipe/household path ownership, attached-object cleanup protection, and no change to cooking history. Migration 021 was deployed to FluffyList V2 on October 25 after these checks passed.

## Grocery cleanup and recovery

`grocery_cleanup_test.py` uses only a disposable Docker container named `fluffylist-grocery-validation` with networking disabled and the same dummy local password as the photo tests. In a fresh container apply migrations 001, 003, 005 and 015, then run `python3 grocery_cleanup_test.py`. Do not run against household data. Tests cover dry-run rollback, exact row/link recovery, refusing stale recovery, household and checked-item preservation, unit conversions, contribution IDs/amounts, incompatible units/notes, idempotence, and meal unwind.

The admin-only scripts `../scripts/cleanup_groceries.sql` and `restore_groceries.sql` are not app migrations or public RPCs. Cleanup defaults to ROLLBACK, requires an explicit household ID, and stores complete before/after snapshots in an RLS-enabled maintenance schema with no anon/authenticated access when committed. Every temporary work table also enables RLS. Recovery refuses to overwrite later grocery changes; the archive remains available for selective review if that guard fires. Nonempty notes are excluded from numeric consolidation because they can encode extra amounts or different package sizes. Checked rows remain unchanged.
