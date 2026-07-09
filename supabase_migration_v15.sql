-- v15: In-app OTA updates — admin uploads a new APK from the web admin panel,
-- the Android app checks app_versions on launch and offers to install it.
-- Run this in the Supabase SQL Editor (after v14).

-- ---------- 1. Admin flag ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Make the owner account the admin (change the email if needed)
UPDATE profiles SET is_admin = TRUE
WHERE id IN (SELECT id FROM auth.users WHERE email = 'towhidul.ig@gmail.com');

-- SECURITY DEFINER so it can be used inside RLS/storage policies without
-- tripping over profiles' own row-level security.
CREATE OR REPLACE FUNCTION is_app_admin() RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM profiles WHERE id = auth.uid()),
    FALSE
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---------- 2. Published app versions ----------
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  version_code INT NOT NULL UNIQUE,      -- Android versionCode (the +N in pubspec.yaml)
  version_name TEXT NOT NULL,            -- e.g. "1.1.0"
  notes TEXT,                            -- release notes shown in the update dialog
  apk_path TEXT NOT NULL,                -- storage path inside the app-releases bucket
  apk_url TEXT NOT NULL,                 -- public download URL
  file_size BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Every signed-in app user may check for updates
DROP POLICY IF EXISTS "Authenticated users can read app versions" ON app_versions;
CREATE POLICY "Authenticated users can read app versions" ON app_versions
  FOR SELECT TO authenticated USING (TRUE);

-- Only admins may publish or remove releases
DROP POLICY IF EXISTS "Admins can manage app versions" ON app_versions;
CREATE POLICY "Admins can manage app versions" ON app_versions
  FOR ALL TO authenticated USING (is_app_admin()) WITH CHECK (is_app_admin());

-- ---------- 3. Storage bucket for the APK files ----------
-- Public bucket: the app downloads the APK with a plain URL (Android
-- DownloadManager can't send auth headers).
INSERT INTO storage.buckets (id, name, public)
VALUES ('app-releases', 'app-releases', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

DROP POLICY IF EXISTS "Public read app releases" ON storage.objects;
CREATE POLICY "Public read app releases" ON storage.objects
  FOR SELECT USING (bucket_id = 'app-releases');

DROP POLICY IF EXISTS "Admins upload app releases" ON storage.objects;
CREATE POLICY "Admins upload app releases" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'app-releases' AND is_app_admin());

DROP POLICY IF EXISTS "Admins update app releases" ON storage.objects;
CREATE POLICY "Admins update app releases" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'app-releases' AND is_app_admin());

DROP POLICY IF EXISTS "Admins delete app releases" ON storage.objects;
CREATE POLICY "Admins delete app releases" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'app-releases' AND is_app_admin());
