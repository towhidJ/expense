-- v28: Budget overspend / bill-due alerts (Phase 3 of the feature-idea plan).
-- finance_notifications is the finance-side analog of meal_notifications
-- (v19) — same shape (user_id, title, body, link, is_read), so it can reuse
-- v22's push-dispatch trigger function as-is (it only reads NEW.user_id /
-- title / body / link, nothing meal-specific).
-- check_budget_and_bill_alerts() is a server-side version of the spent-vs-
-- limit calc that lives in src/hooks/useBudgetSpend.js on the client, plus a
-- "due within 3 days" check on recurring transactions/savings/liabilities —
-- scheduled daily via pg_cron so it also covers users who don't open the app.
-- Run this in the Supabase SQL Editor (after v27).

CREATE TABLE IF NOT EXISTS finance_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  entity_id UUID REFERENCES entities(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('budget_overspend', 'bill_due')),
  ref_id UUID NOT NULL, -- budgets.id, recurring_transactions.id, recurring_savings.id or liabilities.id
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  -- created_at::date isn't usable in an index — it depends on the session's
  -- TimeZone setting, so Postgres won't call it IMMUTABLE. AT TIME ZONE
  -- 'UTC' with a fixed literal zone is deterministic, so a generated column
  -- off that works and gives ON CONFLICT a plain column to target.
  created_date DATE GENERATED ALWAYS AS ((created_at AT TIME ZONE 'UTC')::date) STORED
);
CREATE INDEX IF NOT EXISTS idx_finance_notifications_user
  ON finance_notifications(user_id, is_read, created_at);
-- One alert per ref per day, so re-running the daily check doesn't spam.
CREATE UNIQUE INDEX IF NOT EXISTS idx_finance_notifications_dedup
  ON finance_notifications(user_id, type, ref_id, created_date);

ALTER TABLE finance_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own finance notifications" ON finance_notifications;
CREATE POLICY "Users manage own finance notifications" ON finance_notifications
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS finance_notification_push_dispatch ON finance_notifications;
CREATE TRIGGER finance_notification_push_dispatch
  AFTER INSERT ON finance_notifications
  FOR EACH ROW EXECUTE FUNCTION trg_dispatch_push_on_notification();

-- Scans every user's budgets/recurring items/liabilities and inserts an
-- alert where one doesn't already exist for today. SECURITY DEFINER + no
-- auth.uid() filtering, since this runs as a scheduled job with no signed-in
-- user — it iterates across all users by design.
CREATE OR REPLACE FUNCTION check_budget_and_bill_alerts() RETURNS VOID AS $$
DECLARE
  v_month INT := EXTRACT(MONTH FROM CURRENT_DATE)::INT;
  v_year INT := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
  v_today DATE := CURRENT_DATE;
  v_horizon DATE := CURRENT_DATE + 3;
BEGIN
  -- Budgets at/over 80% spent, this month only (matches useBudgetSpend.js)
  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT b.user_id, b.entity_id, 'budget_overspend', b.id,
    CASE WHEN spent >= b.amount THEN 'Budget over limit' ELSE 'Budget nearly spent' END,
    c.name || ': ' || ROUND(spent) || ' of ' || b.amount || ' spent (' ||
      ROUND((spent / NULLIF(b.amount, 0)) * 100) || '%)',
    '/budgets'
  FROM budgets b
  JOIN categories c ON c.id = b.category_id
  CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(t.amount), 0) AS spent
    FROM transactions t
    WHERE t.user_id = b.user_id AND t.category_id = b.category_id AND t.type = 'expense'
      AND EXTRACT(MONTH FROM t.date) = b.month AND EXTRACT(YEAR FROM t.date) = b.year
  ) spend
  WHERE b.month = v_month AND b.year = v_year
    AND b.amount > 0 AND spend.spent / b.amount >= 0.8
    AND NOT EXISTS (
      SELECT 1 FROM finance_notifications n
      WHERE n.type = 'budget_overspend' AND n.ref_id = b.id AND n.created_date = v_today
    )
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;

  -- Recurring transactions due within 3 days
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

  -- Recurring savings installments due within 3 days
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

  -- Liabilities due within 3 days (still outstanding)
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

CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.unschedule('finance-alerts-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'finance-alerts-daily'
);
SELECT cron.schedule('finance-alerts-daily', '0 7 * * *', 'SELECT check_budget_and_bill_alerts();');
