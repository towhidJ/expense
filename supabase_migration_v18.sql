-- v18: Three new meal modules — month close + carry-forward, meal off/guest
-- requests with a cutoff time, and a notice board.
--   * Month close (meal_month_closures + _balances): the manager closes a month
--     from the Summary page. Closing snapshots every member's balance
--     (deposits − costs + carry) into meal_month_closure_balances; the next
--     month's get_meal_month_summary reads that snapshot as each member's
--     opening_balance, so bokeya/joma carries forward automatically. Months
--     must be closed in order (you cannot close March while February with
--     activity is still open) and reopened newest-first, so the carry chain
--     never has holes. A closed month is read-only: meal entries, deposits and
--     expenses in it are blocked at the DB level (RLS + RPC checks), and the
--     manager can reopen if a correction is needed.
--   * Meal requests (meal_requests): a member requests "meal off" or "guest
--     meal" for a date themselves instead of telling the manager. The group
--     can set a cutoff_time (e.g. 21:00 = requests for tomorrow must be in by
--     9pm today, Asia/Dhaka); past-cutoff submissions are rejected by the RPC.
--     Manager approves/rejects; approving writes the meal entry (off zeroes
--     the requested slots, guest adds guest counts).
--   * Notice board (meal_notices): manager posts announcements; members see
--     them in the app (pinned ones as a banner on the Summary page).
--   * get_meal_month_summary re-created: per-member `opening_balance` (carry
--     from the previous closed month), balance now = opening + deposits −
--     costs; top-level `is_closed`, `closed_at`, `prev_month_closed`,
--     `total_opening`. Signature unchanged, so old mobile clients keep working.
-- Run this in the Supabase SQL Editor (after v17).

-- ---------- 1. Tables ----------

CREATE TABLE IF NOT EXISTS meal_month_closures (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
  note TEXT,
  closed_by UUID REFERENCES profiles(id) NOT NULL,
  closed_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, year, month)
);

-- Per-member balance snapshot taken at close time. This is what the next
-- month reads as opening_balance — a stored fact, not a live recalculation,
-- so editing history in a reopened month never silently changes a closed one.
CREATE TABLE IF NOT EXISTS meal_month_closure_balances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  closure_id UUID REFERENCES meal_month_closures(id) ON DELETE CASCADE NOT NULL,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  balance NUMERIC NOT NULL DEFAULT 0,
  UNIQUE (closure_id, member_id)
);

CREATE TABLE IF NOT EXISTS meal_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  date DATE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('off', 'guest')),
  -- off: 1 = turn that slot off; guest: how many guests that slot
  breakfast NUMERIC NOT NULL DEFAULT 0 CHECK (breakfast >= 0),
  lunch NUMERIC NOT NULL DEFAULT 0 CHECK (lunch >= 0),
  dinner NUMERIC NOT NULL DEFAULT 0 CHECK (dinner >= 0),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  responded_by UUID REFERENCES profiles(id),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_notices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  pinned BOOLEAN DEFAULT FALSE,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cutoff for meal off / guest requests. NULL = no cutoff (any time before the
-- date). 21:00 means: a request for date D must be in by 9pm on D−1 (Dhaka).
ALTER TABLE meal_groups ADD COLUMN IF NOT EXISTS cutoff_time TIME;

CREATE INDEX IF NOT EXISTS idx_meal_closures_group ON meal_month_closures(group_id, year, month);
CREATE INDEX IF NOT EXISTS idx_meal_closure_balances_closure ON meal_month_closure_balances(closure_id);
CREATE INDEX IF NOT EXISTS idx_meal_requests_group_date ON meal_requests(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_notices_group ON meal_notices(group_id, created_at);

-- ---------- 2. Closed-month helper ----------
-- SECURITY DEFINER so RLS policies can use it without their own table grants.

CREATE OR REPLACE FUNCTION is_meal_month_closed(p_group_id UUID, p_date DATE)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM meal_month_closures
    WHERE group_id = p_group_id
      AND year = EXTRACT(YEAR FROM p_date)::INT
      AND month = EXTRACT(MONTH FROM p_date)::INT
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---------- 3. RLS ----------

ALTER TABLE meal_month_closures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view month closures" ON meal_month_closures;
CREATE POLICY "Members can view month closures" ON meal_month_closures
  FOR SELECT USING (is_meal_group_member(group_id));
-- writes: close/reopen RPCs only

ALTER TABLE meal_month_closure_balances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view closure balances" ON meal_month_closure_balances;
CREATE POLICY "Members can view closure balances" ON meal_month_closure_balances
  FOR SELECT USING (is_meal_group_member(group_id));
-- writes: close RPC only

ALTER TABLE meal_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal requests" ON meal_requests;
CREATE POLICY "Members can view meal requests" ON meal_requests
  FOR SELECT USING (is_meal_group_member(group_id));
-- writes: submit/cancel/respond RPCs only (cutoff + ownership rules live there)

ALTER TABLE meal_notices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal notices" ON meal_notices;
CREATE POLICY "Members can view meal notices" ON meal_notices
  FOR SELECT USING (is_meal_group_member(group_id));
-- Split policies so any manager can edit/delete any notice (created_by is the
-- original author and stays put; requiring it to equal auth.uid() on UPDATE
-- would lock out co-managers).
DROP POLICY IF EXISTS "Managers can add meal notices" ON meal_notices;
CREATE POLICY "Managers can add meal notices" ON meal_notices
  FOR INSERT WITH CHECK (is_meal_group_manager(group_id) AND created_by = auth.uid());
DROP POLICY IF EXISTS "Managers can update meal notices" ON meal_notices;
CREATE POLICY "Managers can update meal notices" ON meal_notices
  FOR UPDATE USING (is_meal_group_manager(group_id))
  WITH CHECK (is_meal_group_manager(group_id));
DROP POLICY IF EXISTS "Managers can delete meal notices" ON meal_notices;
CREATE POLICY "Managers can delete meal notices" ON meal_notices
  FOR DELETE USING (is_meal_group_manager(group_id));

-- Deposits/expenses: re-create the write policies with a closed-month guard.
-- (SELECT policies are unchanged.)

DROP POLICY IF EXISTS "Managers can add meal deposits" ON meal_deposits;
CREATE POLICY "Managers can add meal deposits" ON meal_deposits
  FOR INSERT WITH CHECK (is_meal_group_manager(group_id) AND added_by = auth.uid()
    AND NOT is_meal_month_closed(group_id, date));
DROP POLICY IF EXISTS "Managers can update meal deposits" ON meal_deposits;
CREATE POLICY "Managers can update meal deposits" ON meal_deposits
  FOR UPDATE USING (is_meal_group_manager(group_id) AND NOT is_meal_month_closed(group_id, date))
  WITH CHECK (is_meal_group_manager(group_id) AND NOT is_meal_month_closed(group_id, date));
DROP POLICY IF EXISTS "Managers can delete meal deposits" ON meal_deposits;
CREATE POLICY "Managers can delete meal deposits" ON meal_deposits
  FOR DELETE USING (is_meal_group_manager(group_id) AND NOT is_meal_month_closed(group_id, date));

DROP POLICY IF EXISTS "Members can add meal expenses" ON meal_expenses;
CREATE POLICY "Members can add meal expenses" ON meal_expenses
  FOR INSERT WITH CHECK (is_meal_group_member(group_id) AND added_by = auth.uid()
    AND NOT is_meal_month_closed(group_id, date));
DROP POLICY IF EXISTS "Managers or authors can update meal expenses" ON meal_expenses;
CREATE POLICY "Managers or authors can update meal expenses" ON meal_expenses
  FOR UPDATE USING ((is_meal_group_manager(group_id) OR added_by = auth.uid())
    AND NOT is_meal_month_closed(group_id, date))
  WITH CHECK ((is_meal_group_manager(group_id) OR added_by = auth.uid())
    AND NOT is_meal_month_closed(group_id, date));
DROP POLICY IF EXISTS "Managers or authors can delete meal expenses" ON meal_expenses;
CREATE POLICY "Managers or authors can delete meal expenses" ON meal_expenses
  FOR DELETE USING ((is_meal_group_manager(group_id) OR added_by = auth.uid())
    AND NOT is_meal_month_closed(group_id, date));

-- ---------- 4. Closed-month guard in existing RPCs ----------

-- Same as v16 plus the closed-month check.
CREATE OR REPLACE FUNCTION upsert_meal_entry(
  p_group_id UUID,
  p_member_id UUID,
  p_date DATE,
  p_breakfast NUMERIC DEFAULT 0,
  p_lunch NUMERIC DEFAULT 0,
  p_dinner NUMERIC DEFAULT 0,
  p_guest_breakfast NUMERIC DEFAULT 0,
  p_guest_lunch NUMERIC DEFAULT 0,
  p_guest_dinner NUMERIC DEFAULT 0
) RETURNS UUID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_member RECORD;
  v_entry_id UUID;
BEGIN
  SELECT * INTO v_member FROM meal_group_members
  WHERE id = p_member_id AND group_id = p_group_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found in this group';
  END IF;

  IF NOT is_meal_group_manager(p_group_id) THEN
    IF v_member.user_id <> v_uid OR v_member.status <> 'approved' THEN
      RAISE EXCEPTION 'You can only record your own meals';
    END IF;
  END IF;

  IF p_date IS NULL THEN
    RAISE EXCEPTION 'Date is required';
  END IF;
  IF is_meal_month_closed(p_group_id, p_date) THEN
    RAISE EXCEPTION 'This month is closed. Reopen it from the Summary page to make changes.';
  END IF;
  IF LEAST(COALESCE(p_breakfast, 0), COALESCE(p_lunch, 0), COALESCE(p_dinner, 0),
           COALESCE(p_guest_breakfast, 0), COALESCE(p_guest_lunch, 0),
           COALESCE(p_guest_dinner, 0)) < 0 THEN
    RAISE EXCEPTION 'Meal counts cannot be negative';
  END IF;

  INSERT INTO meal_entries (group_id, member_id, date,
    breakfast, lunch, dinner, guest_breakfast, guest_lunch, guest_dinner,
    updated_by, updated_at)
  VALUES (p_group_id, p_member_id, p_date,
    COALESCE(p_breakfast, 0), COALESCE(p_lunch, 0), COALESCE(p_dinner, 0),
    COALESCE(p_guest_breakfast, 0), COALESCE(p_guest_lunch, 0), COALESCE(p_guest_dinner, 0),
    v_uid, NOW())
  ON CONFLICT (group_id, member_id, date) DO UPDATE SET
    breakfast = EXCLUDED.breakfast,
    lunch = EXCLUDED.lunch,
    dinner = EXCLUDED.dinner,
    guest_breakfast = EXCLUDED.guest_breakfast,
    guest_lunch = EXCLUDED.guest_lunch,
    guest_dinner = EXCLUDED.guest_dinner,
    updated_by = EXCLUDED.updated_by,
    updated_at = NOW()
  RETURNING id INTO v_entry_id;

  RETURN v_entry_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Same as v17 plus the closed-month check (it writes a deposit row, which
-- would otherwise slip past the deposit RLS because this is SECURITY DEFINER).
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
  IF is_meal_month_closed(v_member.group_id, p_date) THEN
    RAISE EXCEPTION 'This month is closed. Reopen it from the Summary page to make changes.';
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

-- ---------- 5. Month summary with carry-forward ----------
-- balance = opening_balance (previous month's closing snapshot, if that month
-- is closed) + deposits − meal_cost − fixed_share. Members with a nonzero
-- opening are listed even with no activity this month, so bokeya never
-- disappears from the table.

CREATE OR REPLACE FUNCTION get_meal_month_summary(
  p_group_id UUID,
  p_year INT,
  p_month INT
) RETURNS JSONB AS $$
DECLARE
  v_group RECORD;
  v_start DATE;
  v_end DATE;
  v_prev_year INT;
  v_prev_month INT;
  v_prev_closure_id UUID;
  v_closure RECORD;
  v_total_meals NUMERIC := 0;
  v_total_deposits NUMERIC := 0;
  v_total_bazar NUMERIC := 0;
  v_total_fixed NUMERIC := 0;
  v_total_advance NUMERIC := 0;
  v_total_opening NUMERIC := 0;
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

  v_prev_year := CASE WHEN p_month = 1 THEN p_year - 1 ELSE p_year END;
  v_prev_month := CASE WHEN p_month = 1 THEN 12 ELSE p_month - 1 END;
  SELECT id INTO v_prev_closure_id FROM meal_month_closures
  WHERE group_id = p_group_id AND year = v_prev_year AND month = v_prev_month;

  SELECT * INTO v_closure FROM meal_month_closures
  WHERE group_id = p_group_id AND year = p_year AND month = p_month;

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

  SELECT COALESCE(SUM(balance), 0) INTO v_total_opening
  FROM meal_month_closure_balances
  WHERE closure_id = v_prev_closure_id;

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
      'opening_balance', x.opening,
      'meal_cost', x.meal_cost,
      'fixed_share', x.fixed_share,
      'total_cost', ROUND(x.meal_cost + x.fixed_share, 2),
      'balance', ROUND(x.opening + x.deposits - x.meal_cost - x.fixed_share, 2)
    ) ORDER BY x.display_name), '[]'::jsonb)
  INTO v_members
  FROM (
    SELECT mm.id AS member_id, mm.user_id, mm.display_name, mm.status, mm.role,
      COALESCE(ent.meals, 0) AS meals,
      COALESCE(dep.deposits, 0) AS deposits,
      COALESCE(adv.advance, 0) AS advance,
      COALESCE(op.balance, 0) AS opening,
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
    LEFT JOIN (
      SELECT member_id, balance
      FROM meal_month_closure_balances
      WHERE closure_id = v_prev_closure_id
    ) op ON op.member_id = mm.id
    WHERE mm.group_id = p_group_id
      AND (mm.status = 'approved'
        OR COALESCE(ent.meals, 0) > 0
        OR COALESCE(dep.deposits, 0) > 0
        OR COALESCE(adv.advance, 0) <> 0
        OR COALESCE(op.balance, 0) <> 0)
  ) x;

  RETURN jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'total_meals', v_total_meals,
    'total_bazar', v_total_bazar,
    'total_fixed', v_total_fixed,
    'total_deposits', v_total_deposits,
    'total_advance', v_total_advance,
    'total_opening', v_total_opening,
    'meal_rate', ROUND(v_meal_rate, 2),
    'is_closed', v_closure.id IS NOT NULL,
    'closed_at', v_closure.closed_at,
    'prev_month_closed', v_prev_closure_id IS NOT NULL,
    'members', v_members
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 6. Close / reopen RPCs ----------

CREATE OR REPLACE FUNCTION close_meal_month(
  p_group_id UUID,
  p_year INT,
  p_month INT,
  p_note TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_start DATE;
  v_prev_year INT;
  v_prev_month INT;
  v_summary JSONB;
  v_closure_id UUID;
  v_member JSONB;
BEGIN
  IF NOT is_meal_group_manager(p_group_id) THEN
    RAISE EXCEPTION 'Only a manager can close a month';
  END IF;
  IF p_month < 1 OR p_month > 12 THEN
    RAISE EXCEPTION 'Invalid month: %', p_month;
  END IF;
  v_start := make_date(p_year, p_month, 1);

  IF v_start > date_trunc('month', (NOW() AT TIME ZONE 'Asia/Dhaka'))::DATE THEN
    RAISE EXCEPTION 'Cannot close a future month';
  END IF;
  IF EXISTS (SELECT 1 FROM meal_month_closures
             WHERE group_id = p_group_id AND year = p_year AND month = p_month) THEN
    RAISE EXCEPTION 'This month is already closed';
  END IF;

  -- Keep the carry chain hole-free: if there is any activity before this
  -- month, the previous month must already be closed.
  v_prev_year := CASE WHEN p_month = 1 THEN p_year - 1 ELSE p_year END;
  v_prev_month := CASE WHEN p_month = 1 THEN 12 ELSE p_month - 1 END;
  IF NOT EXISTS (SELECT 1 FROM meal_month_closures
                 WHERE group_id = p_group_id AND year = v_prev_year AND month = v_prev_month)
     AND (
       EXISTS (SELECT 1 FROM meal_entries WHERE group_id = p_group_id AND date < v_start)
       OR EXISTS (SELECT 1 FROM meal_deposits WHERE group_id = p_group_id AND date < v_start)
       OR EXISTS (SELECT 1 FROM meal_expenses WHERE group_id = p_group_id AND date < v_start)
     ) THEN
    RAISE EXCEPTION 'Close the previous month (%-%) first', v_prev_year, LPAD(v_prev_month::TEXT, 2, '0');
  END IF;

  -- Snapshot balances from the same math every screen uses
  v_summary := get_meal_month_summary(p_group_id, p_year, p_month);

  INSERT INTO meal_month_closures (group_id, year, month, note, closed_by)
  VALUES (p_group_id, p_year, p_month, NULLIF(TRIM(COALESCE(p_note, '')), ''), auth.uid())
  RETURNING id INTO v_closure_id;

  FOR v_member IN SELECT * FROM jsonb_array_elements(v_summary->'members') LOOP
    IF (v_member->>'balance')::NUMERIC <> 0 THEN
      INSERT INTO meal_month_closure_balances (closure_id, group_id, member_id, balance)
      VALUES (v_closure_id, p_group_id, (v_member->>'member_id')::UUID,
              (v_member->>'balance')::NUMERIC);
    END IF;
  END LOOP;

  RETURN v_closure_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reopen_meal_month(
  p_group_id UUID,
  p_year INT,
  p_month INT
) RETURNS VOID AS $$
DECLARE
  v_closure RECORD;
BEGIN
  IF NOT is_meal_group_manager(p_group_id) THEN
    RAISE EXCEPTION 'Only a manager can reopen a month';
  END IF;

  SELECT * INTO v_closure FROM meal_month_closures
  WHERE group_id = p_group_id AND year = p_year AND month = p_month FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This month is not closed';
  END IF;

  -- Reopen newest-first so a later month never carries from a reopened one
  IF EXISTS (SELECT 1 FROM meal_month_closures
             WHERE group_id = p_group_id AND (year, month) > (p_year, p_month)) THEN
    RAISE EXCEPTION 'Reopen the later closed month(s) first';
  END IF;

  DELETE FROM meal_month_closures WHERE id = v_closure.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 7. Meal off / guest request RPCs ----------

-- A member submits a request for themselves. Cutoff rule (when the group has
-- one): a request for date D must be in by cutoff_time on D−1, Dhaka time.
CREATE OR REPLACE FUNCTION submit_meal_request(
  p_group_id UUID,
  p_date DATE,
  p_type TEXT,
  p_breakfast NUMERIC DEFAULT 0,
  p_lunch NUMERIC DEFAULT 0,
  p_dinner NUMERIC DEFAULT 0,
  p_note TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_member RECORD;
  v_group RECORD;
  v_now TIMESTAMP;
  v_request_id UUID;
BEGIN
  SELECT * INTO v_member FROM meal_group_members
  WHERE group_id = p_group_id AND user_id = v_uid AND status = 'approved';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'You are not an approved member of this group';
  END IF;

  IF p_type NOT IN ('off', 'guest') THEN
    RAISE EXCEPTION 'Invalid request type: %', p_type;
  END IF;
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'Date is required';
  END IF;
  IF COALESCE(p_breakfast, 0) < 0 OR COALESCE(p_lunch, 0) < 0 OR COALESCE(p_dinner, 0) < 0 THEN
    RAISE EXCEPTION 'Counts cannot be negative';
  END IF;
  IF COALESCE(p_breakfast, 0) + COALESCE(p_lunch, 0) + COALESCE(p_dinner, 0) = 0 THEN
    RAISE EXCEPTION 'Pick at least one meal slot';
  END IF;
  IF is_meal_month_closed(p_group_id, p_date) THEN
    RAISE EXCEPTION 'This month is closed';
  END IF;

  SELECT * INTO v_group FROM meal_groups WHERE id = p_group_id;
  v_now := NOW() AT TIME ZONE 'Asia/Dhaka';

  IF p_date < v_now::DATE THEN
    RAISE EXCEPTION 'Cannot request for a past date';
  END IF;
  IF v_group.cutoff_time IS NOT NULL
     AND v_now > (p_date - 1) + v_group.cutoff_time THEN
    RAISE EXCEPTION 'Too late — requests for % had to be in by % the day before',
      TO_CHAR(p_date, 'DD Mon'), TO_CHAR((p_date - 1) + v_group.cutoff_time, 'HH12:MI AM');
  END IF;

  IF EXISTS (SELECT 1 FROM meal_requests
             WHERE group_id = p_group_id AND member_id = v_member.id
               AND date = p_date AND type = p_type AND status = 'pending') THEN
    RAISE EXCEPTION 'You already have a pending % request for this date', p_type;
  END IF;

  INSERT INTO meal_requests (group_id, member_id, date, type,
    breakfast, lunch, dinner, note)
  VALUES (p_group_id, v_member.id, p_date, p_type,
    COALESCE(p_breakfast, 0), COALESCE(p_lunch, 0), COALESCE(p_dinner, 0),
    NULLIF(TRIM(COALESCE(p_note, '')), ''))
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cancel_meal_request(p_request_id UUID) RETURNS VOID AS $$
DECLARE
  v_req RECORD;
  v_member RECORD;
BEGIN
  SELECT * INTO v_req FROM meal_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  SELECT * INTO v_member FROM meal_group_members WHERE id = v_req.member_id;
  IF v_member.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'You can only cancel your own request';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Only a pending request can be cancelled';
  END IF;

  UPDATE meal_requests SET status = 'cancelled' WHERE id = p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Manager approves or rejects. Approving writes the meal entry:
--   off   → the requested slots become 0 (row created if missing)
--   guest → guest counts are added on top of what is already there
CREATE OR REPLACE FUNCTION respond_meal_request(
  p_request_id UUID,
  p_approve BOOLEAN
) RETURNS VOID AS $$
DECLARE
  v_req RECORD;
BEGIN
  SELECT * INTO v_req FROM meal_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF NOT is_meal_group_manager(v_req.group_id) THEN
    RAISE EXCEPTION 'Only a manager can respond to requests';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'This request is not pending';
  END IF;

  IF p_approve THEN
    IF is_meal_month_closed(v_req.group_id, v_req.date) THEN
      RAISE EXCEPTION 'This month is closed';
    END IF;

    IF v_req.type = 'off' THEN
      INSERT INTO meal_entries (group_id, member_id, date,
        breakfast, lunch, dinner, updated_by, updated_at)
      VALUES (v_req.group_id, v_req.member_id, v_req.date, 0, 0, 0, auth.uid(), NOW())
      ON CONFLICT (group_id, member_id, date) DO UPDATE SET
        breakfast = CASE WHEN v_req.breakfast > 0 THEN 0 ELSE meal_entries.breakfast END,
        lunch     = CASE WHEN v_req.lunch > 0 THEN 0 ELSE meal_entries.lunch END,
        dinner    = CASE WHEN v_req.dinner > 0 THEN 0 ELSE meal_entries.dinner END,
        updated_by = auth.uid(),
        updated_at = NOW();
    ELSE
      INSERT INTO meal_entries (group_id, member_id, date,
        guest_breakfast, guest_lunch, guest_dinner, updated_by, updated_at)
      VALUES (v_req.group_id, v_req.member_id, v_req.date,
        v_req.breakfast, v_req.lunch, v_req.dinner, auth.uid(), NOW())
      ON CONFLICT (group_id, member_id, date) DO UPDATE SET
        guest_breakfast = meal_entries.guest_breakfast + v_req.breakfast,
        guest_lunch     = meal_entries.guest_lunch + v_req.lunch,
        guest_dinner    = meal_entries.guest_dinner + v_req.dinner,
        updated_by = auth.uid(),
        updated_at = NOW();
    END IF;
  END IF;

  UPDATE meal_requests SET
    status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    responded_by = auth.uid(),
    responded_at = NOW()
  WHERE id = p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
