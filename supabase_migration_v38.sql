-- ============================================================
-- Migration v38 — Rent management expansion
--
--  1. Partial payments: a month can now hold several rent_payments rows
--     (UNIQUE(unit_id, rent_month) dropped). `amount` stays the TOTAL
--     received; optional charge_amount/charge_note itemize service or
--     utility charges inside that total (for receipts).
--  2. rent_revisions: rent-increase history. Expected rent for a month =
--     the latest revision effective on or before it (fallback:
--     rental_units.monthly_rent). Seeded from existing units.
--  3. unit_tenancies: archive of past tenants incl. advance settlement
--     (dues deducted from the advance, amount returned).
--  4. rent_unit_expenses: repairs/maintenance per unit (optionally linked
--     to a real expense transaction) for per-unit net income.
--  5. 'rent_due' notifications on the 5th/10th/20th for units with an
--     outstanding balance this month, wired into finance_daily_alerts().
-- Run this whole file in the Supabase SQL Editor (after v35).
-- ============================================================

-- ---- 1. Partial payments + charge itemization ----
ALTER TABLE rent_payments DROP CONSTRAINT IF EXISTS rent_payments_unit_id_rent_month_key;
CREATE INDEX IF NOT EXISTS idx_rent_payments_unit_month ON rent_payments(unit_id, rent_month);
ALTER TABLE rent_payments ADD COLUMN IF NOT EXISTS charge_amount NUMERIC DEFAULT 0;
ALTER TABLE rent_payments ADD COLUMN IF NOT EXISTS charge_note TEXT;

-- ---- 2. Rent revision history ----
CREATE TABLE IF NOT EXISTS rent_revisions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  unit_id UUID REFERENCES rental_units(id) ON DELETE CASCADE NOT NULL,
  effective_from DATE NOT NULL, -- normalized to the 1st of a month by the UI
  monthly_rent NUMERIC NOT NULL CHECK (monthly_rent >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (unit_id, effective_from)
);
ALTER TABLE rent_revisions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own rent revisions" ON rent_revisions;
CREATE POLICY "Users manage own rent revisions" ON rent_revisions FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_rent_revisions_unit ON rent_revisions(unit_id, effective_from DESC);

-- Seed: one baseline revision per existing unit so history starts somewhere.
INSERT INTO rent_revisions (user_id, entity_id, unit_id, effective_from, monthly_rent)
SELECT u.user_id, u.entity_id, u.id,
       date_trunc('month', COALESCE(u.rent_start, u.created_at::DATE))::DATE, u.monthly_rent
FROM rental_units u
ON CONFLICT (unit_id, effective_from) DO NOTHING;

-- ---- 3. Tenant history + advance settlement ----
CREATE TABLE IF NOT EXISTS unit_tenancies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  unit_id UUID REFERENCES rental_units(id) ON DELETE CASCADE NOT NULL,
  tenant_name TEXT NOT NULL,
  tenant_phone TEXT,
  start_date DATE,
  end_date DATE NOT NULL,
  monthly_rent NUMERIC DEFAULT 0,       -- rent at the time of leaving
  advance_deposit NUMERIC DEFAULT 0,    -- advance held when tenancy ended
  dues_deducted NUMERIC DEFAULT 0,      -- unpaid rent kept from the advance
  advance_returned NUMERIC DEFAULT 0,   -- cash actually handed back
  refund_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE unit_tenancies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own tenancies" ON unit_tenancies;
CREATE POLICY "Users manage own tenancies" ON unit_tenancies FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_unit_tenancies_unit ON unit_tenancies(unit_id, end_date DESC);

-- ---- 4. Per-unit expenses (repairs, paint, motor…) ----
CREATE TABLE IF NOT EXISTS rent_unit_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  unit_id UUID REFERENCES rental_units(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  description TEXT,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE rent_unit_expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own unit expenses" ON rent_unit_expenses;
CREATE POLICY "Users manage own unit expenses" ON rent_unit_expenses FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_rent_unit_expenses_unit ON rent_unit_expenses(unit_id, date DESC);

-- ---- 5. Rent-due reminders ----
ALTER TABLE finance_notifications DROP CONSTRAINT IF EXISTS finance_notifications_type_check;
ALTER TABLE finance_notifications ADD CONSTRAINT finance_notifications_type_check
  CHECK (type IN ('budget_overspend', 'bill_due', 'recurring_posted',
                  'weekly_digest', 'goal_milestone', 'large_expense', 'rent_due'));

-- On the 5th, 10th and 20th: one reminder per active unit whose expected rent
-- (latest revision <= this month, else the unit's base rent) is not fully
-- collected. The daily-dedup index prevents duplicates within a day.
CREATE OR REPLACE FUNCTION check_rent_due() RETURNS VOID AS $$
DECLARE
  v_month DATE := date_trunc('month', CURRENT_DATE)::DATE;
BEGIN
  IF EXTRACT(DAY FROM CURRENT_DATE)::INT NOT IN (5, 10, 20) THEN
    RETURN;
  END IF;

  INSERT INTO finance_notifications (user_id, entity_id, type, ref_id, title, body, link)
  SELECT u.user_id, u.entity_id, 'rent_due', u.id,
    'Rent due: ' || u.name,
    COALESCE(u.tenant_name || ' — ', '') || 'Tk ' || ROUND(exp.rent - pay.paid) ||
      CASE WHEN pay.paid > 0 THEN ' still due (' || ROUND(pay.paid) || ' received)' ELSE ' due' END ||
      ' for ' || to_char(v_month, 'Mon YYYY') || '.',
    '/rent'
  FROM rental_units u
  CROSS JOIN LATERAL (
    SELECT COALESCE(
      (SELECT r.monthly_rent FROM rent_revisions r
       WHERE r.unit_id = u.id AND r.effective_from <= v_month
       ORDER BY r.effective_from DESC LIMIT 1),
      u.monthly_rent) AS rent
  ) exp
  CROSS JOIN LATERAL (
    SELECT COALESCE(SUM(p.amount), 0) AS paid
    FROM rent_payments p WHERE p.unit_id = u.id AND p.rent_month = v_month
  ) pay
  WHERE u.is_active AND exp.rent > 0 AND pay.paid < exp.rent
  ON CONFLICT (user_id, type, ref_id, created_date) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-wrap the daily alert runner so the existing 7:00am Dhaka cron picks
-- rent checks up too (no new cron job needed).
CREATE OR REPLACE FUNCTION finance_daily_alerts() RETURNS VOID AS $$
BEGIN
  PERFORM check_budget_and_bill_alerts();
  PERFORM check_goal_milestones();
  PERFORM check_large_expenses();
  PERFORM check_rent_due();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
