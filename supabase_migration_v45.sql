-- v45: Public user manual / help documents.
--
-- The admin panel gains a "Manuals" tab to upload PDF guides (the Bangla user
-- manual, English guide, etc.). Unlike almost everything else in the app, these
-- are PUBLIC — the read policy allows the `anon` role too, so the login page
-- (shown before sign-in) and the app footer can link to the manual without a
-- session. Only admins may upload or delete.
--
-- Run this in the Supabase SQL Editor (after v44).

-- ---------- 1. Manuals table ----------
CREATE TABLE IF NOT EXISTS app_manuals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,                    -- e.g. "ব্যবহার নির্দেশিকা (Bangla)"
  description TEXT,                        -- optional one-line blurb
  file_path TEXT NOT NULL,                -- storage path inside the app-manuals bucket
  file_url TEXT NOT NULL,                 -- public URL
  file_size BIGINT,
  sort_order INT NOT NULL DEFAULT 0,      -- lower shows first
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE app_manuals ENABLE ROW LEVEL SECURITY;

-- Anyone (even signed-out visitors on the login page) may read the manual list.
DROP POLICY IF EXISTS "Anyone can read manuals" ON app_manuals;
CREATE POLICY "Anyone can read manuals" ON app_manuals
  FOR SELECT USING (TRUE);

-- Only admins may add or remove manuals.
DROP POLICY IF EXISTS "Admins can manage manuals" ON app_manuals;
CREATE POLICY "Admins can manage manuals" ON app_manuals
  FOR ALL TO authenticated USING (is_app_admin()) WITH CHECK (is_app_admin());

-- ---------- 2. Storage bucket for the manual files ----------
-- Public bucket so the file opens with a plain URL, no auth headers needed.
INSERT INTO storage.buckets (id, name, public)
VALUES ('app-manuals', 'app-manuals', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

DROP POLICY IF EXISTS "Public read manuals" ON storage.objects;
CREATE POLICY "Public read manuals" ON storage.objects
  FOR SELECT USING (bucket_id = 'app-manuals');

DROP POLICY IF EXISTS "Admins upload manuals" ON storage.objects;
CREATE POLICY "Admins upload manuals" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'app-manuals' AND is_app_admin());

DROP POLICY IF EXISTS "Admins update manuals" ON storage.objects;
CREATE POLICY "Admins update manuals" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'app-manuals' AND is_app_admin());

DROP POLICY IF EXISTS "Admins delete manuals" ON storage.objects;
CREATE POLICY "Admins delete manuals" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'app-manuals' AND is_app_admin());
