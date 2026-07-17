-- v39: Commercial billing — admin panel + Premium subscription system.
-- Run this in the Supabase SQL Editor (after v38). Safe to re-run.
--
-- Model:
--   * One Premium plan. Admin marks modules free/premium (module_access) and
--     configures which durations are sold (monthly/yearly/lifetime) with
--     prices + bKash/Nagad payment numbers (billing_settings).
--   * Payments are MANUAL: the user sends money via bKash/Nagad and submits a
--     request with the transaction ID (subscription_requests). An admin
--     verifies it against the wallet statement and approves/rejects. Approval
--     activates/extends user_subscriptions (per-USER, never per-entity).
--   * Client-side module gating is UX-only; everything that matters (submit,
--     review, config writes) is enforced here via RLS + SECURITY DEFINER RPCs.

-- ---------- 0. Defensive: admin plumbing from v15/v32 ----------
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION is_app_admin() RETURNS BOOLEAN AS $$
  SELECT COALESCE((SELECT is_admin FROM profiles WHERE id = auth.uid()), FALSE);
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Admins can read every profile (needed to show requester names in the
-- admin queue via embedded selects). Users still only manage their own row.
DROP POLICY IF EXISTS "Admins read all profiles" ON profiles;
CREATE POLICY "Admins read all profiles" ON profiles
  FOR SELECT TO authenticated USING (is_app_admin());

-- ---------- 1. billing_settings: single-row public config ----------
CREATE TABLE IF NOT EXISTS billing_settings (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  monthly_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  monthly_price NUMERIC NOT NULL DEFAULT 100,
  yearly_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  yearly_price NUMERIC NOT NULL DEFAULT 1000,
  lifetime_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  lifetime_price NUMERIC NOT NULL DEFAULT 3000,
  bkash_number TEXT,
  bkash_account_type TEXT DEFAULT 'personal', -- personal / agent / merchant
  nagad_number TEXT,
  nagad_account_type TEXT DEFAULT 'personal',
  instructions TEXT, -- free text shown on the paywall
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO billing_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE billing_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone reads billing settings" ON billing_settings;
CREATE POLICY "Anyone reads billing settings" ON billing_settings
  FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Admins manage billing settings" ON billing_settings;
CREATE POLICY "Admins manage billing settings" ON billing_settings
  FOR ALL TO authenticated USING (is_app_admin()) WITH CHECK (is_app_admin());

-- ---------- 2. module_access: which modules are premium ----------
-- Missing key = free. dashboard/transactions/accounts are deliberately never
-- seeded: the core trio cannot be gated.
CREATE TABLE IF NOT EXISTS module_access (
  module_key TEXT PRIMARY KEY,
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO module_access (module_key) VALUES
  ('bazar'), ('reports'), ('budgets'), ('goals'), ('savings'), ('transfers'),
  ('recurring'), ('categories'), ('assets'), ('liabilities'), ('investments'),
  ('family'), ('meals'), ('lending'), ('forecast'), ('zakat'),
  ('subscriptions'), ('insurance'), ('utility'), ('rent'), ('warranty'),
  ('backup'), ('activity'), ('splitter'), ('tax'), ('insights'), ('scan'),
  ('import')
ON CONFLICT (module_key) DO NOTHING;

ALTER TABLE module_access ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone reads module access" ON module_access;
CREATE POLICY "Anyone reads module access" ON module_access
  FOR SELECT TO authenticated USING (TRUE);
DROP POLICY IF EXISTS "Admins manage module access" ON module_access;
CREATE POLICY "Admins manage module access" ON module_access
  FOR ALL TO authenticated USING (is_app_admin()) WITH CHECK (is_app_admin());

-- ---------- 3. subscription_requests: manual payment verification queue ----------
CREATE TABLE IF NOT EXISTS subscription_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  duration TEXT NOT NULL CHECK (duration IN ('monthly', 'yearly', 'lifetime')),
  method TEXT NOT NULL CHECK (method IN ('bkash', 'nagad')),
  trx_id TEXT NOT NULL,
  sender_number TEXT NOT NULL,
  amount NUMERIC,          -- what the user says they sent
  expected_amount NUMERIC, -- configured price snapshotted at submit time
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reject_reason TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- An approved/pending trx id can never be claimed twice; a rejected one (typo)
-- may be resubmitted.
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscription_requests_trx
  ON subscription_requests (lower(trim(trx_id))) WHERE status IN ('pending', 'approved');
CREATE INDEX IF NOT EXISTS idx_subscription_requests_queue
  ON subscription_requests (status, created_at);
CREATE INDEX IF NOT EXISTS idx_subscription_requests_user
  ON subscription_requests (user_id, created_at);

ALTER TABLE subscription_requests ENABLE ROW LEVEL SECURITY;
-- Read own-or-admin; NO write policies — all writes go through the RPCs below.
DROP POLICY IF EXISTS "Users read own subscription requests" ON subscription_requests;
CREATE POLICY "Users read own subscription requests" ON subscription_requests
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_app_admin());

-- ---------- 4. user_subscriptions: one row per premium account ----------
CREATE TABLE IF NOT EXISTS user_subscriptions (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ, -- NULL = lifetime
  source_request_id UUID REFERENCES subscription_requests(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own subscription" ON user_subscriptions;
CREATE POLICY "Users read own subscription" ON user_subscriptions
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_app_admin());

-- ---------- 5. Notification type for approval/rejection pushes ----------
ALTER TABLE finance_notifications DROP CONSTRAINT IF EXISTS finance_notifications_type_check;
ALTER TABLE finance_notifications ADD CONSTRAINT finance_notifications_type_check
  CHECK (type IN ('budget_overspend', 'bill_due', 'recurring_posted',
                  'weekly_digest', 'goal_milestone', 'large_expense', 'rent_due',
                  'subscription_update'));

-- ---------- 6. RPCs ----------

CREATE OR REPLACE FUNCTION has_premium(p_user UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_subscriptions
    WHERE user_id = p_user AND (expires_at IS NULL OR expires_at > NOW())
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_my_subscription()
RETURNS TABLE (is_active BOOLEAN, is_lifetime BOOLEAN, expires_at TIMESTAMPTZ) AS $$
  SELECT
    (s.expires_at IS NULL OR s.expires_at > NOW()),
    (s.expires_at IS NULL),
    s.expires_at
  FROM user_subscriptions s
  WHERE s.user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION submit_subscription_request(
  p_duration TEXT,
  p_method TEXT,
  p_trx_id TEXT,
  p_sender_number TEXT,
  p_amount NUMERIC DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_cfg billing_settings%ROWTYPE;
  v_expected NUMERIC;
  v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF p_trx_id IS NULL OR length(trim(p_trx_id)) < 4 THEN
    RAISE EXCEPTION 'Please enter the transaction ID from your payment.';
  END IF;
  IF p_sender_number IS NULL OR length(trim(p_sender_number)) < 6 THEN
    RAISE EXCEPTION 'Please enter the mobile number you paid from.';
  END IF;

  SELECT * INTO v_cfg FROM billing_settings WHERE id = 1;
  v_expected := CASE p_duration
    WHEN 'monthly'  THEN CASE WHEN v_cfg.monthly_enabled  THEN v_cfg.monthly_price  END
    WHEN 'yearly'   THEN CASE WHEN v_cfg.yearly_enabled   THEN v_cfg.yearly_price   END
    WHEN 'lifetime' THEN CASE WHEN v_cfg.lifetime_enabled THEN v_cfg.lifetime_price END
  END;
  IF v_expected IS NULL THEN
    RAISE EXCEPTION 'This plan is not available right now.';
  END IF;

  IF EXISTS (SELECT 1 FROM subscription_requests
             WHERE user_id = auth.uid() AND status = 'pending') THEN
    RAISE EXCEPTION 'You already have a pending request. Please wait for it to be reviewed.';
  END IF;

  BEGIN
    INSERT INTO subscription_requests
      (user_id, duration, method, trx_id, sender_number, amount, expected_amount)
    VALUES
      (auth.uid(), p_duration, p_method, trim(p_trx_id), trim(p_sender_number),
       p_amount, v_expected)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'This transaction ID was already submitted.';
  END;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION review_subscription_request(
  p_request_id UUID,
  p_approve BOOLEAN,
  p_reason TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_req subscription_requests%ROWTYPE;
  v_existing user_subscriptions%ROWTYPE;
  v_base TIMESTAMPTZ;
  v_new_expiry TIMESTAMPTZ;
BEGIN
  IF NOT is_app_admin() THEN
    RAISE EXCEPTION 'Only admins can review subscription requests';
  END IF;

  SELECT * INTO v_req FROM subscription_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'This request was already reviewed';
  END IF;
  IF v_req.user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot review your own request';
  END IF;

  IF p_approve THEN
    SELECT * INTO v_existing FROM user_subscriptions WHERE user_id = v_req.user_id;
    IF v_req.duration = 'lifetime' OR (FOUND AND v_existing.expires_at IS NULL) THEN
      v_new_expiry := NULL; -- lifetime (an existing lifetime is never downgraded)
    ELSE
      v_base := GREATEST(NOW(), COALESCE(v_existing.expires_at, NOW()));
      v_new_expiry := v_base + CASE v_req.duration
        WHEN 'monthly' THEN INTERVAL '1 month'
        WHEN 'yearly' THEN INTERVAL '1 year'
      END;
    END IF;

    INSERT INTO user_subscriptions (user_id, started_at, expires_at, source_request_id, updated_at)
    VALUES (v_req.user_id, NOW(), v_new_expiry, v_req.id, NOW())
    ON CONFLICT (user_id) DO UPDATE
      SET expires_at = EXCLUDED.expires_at,
          source_request_id = EXCLUDED.source_request_id,
          updated_at = NOW();

    UPDATE subscription_requests
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_request_id;
  ELSE
    UPDATE subscription_requests
    SET status = 'rejected', reject_reason = p_reason,
        reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_request_id;
  END IF;

  -- Push notification to the requester via the existing
  -- finance_notifications → pg_net → send-push → FCM pipeline.
  INSERT INTO finance_notifications (user_id, type, ref_id, title, body, link)
  VALUES (
    v_req.user_id,
    'subscription_update',
    v_req.id,
    CASE WHEN p_approve THEN 'Subscription activated 🎉' ELSE 'Subscription request rejected' END,
    CASE WHEN p_approve
      THEN 'Your ' || v_req.duration || ' Premium subscription is now active. Enjoy!'
      ELSE COALESCE('Reason: ' || p_reason, 'Please check the transaction ID and try again.')
    END,
    '/subscription'
  )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Manual grant/extend/revoke from the admin Users tab (goodwill, refunds…).
-- p_duration NULL revokes.
CREATE OR REPLACE FUNCTION admin_set_subscription(p_user UUID, p_duration TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
  v_existing user_subscriptions%ROWTYPE;
  v_new_expiry TIMESTAMPTZ;
BEGIN
  IF NOT is_app_admin() THEN
    RAISE EXCEPTION 'Only admins can manage subscriptions';
  END IF;

  IF p_duration IS NULL THEN
    DELETE FROM user_subscriptions WHERE user_id = p_user;
    RETURN;
  END IF;
  IF p_duration NOT IN ('monthly', 'yearly', 'lifetime') THEN
    RAISE EXCEPTION 'Invalid duration';
  END IF;

  SELECT * INTO v_existing FROM user_subscriptions WHERE user_id = p_user;
  IF p_duration = 'lifetime' OR (FOUND AND v_existing.expires_at IS NULL) THEN
    v_new_expiry := NULL;
  ELSE
    v_new_expiry := GREATEST(NOW(), COALESCE(v_existing.expires_at, NOW()))
      + CASE p_duration WHEN 'monthly' THEN INTERVAL '1 month' ELSE INTERVAL '1 year' END;
  END IF;

  INSERT INTO user_subscriptions (user_id, started_at, expires_at, updated_at)
  VALUES (p_user, NOW(), v_new_expiry, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET expires_at = EXCLUDED.expires_at, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
