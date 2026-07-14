-- v22: Real push notifications (FCM), phase 1 of the feature-idea plan.
--   * fcm_tokens: one row per (user, device token) so a user's multiple
--     devices can all receive a push. Registered by the Flutter app right
--     after sign-in; self-cleaned by the Edge Function when FCM reports a
--     token as invalid/unregistered.
--   * pg_net: lets a trigger fire an outbound HTTP request without any
--     external cron/worker.
--   * meal_notification_push_dispatch: a single AFTER INSERT trigger on the
--     existing meal_notifications table (added in v19) that POSTs the new
--     row to the send-push Edge Function. Deliberately placed on the table
--     itself rather than touching any of the four existing
--     trg_notify_meal_* functions, so this is purely additive.
-- Manual steps outside this SQL file (see plan doc, Phase 1):
--   1. `supabase functions deploy send-push` (see supabase/functions/send-push).
--   2. Set the Edge Function secret FIREBASE_SERVICE_ACCOUNT_JSON.
--   3. Set app.settings.functions_url / app.settings.functions_secret below
--      to your project's values (or hardcode them) before running this file.
-- Run this in the Supabase SQL Editor (after v21).

-- ---------- 1. FCM device tokens ----------

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (token)
);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON fcm_tokens(user_id);

ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own fcm tokens" ON fcm_tokens;
CREATE POLICY "Users manage own fcm tokens" ON fcm_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Upsert-by-token so re-registering an existing token (app reinstall on the
-- same device, or the same token surviving a user switch) just re-points it.
CREATE OR REPLACE FUNCTION register_fcm_token(p_token TEXT, p_platform TEXT DEFAULT 'android')
RETURNS VOID AS $$
  INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
  VALUES (auth.uid(), p_token, p_platform, NOW())
  ON CONFLICT (token) DO UPDATE
    SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW();
$$ LANGUAGE sql SECURITY DEFINER;

-- ---------- 2. Push dispatch on new meal_notifications rows ----------

CREATE EXTENSION IF NOT EXISTS pg_net;

-- Project URL/secret are project-specific — fill these in before running.
-- (Supabase Dashboard > Settings > API for the URL; the secret is whatever
-- you set as the Edge Function's own shared secret, checked in its code.)
-- ALTER DATABASE (not set_config) so the setting is visible to every future
-- session/connection, not just the one running this migration. Supabase's
-- default database name is "postgres" — adjust if yours differs.
ALTER DATABASE postgres SET app.settings.functions_url =
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/send-push';
ALTER DATABASE postgres SET app.settings.functions_secret = 'REPLACE_ME';

CREATE OR REPLACE FUNCTION trg_dispatch_push_on_notification() RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := current_setting('app.settings.functions_url', true),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.functions_secret', true)
    ),
    body := jsonb_build_object(
      'user_id', NEW.user_id, 'title', NEW.title, 'body', NEW.body, 'link', NEW.link
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never let a push-delivery failure block the notification row itself.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_notification_push_dispatch ON meal_notifications;
CREATE TRIGGER meal_notification_push_dispatch
  AFTER INSERT ON meal_notifications
  FOR EACH ROW EXECUTE FUNCTION trg_dispatch_push_on_notification();
