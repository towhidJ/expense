-- v17: Meal module additions + itemized bazar lists.
--   * meal_advances (জামানত): a returnable security advance taken from a member
--     when they join. type 'taken' (member gives money), 'returned' (mess gives
--     it back when they leave), 'adjusted' (advance used to pay the member's
--     bokeya — adjust_meal_advance RPC also inserts a meal_deposits row so the
--     month summary sees the payment). Advance balance is lifetime, not
--     monthly: taken - returned - adjusted. Manager-only writes, like deposits.
--   * meal_holidays: mark a date as a meal holiday, optionally with a special
--     food / nasta plan (title + menu). Shown as a banner on the daily meal
--     entry screens. Cost of the special food is recorded as a meal expense of
--     the new type 'feast' — it lands in the fixed-cost pot automatically
--     (the summary treats every non-bazar type as fixed).
--   * Itemized lists: meal_expenses.items and bazar_purchases.items JSONB
--     arrays of {name, amount} so "ki ki kinlam" is a proper list, not a note.
--     process_bazar_purchase gets a defaulted p_items param (old clients keep
--     working).
--   * Meal receipts: meal_expenses.attachment_url/_path — one receipt photo
--     per expense, stored in the existing public `documents` bucket under
--     meal/{group_id}/... so every member can view it.
--   * get_meal_month_summary re-created: per-member lifetime `advance` and
--     top-level `total_advance`.
-- Run this in the Supabase SQL Editor (after v16).

-- ---------- 1. Member advances (জামানত) ----------

CREATE TABLE IF NOT EXISTS meal_advances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  type TEXT NOT NULL DEFAULT 'taken' CHECK (type IN ('taken', 'returned', 'adjusted')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL,
  note TEXT,
  added_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_meal_advances_group ON meal_advances(group_id, member_id);

ALTER TABLE meal_advances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal advances" ON meal_advances;
CREATE POLICY "Members can view meal advances" ON meal_advances
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can add meal advances" ON meal_advances;
CREATE POLICY "Managers can add meal advances" ON meal_advances
  FOR INSERT WITH CHECK (is_meal_group_manager(group_id) AND added_by = auth.uid());
DROP POLICY IF EXISTS "Managers can update meal advances" ON meal_advances;
CREATE POLICY "Managers can update meal advances" ON meal_advances
  FOR UPDATE USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));
DROP POLICY IF EXISTS "Managers can delete meal advances" ON meal_advances;
CREATE POLICY "Managers can delete meal advances" ON meal_advances
  FOR DELETE USING (is_meal_group_manager(group_id));

-- Advance balance of one member (lifetime): taken - returned - adjusted
CREATE OR REPLACE FUNCTION meal_advance_balance(p_member_id UUID) RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(CASE WHEN type = 'taken' THEN amount ELSE -amount END), 0)
  FROM meal_advances WHERE member_id = p_member_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Use part of a member's advance to pay their bokeya: one 'adjusted' advance
-- row + one deposit row, atomically, so their meal balance goes up while the
-- advance goes down.
CREATE OR REPLACE FUNCTION adjust_meal_advance(
  p_member_id UUID,
  p_amount NUMERIC,
  p_date DATE,
  p_note TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  v_member RECORD;
  v_balance NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  SELECT * INTO v_member FROM meal_group_members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF NOT is_meal_group_manager(v_member.group_id) THEN
    RAISE EXCEPTION 'Only a manager can adjust advances';
  END IF;

  v_balance := meal_advance_balance(p_member_id);
  IF p_amount > v_balance THEN
    RAISE EXCEPTION 'Adjustment (%) exceeds the advance balance (%)', p_amount, v_balance;
  END IF;

  INSERT INTO meal_advances (group_id, member_id, type, amount, date, note, added_by)
  VALUES (v_member.group_id, p_member_id, 'adjusted', p_amount, p_date,
          COALESCE(p_note, 'Adjusted against dues'), auth.uid());

  INSERT INTO meal_deposits (group_id, member_id, amount, date, note, added_by)
  VALUES (v_member.group_id, p_member_id, p_amount, p_date,
          COALESCE(p_note, 'Paid from advance (জামানত)'), auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 2. Meal holidays / special food (feast) ----------

CREATE TABLE IF NOT EXISTS meal_holidays (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  title TEXT NOT NULL DEFAULT 'Meal Holiday',
  menu TEXT, -- special khabar / nasta plan for the day
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, date)
);

ALTER TABLE meal_holidays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal holidays" ON meal_holidays;
CREATE POLICY "Members can view meal holidays" ON meal_holidays
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can manage meal holidays" ON meal_holidays;
CREATE POLICY "Managers can manage meal holidays" ON meal_holidays
  FOR ALL USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));

-- Feast (special food) is a new expense type; every non-bazar type is split
-- as a fixed cost by the summary, so no math changes needed.
ALTER TABLE meal_expenses DROP CONSTRAINT IF EXISTS meal_expenses_expense_type_check;
ALTER TABLE meal_expenses ADD CONSTRAINT meal_expenses_expense_type_check
  CHECK (expense_type IN ('bazar', 'utility', 'maid', 'feast', 'other'));

-- ---------- 3. Itemized lists + receipt attachment ----------

ALTER TABLE meal_expenses ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]';
ALTER TABLE meal_expenses ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE meal_expenses ADD COLUMN IF NOT EXISTS attachment_path TEXT;

ALTER TABLE bazar_purchases ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]';

-- Re-create process_bazar_purchase with a defaulted p_items param.
-- (Same body as v14 otherwise; old clients that don't send p_items still work.)
CREATE OR REPLACE FUNCTION process_bazar_purchase(
  p_user_id UUID,
  p_entity_id UUID,
  p_category_id UUID,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT,
  p_payment_type TEXT,
  p_account_id UUID DEFAULT NULL,
  p_liability_id UUID DEFAULT NULL,
  p_items JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_txn_id UUID;
  v_purchase_id UUID;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Purchase amount must be positive';
  END IF;

  IF p_payment_type = 'cash' THEN
    IF p_account_id IS NULL THEN
      RAISE EXCEPTION 'Cash purchase requires an account';
    END IF;
    UPDATE accounts SET current_balance = current_balance - p_amount
    WHERE id = p_account_id AND user_id = p_user_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Account not found';
    END IF;

    INSERT INTO transactions (user_id, entity_id, account_id, category_id, type, amount, date, description)
    VALUES (p_user_id, p_entity_id, p_account_id, p_category_id, 'expense', p_amount, p_date, p_description)
    RETURNING id INTO v_txn_id;

  ELSIF p_payment_type = 'due' THEN
    IF p_liability_id IS NULL THEN
      RAISE EXCEPTION 'Due purchase requires a shop';
    END IF;
    UPDATE liabilities SET
      principal = principal + p_amount,
      remaining_balance = remaining_balance + p_amount
    WHERE id = p_liability_id AND user_id = p_user_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Shop not found';
    END IF;

    -- No account: money has not left yet. Expense is still recognized now.
    INSERT INTO transactions (user_id, entity_id, account_id, category_id, liability_id, type, amount, date, description)
    VALUES (p_user_id, p_entity_id, NULL, p_category_id, p_liability_id, 'expense', p_amount, p_date, p_description)
    RETURNING id INTO v_txn_id;

  ELSE
    RAISE EXCEPTION 'Invalid payment type: %', p_payment_type;
  END IF;

  INSERT INTO bazar_purchases (user_id, entity_id, liability_id, account_id, transaction_id, payment_type, amount, date, description, items)
  VALUES (p_user_id, p_entity_id,
          CASE WHEN p_payment_type = 'due' THEN p_liability_id END,
          CASE WHEN p_payment_type = 'cash' THEN p_account_id END,
          v_txn_id, p_payment_type, p_amount, p_date, p_description,
          COALESCE(p_items, '[]'::jsonb))
  RETURNING id INTO v_purchase_id;

  RETURN v_purchase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 4. Storage for meal receipts ----------
-- The web app already stores transaction invoices in the public `documents`
-- bucket. Meal receipts go in the same bucket under meal/{group_id}/... —
-- these policies make sure the bucket exists and signed-in users can upload.

INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

DROP POLICY IF EXISTS "Public read documents" ON storage.objects;
CREATE POLICY "Public read documents" ON storage.objects
  FOR SELECT USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "Authenticated upload documents" ON storage.objects;
CREATE POLICY "Authenticated upload documents" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'documents');

DROP POLICY IF EXISTS "Authenticated delete own documents" ON storage.objects;
CREATE POLICY "Authenticated delete own documents" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'documents' AND owner = auth.uid());

-- ---------- 5. Month summary with advance balances ----------

CREATE OR REPLACE FUNCTION get_meal_month_summary(
  p_group_id UUID,
  p_year INT,
  p_month INT
) RETURNS JSONB AS $$
DECLARE
  v_group RECORD;
  v_start DATE;
  v_end DATE;
  v_total_meals NUMERIC := 0;
  v_total_deposits NUMERIC := 0;
  v_total_bazar NUMERIC := 0;
  v_total_fixed NUMERIC := 0;
  v_total_advance NUMERIC := 0;
  v_meal_rate NUMERIC := 0;
  v_eligible INT := 0;
  v_approved INT := 0;
  v_members JSONB;
BEGIN
  IF NOT is_meal_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;
  IF p_month < 1 OR p_month > 12 THEN
    RAISE EXCEPTION 'Invalid month: %', p_month;
  END IF;

  SELECT * INTO v_group FROM meal_groups WHERE id = p_group_id;
  v_start := make_date(p_year, p_month, 1);
  v_end := (v_start + INTERVAL '1 month')::DATE;

  SELECT
    COALESCE(SUM(amount) FILTER (WHERE expense_type = 'bazar'), 0),
    COALESCE(SUM(amount) FILTER (WHERE expense_type <> 'bazar'), 0)
  INTO v_total_bazar, v_total_fixed
  FROM meal_expenses
  WHERE group_id = p_group_id AND date >= v_start AND date < v_end;

  SELECT COALESCE(SUM(
      (breakfast + guest_breakfast) * v_group.breakfast_value
    + (lunch + guest_lunch) * v_group.lunch_value
    + (dinner + guest_dinner) * v_group.dinner_value), 0)
  INTO v_total_meals
  FROM meal_entries
  WHERE group_id = p_group_id AND date >= v_start AND date < v_end;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_deposits
  FROM meal_deposits
  WHERE group_id = p_group_id AND date >= v_start AND date < v_end;

  -- Advance (জামানত) held by the mess is lifetime, not month-scoped
  SELECT COALESCE(SUM(CASE WHEN a.type = 'taken' THEN a.amount ELSE -a.amount END), 0)
  INTO v_total_advance
  FROM meal_advances a
  WHERE a.group_id = p_group_id;

  v_meal_rate := COALESCE(v_total_bazar / NULLIF(v_total_meals, 0), 0);

  SELECT COUNT(*) INTO v_approved FROM meal_group_members
  WHERE group_id = p_group_id AND status = 'approved';

  SELECT COUNT(*) INTO v_eligible FROM meal_group_members mm
  WHERE mm.group_id = p_group_id AND (
    EXISTS (
      SELECT 1 FROM meal_entries e
      WHERE e.member_id = mm.id AND e.date >= v_start AND e.date < v_end
        AND (e.breakfast + e.lunch + e.dinner
           + e.guest_breakfast + e.guest_lunch + e.guest_dinner) > 0
    )
    OR EXISTS (
      SELECT 1 FROM meal_deposits d
      WHERE d.member_id = mm.id AND d.date >= v_start AND d.date < v_end
    )
  );

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'member_id', x.member_id,
      'user_id', x.user_id,
      'display_name', x.display_name,
      'status', x.status,
      'role', x.role,
      'meals', x.meals,
      'deposits', x.deposits,
      'advance', x.advance,
      'meal_cost', x.meal_cost,
      'fixed_share', x.fixed_share,
      'total_cost', ROUND(x.meal_cost + x.fixed_share, 2),
      'balance', ROUND(x.deposits - x.meal_cost - x.fixed_share, 2)
    ) ORDER BY x.display_name), '[]'::jsonb)
  INTO v_members
  FROM (
    SELECT mm.id AS member_id, mm.user_id, mm.display_name, mm.status, mm.role,
      COALESCE(ent.meals, 0) AS meals,
      COALESCE(dep.deposits, 0) AS deposits,
      COALESCE(adv.advance, 0) AS advance,
      ROUND(COALESCE(ent.meals, 0) * v_meal_rate, 2) AS meal_cost,
      CASE
        WHEN v_eligible > 0
          AND (COALESCE(ent.meals, 0) > 0 OR COALESCE(dep.deposits, 0) > 0)
          THEN ROUND(v_total_fixed / v_eligible, 2)
        WHEN v_eligible = 0 AND mm.status = 'approved' AND v_approved > 0
          THEN ROUND(v_total_fixed / v_approved, 2)
        ELSE 0
      END AS fixed_share
    FROM meal_group_members mm
    LEFT JOIN (
      SELECT member_id, SUM(
          (breakfast + guest_breakfast) * v_group.breakfast_value
        + (lunch + guest_lunch) * v_group.lunch_value
        + (dinner + guest_dinner) * v_group.dinner_value) AS meals
      FROM meal_entries
      WHERE group_id = p_group_id AND date >= v_start AND date < v_end
      GROUP BY member_id
    ) ent ON ent.member_id = mm.id
    LEFT JOIN (
      SELECT member_id, SUM(amount) AS deposits
      FROM meal_deposits
      WHERE group_id = p_group_id AND date >= v_start AND date < v_end
      GROUP BY member_id
    ) dep ON dep.member_id = mm.id
    LEFT JOIN (
      SELECT member_id,
             SUM(CASE WHEN type = 'taken' THEN amount ELSE -amount END) AS advance
      FROM meal_advances
      WHERE group_id = p_group_id
      GROUP BY member_id
    ) adv ON adv.member_id = mm.id
    WHERE mm.group_id = p_group_id
      AND (mm.status = 'approved'
        OR COALESCE(ent.meals, 0) > 0
        OR COALESCE(dep.deposits, 0) > 0
        OR COALESCE(adv.advance, 0) <> 0)
  ) x;

  RETURN jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'total_meals', v_total_meals,
    'total_bazar', v_total_bazar,
    'total_fixed', v_total_fixed,
    'total_deposits', v_total_deposits,
    'total_advance', v_total_advance,
    'meal_rate', ROUND(v_meal_rate, 2),
    'members', v_members
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
