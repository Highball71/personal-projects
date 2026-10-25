# Photo policy validation

These SQL files are for a disposable local Supabase PostgreSQL container, never production. They use synthetic identities and no real household data.

Using the official `public.ecr.aws/supabase/postgres:17.6.1.111` image with networking disabled and a disposable local password, run psql with `ON_ERROR_STOP=1` as the local `supabase_admin` role, in this order:

1. `../migrations/001_initial_schema.sql`
2. `020_local_storage_fixture.sql`
3. `../migrations/020_family_recipe_photos.sql`
4. `020_family_photos_test.sql`
5. Reapply migration 020 to verify idempotence.

The fixture supplies the minimal Storage SQL table/function surface and a database marker required by the tests. This validates PostgreSQL permissions and triggers, not Storage HTTP uploads or signed URL delivery. Destroy only the container and volumes created for this test when done.
