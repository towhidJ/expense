-- v32: Store the Gemini API key (and any future app-wide secret) in the DB so
-- it can be managed from the web Admin panel instead of a CLI edge-function
-- secret. Run this in the Supabase SQL Editor (after v31). Safe to re-run.
--
-- Security model:
--   * Reads/writes go through SECURITY DEFINER functions that check
--     is_app_admin(), so only admins can change a setting and the raw secret is
--     never exposed to the client (get_app_setting_status returns a masked
--     preview only).
--   * The `gemini` edge function reads the value with the service-role key,
--     which bypasses RLS.

-- ---------- 0. Defensive: make sure the admin plumbing from v15 exists ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Make the owner account an admin (change the email if yours differs).
UPDATE profiles SET is_admin = TRUE
WHERE id IN (SELECT id FROM auth.users WHERE email = 'towhidul.ig@gmail.com');

CREATE OR REPLACE FUNCTION is_app_admin() RETURNS BOOLEAN AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE id = auth.uid()), FALSE);
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---------- 1. Settings table ----------
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
-- No client policies at all: the table is reached only through the SECURITY
-- DEFINER functions below and the edge function's service-role key.

-- ---------- 2. Write a setting (admin only) ----------
CREATE OR REPLACE FUNCTION set_app_setting(p_key TEXT, p_value TEXT)
RETURNS VOID AS $$
BEGIN
  IF NOT is_app_admin() THEN
    RAISE EXCEPTION 'Only admins can change app settings';
  END IF;
  INSERT INTO app_settings (key, value, updated_at)
  VALUES (p_key, p_value, NOW())
  ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 3. Masked status for the Admin UI (never returns the raw value) ----------
CREATE OR REPLACE FUNCTION get_app_setting_status(p_key TEXT)
RETURNS TABLE (is_set BOOLEAN, preview TEXT, updated_at TIMESTAMPTZ) AS $$
  SELECT
    (s.value IS NOT NULL AND length(s.value) > 0),
    CASE
      WHEN s.value IS NULL OR length(s.value) < 8 THEN NULL
      ELSE left(s.value, 4) || '••••' || right(s.value, 4)
    END,
    s.updated_at
  FROM app_settings s
  WHERE s.key = p_key AND is_app_admin();
$$ LANGUAGE sql SECURITY DEFINER STABLE;
