-- v33 (SELF-CONTAINED): notification expansion pack + all prerequisites.
-- Discovered while running the health check: v28 was never applied (no
-- finance_notifications, no pg_cron), so this file now carries everything it
-- needs — the v22 push plumbing, the v28 finance_notifications table, and the
-- v30 alert function — all guarded with IF NOT EXISTS so it is safe to run
-- (and re-run) regardless of which earlier migrations were applied.
-- Run the whole file in the Supabase SQL Editor.
--
-- ONE manual step after this file (in a terminal, once):
--   supabase functions deploy send-push --no-verify-jwt
-- send-push is currently deployed with JWT verification ON, so the platform
-- gateway rejects the DB trigger's call (a shared-secret Bearer, not a JWT)
-- with 401 before the function even runs — no push was ever delivered.
-- Optional hardening afterwards: pick a long random string and set it in both
-- places so only the DB can call the function:
--   INSERT INTO app_settings (key, value) VALUES ('push_functions_secret', '<random>')
--     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
--   supabase secrets set FUNCTIONS_SHARED_SECRET=<random>
--
-- What the expansion adds (all reuse the push chain — an INSERT into
-- meal_notifications / finance_notifications delivers bell + phone push):
--   * Cron timezone fix — pg_cron runs in UTC; jobs below land at Dhaka times.
--   * run_all_due_recurring(): server-side auto-post of due recurring
--     transactions + savings for every user (was client-open only).
--   * finance_daily_alerts(): budget/bill alerts + goal milestones (50/75/100%)
--     + unusual large-expense alerts.
--   * finance_weekly_digest(): Saturday-morning spending summary.
--   * meal_evening_reminders(): 8pm Dhaka — tomorrow's missing-entry reminder,
--     duty reminder, low-balance warning.
--   * Month-close trigger: each member gets their final balance pushed.

-- ============================================================
-- 0. PREREQUISITES (from v22 / v28 / v30 — skipped where already applied)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---- 0a. FCM device tokens (v22) ----
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

CREATE OR REPLACE FUNCTION register_fcm_token(p_token TEXT, p_platform TEXT DEFAULT 'android')
RETURNS VOID AS $$
  INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
  VALUES (auth.uid(), p_token, p_platform, NOW())
  ON CONFLICT (token) DO UPDATE
    SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW();
$$ LANGUAGE sql SECURITY DEFINER;

-- ---- 0b. Push dispatch URL, stored in app_settings (v32 table) ----
-- ALTER DATABASE SET is no longer permitted on Supabase, so the URL/secret
-- live in the same app_settings table the Gemini key uses. Seeded here with
-- the real project URL; ON CONFLICT keeps any value already present.
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

INSERT INTO app_settings (key, value) VALUES
  ('push_functions_url', 'https://rjszawkqtnilmcbfkacr.supabase.co/functions/v1/send-push')
ON CONFLICT (key) DO NOTHING;

-- ---- 0c. Dispatch trigger function (v22, hardened) ----
-- Reads url/secret from app_settings (falling back to the old DB-level GUCs
-- for installs that had them). COALESCE keeps the Authorization header a real
-- string even when no secret is configured (send-push only enforces the
-- secret when its env var is set), and the empty-url guard makes the function
-- a no-op instead of erroring.
CREATE OR REPLACE FUNCTION trg_dispatch_push_on_notification() RETURNS TRIGGER AS $$
DECLARE
  v_url TEXT;
  v_secret TEXT;
BEGIN
  SELECT value INTO v_url FROM app_settings WHERE key = 'push_functions_url';
  v_url := COALESCE(v_url, current_setting('app.settings.functions_url', true), '');
  IF v_url = '' THEN RETURN NEW; END IF;

  SELECT value INTO v_secret FROM app_settings WHERE key = 'push_functions_secret';
  v_secret := COALESCE(v_secret, current_setting('app.settings.functions_secret', true), '');

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
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

-- ---- 0d. finance_notifications (v28, with the v33 type list built in) ----
CREATE TABLE IF NOT EXISTS finance_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  entity_id UUID REFERENCES entities(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  ref_id UUID NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_date DATE GENERATED ALWAYS AS ((created_at AT TIME ZONE 'UTC')::date) STORED
);
CREATE INDEX IF NOT EXISTS idx_finance_notifications_user
  ON finance_notifications(user_id, is_read, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_finance_notifications_dedup
  ON finance_notifications(user_id, type, ref_id, created_date);

ALTER TABLE finance_notifications DROP CONSTRAINT IF EXISTS finance_notifications_type_check;
ALTER TABLE finance_notifications ADD CONSTRAINT finance_notifications_type_check
  CHECK (type IN ('budget_overspend', 'bill_due', 'recurring_posted',
                  'weekly_digest', 'goal_milestone', 'large_expense'));

ALTER TABLE finance_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own finance notifications" ON finance_notifications;
CREATE POLICY "Users manage own finance notifications" ON finance_notifications
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS finance_notification_push_dispatch ON finance_notifications;
CREATE TRIGGER finance_notification_push_dispatch
  AFTER INSERT ON finance_notifications
  FOR EACH ROW EXECUTE FUNCTION trg_dispatch_push_on_notification();

-- ---- 0e. Columns the alert function reads (v30; no-ops when already applied) ----
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES family_members(id) ON DELETE SET NULL;
ALTER TABLE budgets ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES family_members(id) ON DELETE SET NULL;

-- ---- 0f. Budget / bill-due alert scan (v30 — latest version, verbatim) ----
CREATE OR REPLACE FUNCTION check_budget_and_bill_alerts() RETURNS VOID AS $$
DECLARE
  v_month INT := EXTRACT(MONTH FROM CURRENT_DATE)::INT;
  v_year INT := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
  v_today DATE := CURRENT_DATE;
  v_horizon DATE := CURRENT_DATE + 3;
BEGIN
  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT b.user_id, b.entity_id, 'budget_overspend', b.id,
    CASE WHEN spent >= b.amount THEN 'Budget over limit' ELSE 'Budget nearly spent' END,
    c.name || (CASE WHEN fm.name IS NOT NULL THEN ' (' || fm.name || ')' ELSE '' END) ||
      ': ' || ROUND(spent) || ' of ' || b.amount || ' spent (' ||
      ROUND((spent / NULLIF(b.amount, 0)) * 100) || '%)',
    '/budgets'
  FROM budgets b
  JOIN categories c ON c.id = b.category_id
  LEFT JOIN family_members fm ON fm.id = b.family_member_id
  CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(t.amount), 0) AS spent
    FROM transactions t
    WHERE t.user_id = b.user_id AND t.category_id = b.category_id AND t.type = 'expense'
      AND EXTRACT(MONTH FROM t.date) = b.month AND EXTRACT(YEAR FROM t.date) = b.year
      AND COALESCE(t.family_member_id, '00000000-0000-0000-0000-000000000000'::UUID)
        = COALESCE(b.family_member_id, '00000000-0000-0000-0000-000000000000'::UUID)
  ) spend
  WHERE b.month = v_month AND b.year = v_year
    AND b.amount > 0 AND spend.spent / b.amount >= 0.8
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'budget_overspend' AND n.ref_id = b.id AND n.created_date = v_today
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;

  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT r.user_id, r.entity_id, 'bill_due', r.id, 'Upcoming: ' || r.title,
    (CASE WHEN r.next_run_date < v_today THEN 'Overdue · ' ELSE '' END) ||
      r.amount || ' due ' || r.next_run_date,
    '/recurring'
  FROM recurring_transactions r
  WHERE r.is_active AND r.next_run_date <= v_horizon
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'bill_due' AND n.ref_id = r.id AND n.created_date = v_today
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;

  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT s.user_id, s.entity_id, 'bill_due', s.id, 'Upcoming: ' || s.title,
    (CASE WHEN s.next_run_date < v_today THEN 'Overdue · ' ELSE '' END) ||
      s.amount || ' due ' || s.next_run_date,
    '/savings'
  FROM recurring_savings s
  WHERE s.is_active AND s.next_run_date <= v_horizon
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'bill_due' AND n.ref_id = s.id AND n.created_date = v_today
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;

  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT l.user_id, l.entity_id, 'bill_due', l.id, 'Upcoming: ' || l.name,
    (CASE WHEN l.due_date < v_today THEN 'Overdue · ' ELSE '' END) ||
      l.remaining_balance || ' due ' || l.due_date,
    '/liabilities'
  FROM liabilities l
  WHERE l.due_date IS NOT NULL AND l.due_date <= v_horizon AND l.remaining_balance > 0
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'bill_due' AND n.ref_id = l.id AND n.created_date = v_today
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 1. Server-side recurring auto-run
-- ============================================================
-- Loops every (user, entity) with due items and reuses the existing per-user
-- RPCs (v7 / v13), so posting logic stays in exactly one place.

CREATE OR REPLACE FUNCTION run_all_due_recurring() RETURNS VOID AS $$
DECLARE
  p RECORD;
  v_n INT;
BEGIN
  FOR p IN
    SELECT DISTINCT user_id, entity_id FROM recurring_transactions
    WHERE is_active AND next_run_date <= CURRENT_DATE
  LOOP
    v_n := run_due_recurring(p.user_id, p.entity_id);
    IF v_n > 0 THEN
      INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
      VALUES (p.user_id, p.entity_id, 'recurring_posted', p.entity_id,
        'Recurring posted automatically',
        v_n || ' due recurring transaction' || CASE WHEN v_n > 1 THEN 's were' ELSE ' was' END ||
          ' posted and account balances updated.',
        '/recurring')
      ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
    END IF;
  END LOOP;

  FOR p IN
    SELECT DISTINCT user_id, entity_id FROM recurring_savings
    WHERE is_active AND next_run_date <= CURRENT_DATE
  LOOP
    PERFORM run_due_recurring_savings(p.user_id, p.entity_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. Goal milestones + unusual expenses + daily wrapper
-- ============================================================

-- One alert per goal per milestone, ever (dedup by exact title on that goal).
CREATE OR REPLACE FUNCTION check_goal_milestones() RETURNS VOID AS $$
  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT g.user_id, g.entity_id, 'goal_milestone', g.id,
    'Goal reached ' || ms.pct || '%',
    g.title || ': ' || ROUND(g.saved_amount) || ' of ' || ROUND(g.target_amount) || ' saved' ||
      CASE WHEN ms.pct = 100 THEN ' — congratulations! 🎉' ELSE '' END,
    '/goals'
  FROM goals g
  CROSS JOIN (VALUES (50), (75), (100)) AS ms(pct)
  WHERE g.target_amount > 0
    AND g.saved_amount / g.target_amount * 100 >= ms.pct
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'goal_milestone' AND n.ref_id = g.id
        AND n.title = 'Goal reached ' || ms.pct || '%'
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
$$ LANGUAGE sql SECURITY DEFINER;

-- Yesterday's expenses that are 3×+ the category's 90-day average (needs at
-- least 5 earlier transactions in the category so a new category isn't noisy,
-- and a 500 floor so trivial amounts never alert).
CREATE OR REPLACE FUNCTION check_large_expenses() RETURNS VOID AS $$
  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT t.user_id, t.entity_id, 'large_expense', t.id,
    'Unusual expense: ' || c.name,
    ROUND(t.amount) || ' is about ' || ROUND(t.amount / stats.avg_amount, 1) ||
      '× your usual ' || c.name || ' spend (avg ' || ROUND(stats.avg_amount) || ').',
    '/transactions'
  FROM transactions t
  JOIN categories c ON c.id = t.category_id
  CROSS JOIN LATERAL (
    SELECT AVG(p.amount) AS avg_amount, COUNT(*) AS n
    FROM transactions p
    WHERE p.user_id = t.user_id AND p.category_id = t.category_id
      AND p.type = 'expense' AND p.id <> t.id
      AND p.date >= CURRENT_DATE - 90 AND p.date < t.date
  ) stats
  WHERE t.type = 'expense' AND t.date = CURRENT_DATE - 1
    AND t.amount >= 500
    AND stats.n >= 5 AND stats.avg_amount > 0
    AND t.amount >= 3 * stats.avg_amount
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
$$ LANGUAGE sql SECURITY DEFINER;

-- Daily wrapper so one cron job covers all finance checks.
CREATE OR REPLACE FUNCTION finance_daily_alerts() RETURNS VOID AS $$
BEGIN
  PERFORM check_budget_and_bill_alerts();
  PERFORM check_goal_milestones();
  PERFORM check_large_expenses();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. Weekly digest (Saturday morning)
-- ============================================================

CREATE OR REPLACE FUNCTION finance_weekly_digest() RETURNS VOID AS $$
  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT w.user_id, w.entity_id, 'weekly_digest', w.entity_id,
    'Weekly summary',
    'Last 7 days: spent ' || ROUND(w.expense) || ' across ' || w.tx_count || ' expenses' ||
      CASE WHEN w.income > 0 THEN ', earned ' || ROUND(w.income) ELSE '' END ||
      COALESCE('. Top: ' || top.name || ' (' || ROUND(top.total) || ')', '') || '.',
    '/reports'
  FROM (
    SELECT user_id, entity_id,
      COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS expense,
      COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS income,
      COUNT(*) FILTER (WHERE type = 'expense') AS tx_count
    FROM transactions
    -- entity_id guard: pre-v5 rows may have NULL entity_id, and ref_id is NOT NULL
    WHERE date >= CURRENT_DATE - 6 AND entity_id IS NOT NULL
    GROUP BY user_id, entity_id
  ) w
  LEFT JOIN LATERAL (
    SELECT c.name, SUM(t.amount) AS total
    FROM transactions t JOIN categories c ON c.id = t.category_id
    WHERE t.user_id = w.user_id AND t.entity_id = w.entity_id
      AND t.type = 'expense' AND t.date >= CURRENT_DATE - 6
    GROUP BY c.name ORDER BY SUM(t.amount) DESC LIMIT 1
  ) top ON TRUE
  WHERE w.expense > 0
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- 4. Meal evening reminders (8pm Dhaka = 14:00 UTC)
-- ============================================================

CREATE OR REPLACE FUNCTION meal_evening_reminders() RETURNS VOID AS $$
DECLARE
  v_tomorrow DATE := CURRENT_DATE + 1;
BEGIN
  -- a) No meal entry for tomorrow yet. Only for groups with recent activity
  --    (an entry in the last 10 days) so dormant groups never get nagged.
  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  SELECT m.group_id, m.user_id, 'entry_reminder',
    'Meal entry reminder',
    'No meals set for tomorrow (' || to_char(v_tomorrow, 'DD Mon') || ') in ' ||
      g.name || '. Turn tomorrow''s meals on or off.',
    '/meals/daily'
  FROM meal_group_members m
  JOIN meal_groups g ON g.id = m.group_id
  WHERE m.status = 'approved'
    AND EXISTS (
      SELECT 1 FROM meal_entries e
      WHERE e.group_id = m.group_id AND e.date >= CURRENT_DATE - 10
    )
    AND NOT EXISTS (
      SELECT 1 FROM meal_entries e
      WHERE e.group_id = m.group_id AND e.member_id = m.id AND e.date = v_tomorrow
    )
    AND NOT EXISTS (
      SELECT 1 FROM meal_notifications n
      WHERE n.user_id = m.user_id AND n.group_id = m.group_id
        AND n.type = 'entry_reminder' AND n.created_at >= CURRENT_DATE
    );

  -- b) Duty tomorrow.
  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  SELECT a.group_id, m.user_id, 'duty_reminder',
    'Duty tomorrow: ' || dt.name,
    'You have ' || dt.name || ' duty on ' || to_char(a.date, 'DD Mon') || ' in ' || g.name ||
      COALESCE(' — ' || a.note, '') || '.',
    '/meals/duty'
  FROM meal_duty_assignments a
  JOIN meal_duty_types dt ON dt.id = a.duty_type_id
  JOIN meal_group_members m ON m.id = a.member_id
  JOIN meal_groups g ON g.id = a.group_id
  WHERE a.date = v_tomorrow AND m.status = 'approved'
    AND NOT EXISTS (
      SELECT 1 FROM meal_notifications n
      WHERE n.user_id = m.user_id AND n.group_id = a.group_id
        AND n.type = 'duty_reminder' AND n.created_at >= CURRENT_DATE
    );

  -- c) Negative running balance this month (opening + deposits − meals×rate,
  --    meal cost only — fixed shares settle at month close, so this is a
  --    conservative estimate). At most one warning per member per 7 days.
  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  SELECT b.group_id, b.user_id, 'balance_low',
    'Meal balance low',
    'Your estimated balance in ' || b.group_name || ' is ' || ROUND(b.balance) ||
      '. Please add a deposit.',
    '/meals/deposits'
  FROM (
    SELECT m.group_id, m.user_id, g.name AS group_name,
      COALESCE(op.balance, 0) + COALESCE(dep.total, 0)
        - COALESCE(ent.meals, 0) * COALESCE(rate.meal_rate, 0) AS balance
    FROM meal_group_members m
    JOIN meal_groups g ON g.id = m.group_id
    -- month running meal rate: bazar so far / weighted meals so far
    LEFT JOIN LATERAL (
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM meal_expenses x
         WHERE x.group_id = m.group_id AND x.expense_type = 'bazar'
           AND x.date >= date_trunc('month', CURRENT_DATE)::DATE)
        / NULLIF(
          (SELECT COALESCE(SUM(
              (breakfast + guest_breakfast) * g.breakfast_value
            + (lunch + guest_lunch) * g.lunch_value
            + (dinner + guest_dinner) * g.dinner_value), 0) FROM meal_entries e
           WHERE e.group_id = m.group_id
             AND e.date >= date_trunc('month', CURRENT_DATE)::DATE), 0) AS meal_rate
    ) rate ON TRUE
    LEFT JOIN LATERAL (
      SELECT SUM(
          (breakfast + guest_breakfast) * g.breakfast_value
        + (lunch + guest_lunch) * g.lunch_value
        + (dinner + guest_dinner) * g.dinner_value) AS meals
      FROM meal_entries e
      WHERE e.group_id = m.group_id AND e.member_id = m.id
        AND e.date >= date_trunc('month', CURRENT_DATE)::DATE
    ) ent ON TRUE
    LEFT JOIN LATERAL (
      SELECT SUM(amount) AS total FROM meal_deposits d
      WHERE d.group_id = m.group_id AND d.member_id = m.id
        AND d.date >= date_trunc('month', CURRENT_DATE)::DATE
    ) dep ON TRUE
    LEFT JOIN LATERAL (
      SELECT cb.balance FROM meal_month_closure_balances cb
      JOIN meal_month_closures mc ON mc.id = cb.closure_id
      WHERE cb.member_id = m.id
        AND make_date(mc.year, mc.month, 1)
          = (date_trunc('month', CURRENT_DATE) - INTERVAL '1 month')::DATE
    ) op ON TRUE
    WHERE m.status = 'approved'
      AND NOT is_meal_month_closed(m.group_id, CURRENT_DATE)
  ) b
  WHERE b.balance < 0
    AND NOT EXISTS (
      SELECT 1 FROM meal_notifications n
      WHERE n.user_id = b.user_id AND n.group_id = b.group_id
        AND n.type = 'balance_low' AND n.created_at >= CURRENT_DATE - 7
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. Month-close balance push
-- ============================================================
-- close_meal_month (v18) snapshots one balance row per member; this per-row
-- trigger turns each snapshot into that member's personal notification.
-- Purely additive — the closure RPC itself is untouched.

CREATE OR REPLACE FUNCTION trg_notify_month_closed() RETURNS TRIGGER AS $$
DECLARE
  v_user UUID;
  v_group_name TEXT;
  v_label TEXT;
BEGIN
  SELECT user_id INTO v_user FROM meal_group_members WHERE id = NEW.member_id;
  SELECT g.name, to_char(make_date(mc.year, mc.month, 1), 'Mon YYYY')
    INTO v_group_name, v_label
  FROM meal_month_closures mc JOIN meal_groups g ON g.id = mc.group_id
  WHERE mc.id = NEW.closure_id;

  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  VALUES (NEW.group_id, v_user, 'month_closed',
    v_label || ' closed — ' || v_group_name,
    CASE
      WHEN NEW.balance > 0 THEN 'Final balance: you get back ' || ROUND(NEW.balance) || '.'
      WHEN NEW.balance < 0 THEN 'Final balance: you owe ' || ROUND(ABS(NEW.balance)) || '.'
      ELSE 'Final balance: settled — nothing due.'
    END,
    '/meals/summary');
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never let a notification failure block the month-close itself.
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_month_close_notify ON meal_month_closure_balances;
CREATE TRIGGER meal_month_close_notify
  AFTER INSERT ON meal_month_closure_balances
  FOR EACH ROW EXECUTE FUNCTION trg_notify_month_closed();

-- ============================================================
-- 6. Cron schedule (pg_cron runs in UTC; Dhaka = UTC+6)
-- ============================================================

-- 6:30am Dhaka: post due recurring items BEFORE the alert scan, so freshly
-- posted bills don't also fire a stale "due" alert.
SELECT cron.unschedule('recurring-autorun-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'recurring-autorun-daily');
SELECT cron.schedule('recurring-autorun-daily', '30 0 * * *', 'SELECT run_all_due_recurring();');

-- 7:00am Dhaka: full daily alert scan.
SELECT cron.unschedule('finance-alerts-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'finance-alerts-daily');
SELECT cron.schedule('finance-alerts-daily', '0 1 * * *', 'SELECT finance_daily_alerts();');

-- Saturday 7:15am Dhaka.
SELECT cron.unschedule('finance-weekly-digest') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'finance-weekly-digest');
SELECT cron.schedule('finance-weekly-digest', '15 1 * * 6', 'SELECT finance_weekly_digest();');

-- 8:00pm Dhaka: tomorrow's entry + duty reminders, low-balance warnings.
SELECT cron.unschedule('meal-evening-reminders') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'meal-evening-reminders');
SELECT cron.schedule('meal-evening-reminders', '0 14 * * *', 'SELECT meal_evening_reminders();');
