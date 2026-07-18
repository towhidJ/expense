-- v44: Make account deletion possible — cascade all FKs that reference
-- profiles(id) or auth.users.
--
-- The admin Users tab gained a "Delete user" action (admin-users edge fn,
-- auth.admin.deleteUser). That deletes the auth.users row, which must
-- cascade through profiles into every per-user table — but the original
-- schema declared `user_id UUID REFERENCES profiles(id)` with no ON DELETE
-- action, so the delete would abort on the first table with data.
--
-- Rather than enumerate every table (30+ and growing), rewrite every
-- foreign key whose target is public.profiles or auth.users to
-- ON DELETE CASCADE dynamically. Child tables hanging off those rows
-- (vehicle_logs -> vehicles, invoice_items -> invoices, ...) already
-- declare their own ON DELETE CASCADE/SET NULL. Safe to re-run (no-op
-- once every FK already cascades).

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT con.conname,
           con.conrelid::regclass AS tbl,
           pg_get_constraintdef(con.oid) AS def
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE con.contype = 'f'
      AND nsp.nspname = 'public'
      AND con.confrelid IN ('public.profiles'::regclass, 'auth.users'::regclass)
      AND con.confdeltype <> 'c'  -- skip ones that already cascade
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
    EXECUTE format(
      'ALTER TABLE %s ADD CONSTRAINT %I %s ON DELETE CASCADE',
      r.tbl, r.conname,
      -- keep the original definition minus any existing ON DELETE clause
      regexp_replace(r.def, ' ON DELETE (SET NULL|SET DEFAULT|RESTRICT|NO ACTION)', '')
    );
  END LOOP;
END $$;
