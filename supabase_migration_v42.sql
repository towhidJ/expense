-- v42: Free-tier workspace (entity) limit — a free account gets one
-- workspace (the "Personal" one created at signup); Premium or admin
-- unlocks additional Family/Business workspaces. Run after v39-v41 in the
-- Supabase SQL Editor. Safe to re-run.
--
-- Enforced server-side via RLS WITH CHECK (not just client UX) using the
-- has_premium()/is_app_admin() helpers from v39/v40 — a free user's INSERT
-- into `entities` beyond their first row is rejected regardless of what the
-- client sends. The signup trigger (handle_new_user, SECURITY DEFINER)
-- bypasses RLS entirely, so the very first "Personal" workspace is
-- unaffected by this policy.

DROP POLICY IF EXISTS "Users can manage their own entities" ON entities;
DROP POLICY IF EXISTS "Users can view own entities" ON entities;
DROP POLICY IF EXISTS "Users can update own entities" ON entities;
DROP POLICY IF EXISTS "Users can delete own entities" ON entities;
DROP POLICY IF EXISTS "Free accounts get one workspace, Premium unlocks more" ON entities;

CREATE POLICY "Users can view own entities" ON entities
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can update own entities" ON entities
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own entities" ON entities
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Free accounts get one workspace, Premium unlocks more" ON entities
  FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = user_id
    AND (
      has_premium(auth.uid())
      OR is_app_admin()
      OR (SELECT COUNT(*) FROM entities e WHERE e.user_id = auth.uid()) < 1
    )
  );
