-- Captures a unique index that already existed on the live DB (created via
-- dashboard, absent from migrations). IF NOT EXISTS = no-op on live.
create unique index if not exists one_owned_household_per_user
  on public.households using btree (owner_id);
