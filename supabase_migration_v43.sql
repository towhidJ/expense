-- v43: Drop the stale 9-parameter overload of process_transaction.
--
-- v30 "replaced" process_transaction with CREATE OR REPLACE while adding
-- p_family_member_id — but a changed signature creates a NEW overload, so
-- both the v3 9-param and v30 10-param versions coexist. PostgREST then
-- fails 9-argument RPC calls (Vehicle, Utility, Committee, Charity, Rent,
-- Invoicing, Scan) with "Could not choose the best candidate function".
-- Dropping the 9-param version routes every caller to the 10-param one
-- (p_family_member_id defaults to NULL). Safe to re-run.

DROP FUNCTION IF EXISTS public.process_transaction(
  UUID, UUID, UUID, UUID, UUID, TEXT, NUMERIC, DATE, TEXT
);

-- PostgREST caches function signatures; make it reload immediately.
NOTIFY pgrst, 'reload schema';
