-- v30: Per-member spending limits for Family workspaces (Phase 4 of the
-- feature-idea plan). Highest-risk item in the plan — the only change that
-- touches the core transactions table. Nullable everywhere, so existing
-- rows/clients are unaffected (family_member_id = NULL means "household",
-- the same as today).
-- Run this in the Supabase SQL Editor (after v29).

ALTER TABLE transactions ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES family_members(id) ON DELETE SET NULL;
ALTER TABLE budgets ADD COLUMN IF NOT EXISTS family_member_id UUID REFERENCES family_members(id) ON DELETE SET NULL;

-- Relax budgets' unique constraint so a household budget (member NULL) and a
-- per-member budget can coexist for the same category/month — a plain
-- UNIQUE(..., family_member_id) wouldn't do this, since SQL NULLs are never
-- equal to each other and would let duplicate NULL-member rows through.
ALTER TABLE budgets DROP CONSTRAINT IF EXISTS budgets_user_id_category_id_month_year_key;
CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_unique_scope
  ON budgets (user_id, category_id, month, year, COALESCE(family_member_id, '00000000-0000-0000-0000-000000000000'::UUID));

-- Re-create with a trailing DEFAULT NULL param — old callers (mobile, until
-- it's updated) keep working unchanged and get family_member_id = NULL,
-- same backward-compatible pattern as process_bazar_purchase's p_liability_id (v14).
CREATE OR REPLACE FUNCTION process_transaction(
  p_user_id UUID,
  p_entity_id UUID,
  p_account_id UUID,
  p_category_id UUID,
  p_asset_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT,
  p_family_member_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_transaction_id UUID;
BEGIN
  IF p_type = 'income' THEN
    UPDATE accounts SET current_balance = current_balance + p_amount
    WHERE id = p_account_id AND user_id = p_user_id;
  ELSIF p_type = 'expense' THEN
    UPDATE accounts SET current_balance = current_balance - p_amount
    WHERE id = p_account_id AND user_id = p_user_id;
  END IF;

  INSERT INTO transactions (user_id, entity_id, account_id, category_id, asset_id, type, amount, date, description, family_member_id)
  VALUES (p_user_id, p_entity_id, p_account_id, p_category_id, p_asset_id, p_type, p_amount, p_date, p_description, p_family_member_id)
  RETURNING id INTO v_transaction_id;

  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_transaction_with_balance(
  p_user_id UUID,
  p_transaction_id UUID,
  p_account_id UUID,
  p_category_id UUID,
  p_asset_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT,
  p_family_member_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_old RECORD;
BEGIN
  SELECT * INTO v_old FROM transactions
  WHERE id = p_transaction_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  IF v_old.account_id IS NOT NULL THEN
    IF v_old.type = 'income' THEN
      UPDATE accounts SET current_balance = current_balance - v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    ELSIF v_old.type = 'expense' THEN
      UPDATE accounts SET current_balance = current_balance + v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    END IF;
  END IF;

  IF p_account_id IS NOT NULL THEN
    IF p_type = 'income' THEN
      UPDATE accounts SET current_balance = current_balance + p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    ELSIF p_type = 'expense' THEN
      UPDATE accounts SET current_balance = current_balance - p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    END IF;
  END IF;

  IF v_old.liability_id IS NOT NULL AND p_amount <> v_old.amount THEN
    UPDATE liabilities SET
      principal = GREATEST(principal + (p_amount - v_old.amount), 0),
      remaining_balance = GREATEST(remaining_balance + (p_amount - v_old.amount), 0)
    WHERE id = v_old.liability_id AND user_id = p_user_id;
  END IF;

  UPDATE bazar_purchases SET amount = p_amount, date = p_date, description = p_description
  WHERE transaction_id = p_transaction_id AND user_id = p_user_id;

  UPDATE transactions SET
    account_id = p_account_id,
    category_id = p_category_id,
    asset_id = p_asset_id,
    type = p_type,
    amount = p_amount,
    date = p_date,
    description = p_description,
    family_member_id = p_family_member_id
  WHERE id = p_transaction_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Patch v28's budget-alert query to match useBudgetSpend.js's per-member
-- scoping: a member-scoped budget only counts that member's spend, a
-- household budget (member_id NULL) only counts unattributed spend. Only
-- the budget_overspend block changes; bill_due is untouched — re-paste that
-- part of the function body as-is.
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
