-- v40: Free trial — 3 days of Premium for every new signup, plus an admin
-- "grant trial" action. Run this in the Supabase SQL Editor (after v39).
-- Safe to re-run.
--
-- Model:
--   * user_subscriptions gets an is_trial flag so the UI can tell a trial
--     apart from a paid/admin-granted plan (e.g. "Trial ends in 2 days" vs
--     "Premium until ...").
--   * New signups get a 3-day trial row inserted by handle_new_user() (the
--     same trigger that creates the profile + default entity).
--   * admin_set_subscription(p_user, 'trial') lets an admin (re-)grant a
--     fresh 3-day trial to any account from the Users tab. Paid grants
--     (monthly/yearly/lifetime) clear is_trial since they replace it.
--   * Trial expiry falls back to the existing free-tier paywall behavior —
--     no separate "locked out" state, same as an expired paid plan.

-- ---------- 1. user_subscriptions.is_trial ----------
ALTER TABLE user_subscriptions ADD COLUMN IF NOT EXISTS is_trial BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------- 2. New signups get a 3-day trial ----------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');

  INSERT INTO public.entities (user_id, name, type)
  VALUES (new.id, 'Personal', 'personal');

  INSERT INTO public.user_subscriptions (user_id, started_at, expires_at, is_trial)
  VALUES (new.id, NOW(), NOW() + INTERVAL '3 days', TRUE)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 3. get_my_subscription reports is_trial ----------
-- Adding a column to the OUT parameters changes the function's return type,
-- which CREATE OR REPLACE cannot do — drop first.
DROP FUNCTION IF EXISTS get_my_subscription();
CREATE OR REPLACE FUNCTION get_my_subscription()
RETURNS TABLE (is_active BOOLEAN, is_lifetime BOOLEAN, expires_at TIMESTAMPTZ, is_trial BOOLEAN) AS $$
  SELECT
    (s.expires_at IS NULL OR s.expires_at > NOW()),
    (s.expires_at IS NULL),
    s.expires_at,
    s.is_trial
  FROM user_subscriptions s
  WHERE s.user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---------- 4. Paid approval clears the trial flag ----------
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
    -- A trial's remaining days are not stacked into a paid plan — paying
    -- starts the real term from now, same as a first-time subscriber.
    IF v_req.duration = 'lifetime' OR (FOUND AND v_existing.expires_at IS NULL AND NOT v_existing.is_trial) THEN
      v_new_expiry := NULL; -- lifetime (an existing lifetime is never downgraded)
    ELSE
      v_base := CASE WHEN FOUND AND NOT v_existing.is_trial
        THEN GREATEST(NOW(), COALESCE(v_existing.expires_at, NOW()))
        ELSE NOW() END;
      v_new_expiry := v_base + CASE v_req.duration
        WHEN 'monthly' THEN INTERVAL '1 month'
        WHEN 'yearly' THEN INTERVAL '1 year'
      END;
    END IF;

    INSERT INTO user_subscriptions (user_id, started_at, expires_at, source_request_id, is_trial, updated_at)
    VALUES (v_req.user_id, NOW(), v_new_expiry, v_req.id, FALSE, NOW())
    ON CONFLICT (user_id) DO UPDATE
      SET expires_at = EXCLUDED.expires_at,
          source_request_id = EXCLUDED.source_request_id,
          is_trial = FALSE,
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

-- ---------- 5. admin_set_subscription: add a 'trial' grant ----------
-- p_duration NULL revokes; 'trial' grants a fresh 3 days from now (does not
-- stack with any remaining time — same "reset the clock" behavior as
-- starting a first paid term).
CREATE OR REPLACE FUNCTION admin_set_subscription(p_user UUID, p_duration TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
  v_existing user_subscriptions%ROWTYPE;
  v_new_expiry TIMESTAMPTZ;
  v_is_trial BOOLEAN;
BEGIN
  IF NOT is_app_admin() THEN
    RAISE EXCEPTION 'Only admins can manage subscriptions';
  END IF;

  IF p_duration IS NULL THEN
    DELETE FROM user_subscriptions WHERE user_id = p_user;
    RETURN;
  END IF;
  IF p_duration NOT IN ('trial', 'monthly', 'yearly', 'lifetime') THEN
    RAISE EXCEPTION 'Invalid duration';
  END IF;

  IF p_duration = 'trial' THEN
    v_new_expiry := NOW() + INTERVAL '3 days';
    v_is_trial := TRUE;
  ELSE
    v_is_trial := FALSE;
    SELECT * INTO v_existing FROM user_subscriptions WHERE user_id = p_user;
    IF p_duration = 'lifetime' OR (FOUND AND v_existing.expires_at IS NULL AND NOT v_existing.is_trial) THEN
      v_new_expiry := NULL;
    ELSE
      v_new_expiry := (CASE WHEN FOUND AND NOT v_existing.is_trial
        THEN GREATEST(NOW(), COALESCE(v_existing.expires_at, NOW()))
        ELSE NOW() END)
        + CASE p_duration WHEN 'monthly' THEN INTERVAL '1 month' ELSE INTERVAL '1 year' END;
    END IF;
  END IF;

  INSERT INTO user_subscriptions (user_id, started_at, expires_at, is_trial, updated_at)
  VALUES (p_user, NOW(), v_new_expiry, v_is_trial, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET expires_at = EXCLUDED.expires_at, is_trial = EXCLUDED.is_trial, updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
