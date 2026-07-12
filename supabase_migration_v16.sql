-- v16: Meal Management (bachelor mess) — the app's first multi-user shared feature.
-- Model:
--   * A meal group is a mess. One user creates it (becomes manager) and gets an
--     invite code; others join with the code and wait for manager approval.
--   * Meal counting: one row per member per date with breakfast/lunch/dinner
--     counts (+ guest counts). Slot weights (e.g. 0.5/1/1) live on the group
--     and are applied at aggregation time, so past entries stay raw counts.
--   * Mess ledger is standalone: member deposits + group expenses (bazar,
--     utility, maid, other). It never touches personal accounts/transactions,
--     so the "money via RPC" balance convention does not apply here — deposits
--     and expenses are plain RLS-guarded inserts.
--   * Month accounting via get_meal_month_summary: meal_rate = total bazar /
--     total weighted meals; fixed costs split equally among members active
--     that month; balance = deposits - (meals*rate + fixed share).
--   * Duty roster: per-group duty types (5 built-ins seeded, custom allowed),
--     manager assigns members to duties per date. Cooking is flagged
--     excluded_when_maid so it disappears from the roster when the group has
--     a maid (kajer bua).
--   * RLS is membership-based via SECURITY DEFINER helpers (same trick as
--     is_app_admin in v15) — NOT the usual auth.uid() = user_id pattern,
--     because group data is shared across users. Memberships are never
--     hard-deleted once they have data; statuses 'left'/'removed' keep
--     historical months intact.
-- Run this in the Supabase SQL Editor (after v15).

-- ---------- 1. Tables ----------

CREATE TABLE IF NOT EXISTS meal_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  invite_code TEXT NOT NULL UNIQUE,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  has_maid BOOLEAN DEFAULT FALSE,
  breakfast_value NUMERIC DEFAULT 0.5 CHECK (breakfast_value >= 0),
  lunch_value NUMERIC DEFAULT 1 CHECK (lunch_value >= 0),
  dinner_value NUMERIC DEFAULT 1 CHECK (dinner_value >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  -- Snapshot: profiles RLS is self-only, so other members cannot join to it
  display_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('manager', 'member')),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'left', 'removed')),
  joined_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS meal_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  date DATE NOT NULL,
  breakfast NUMERIC NOT NULL DEFAULT 0 CHECK (breakfast >= 0),
  lunch NUMERIC NOT NULL DEFAULT 0 CHECK (lunch >= 0),
  dinner NUMERIC NOT NULL DEFAULT 0 CHECK (dinner >= 0),
  guest_breakfast NUMERIC NOT NULL DEFAULT 0 CHECK (guest_breakfast >= 0),
  guest_lunch NUMERIC NOT NULL DEFAULT 0 CHECK (guest_lunch >= 0),
  guest_dinner NUMERIC NOT NULL DEFAULT 0 CHECK (guest_dinner >= 0),
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, member_id, date)
);

CREATE TABLE IF NOT EXISTS meal_deposits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL,
  note TEXT,
  added_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  expense_type TEXT NOT NULL DEFAULT 'bazar'
    CHECK (expense_type IN ('bazar', 'utility', 'maid', 'other')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL,
  note TEXT,
  spent_by UUID REFERENCES meal_group_members(id), -- who did the bazar (optional)
  added_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_duty_types (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  is_builtin BOOLEAN DEFAULT FALSE,
  excluded_when_maid BOOLEAN DEFAULT FALSE, -- TRUE for Cooking
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS meal_duty_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  duty_type_id UUID REFERENCES meal_duty_types(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  date DATE NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  -- several members may share one duty on one day, but not twice
  UNIQUE (group_id, date, duty_type_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_meal_entries_group_date ON meal_entries(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_deposits_group_date ON meal_deposits(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_expenses_group_date ON meal_expenses(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_duty_group_date ON meal_duty_assignments(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_members_user ON meal_group_members(user_id);

-- ---------- 2. Membership helpers ----------
-- SECURITY DEFINER so they can be used inside RLS policies (including on
-- meal_group_members itself) without recursing into that table's own RLS.

CREATE OR REPLACE FUNCTION is_meal_group_member(p_group_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM meal_group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND status = 'approved'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_meal_group_manager(p_group_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM meal_group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
      AND status = 'approved' AND role = 'manager'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Any-status link: a pending applicant may see the group's name while waiting
CREATE OR REPLACE FUNCTION has_meal_group_link(p_group_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM meal_group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---------- 3. RLS ----------
-- No INSERT/UPDATE policies where a table says "RPC only": those writes go
-- through SECURITY DEFINER functions that enforce their own rules.

ALTER TABLE meal_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Linked users can view meal groups" ON meal_groups;
CREATE POLICY "Linked users can view meal groups" ON meal_groups
  FOR SELECT USING (has_meal_group_link(id));
DROP POLICY IF EXISTS "Managers can update meal groups" ON meal_groups;
CREATE POLICY "Managers can update meal groups" ON meal_groups
  FOR UPDATE USING (is_meal_group_manager(id)) WITH CHECK (is_meal_group_manager(id));
DROP POLICY IF EXISTS "Managers can delete meal groups" ON meal_groups;
CREATE POLICY "Managers can delete meal groups" ON meal_groups
  FOR DELETE USING (is_meal_group_manager(id));

ALTER TABLE meal_group_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view group memberships" ON meal_group_members;
CREATE POLICY "Members can view group memberships" ON meal_group_members
  FOR SELECT USING (user_id = auth.uid() OR is_meal_group_member(group_id));

ALTER TABLE meal_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal entries" ON meal_entries;
CREATE POLICY "Members can view meal entries" ON meal_entries
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can delete meal entries" ON meal_entries;
CREATE POLICY "Managers can delete meal entries" ON meal_entries
  FOR DELETE USING (is_meal_group_manager(group_id));

ALTER TABLE meal_deposits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal deposits" ON meal_deposits;
CREATE POLICY "Members can view meal deposits" ON meal_deposits
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can add meal deposits" ON meal_deposits;
CREATE POLICY "Managers can add meal deposits" ON meal_deposits
  FOR INSERT WITH CHECK (is_meal_group_manager(group_id) AND added_by = auth.uid());
DROP POLICY IF EXISTS "Managers can update meal deposits" ON meal_deposits;
CREATE POLICY "Managers can update meal deposits" ON meal_deposits
  FOR UPDATE USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));
DROP POLICY IF EXISTS "Managers can delete meal deposits" ON meal_deposits;
CREATE POLICY "Managers can delete meal deposits" ON meal_deposits
  FOR DELETE USING (is_meal_group_manager(group_id));

ALTER TABLE meal_expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view meal expenses" ON meal_expenses;
CREATE POLICY "Members can view meal expenses" ON meal_expenses
  FOR SELECT USING (is_meal_group_member(group_id));
-- The member who did the bazar records it themselves
DROP POLICY IF EXISTS "Members can add meal expenses" ON meal_expenses;
CREATE POLICY "Members can add meal expenses" ON meal_expenses
  FOR INSERT WITH CHECK (is_meal_group_member(group_id) AND added_by = auth.uid());
DROP POLICY IF EXISTS "Managers or authors can update meal expenses" ON meal_expenses;
CREATE POLICY "Managers or authors can update meal expenses" ON meal_expenses
  FOR UPDATE USING (is_meal_group_manager(group_id) OR added_by = auth.uid())
  WITH CHECK (is_meal_group_manager(group_id) OR added_by = auth.uid());
DROP POLICY IF EXISTS "Managers or authors can delete meal expenses" ON meal_expenses;
CREATE POLICY "Managers or authors can delete meal expenses" ON meal_expenses
  FOR DELETE USING (is_meal_group_manager(group_id) OR added_by = auth.uid());

ALTER TABLE meal_duty_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view duty types" ON meal_duty_types;
CREATE POLICY "Members can view duty types" ON meal_duty_types
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can manage duty types" ON meal_duty_types;
CREATE POLICY "Managers can manage duty types" ON meal_duty_types
  FOR ALL USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));

ALTER TABLE meal_duty_assignments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view duty assignments" ON meal_duty_assignments;
CREATE POLICY "Members can view duty assignments" ON meal_duty_assignments
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can manage duty assignments" ON meal_duty_assignments;
CREATE POLICY "Managers can manage duty assignments" ON meal_duty_assignments
  FOR ALL USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));

-- Duty-type SELECT policies above require approved membership; managers are
-- approved members too, so they are covered by the member policies.

-- ---------- 4. Group lifecycle RPCs ----------

-- Ambiguity-free alphabet (no 0/O, 1/I/L)
CREATE OR REPLACE FUNCTION generate_meal_invite_code() RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code TEXT;
  i INT;
BEGIN
  LOOP
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_chars, 1 + floor(random() * length(v_chars))::INT, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM meal_groups WHERE invite_code = v_code);
  END LOOP;
  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_meal_group(
  p_name TEXT,
  p_display_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_group_id UUID;
  v_name TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    RAISE EXCEPTION 'Group name is required';
  END IF;

  SELECT COALESCE(NULLIF(TRIM(p_display_name), ''), full_name, 'Manager')
    INTO v_name FROM profiles WHERE id = v_uid;
  IF v_name IS NULL THEN
    v_name := COALESCE(NULLIF(TRIM(p_display_name), ''), 'Manager');
  END IF;

  INSERT INTO meal_groups (name, invite_code, created_by)
  VALUES (TRIM(p_name), generate_meal_invite_code(), v_uid)
  RETURNING id INTO v_group_id;

  INSERT INTO meal_group_members (group_id, user_id, display_name, role, status, joined_at)
  VALUES (v_group_id, v_uid, v_name, 'manager', 'approved', NOW());

  INSERT INTO meal_duty_types (group_id, name, is_builtin, excluded_when_maid, sort_order) VALUES
    (v_group_id, 'Bazar', TRUE, FALSE, 1),
    (v_group_id, 'Cooking', TRUE, TRUE, 2),
    (v_group_id, 'Vegetable Cutting', TRUE, FALSE, 3),
    (v_group_id, 'Dish Washing', TRUE, FALSE, 4),
    (v_group_id, 'Washroom Cleaning', TRUE, FALSE, 5);

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION join_meal_group(
  p_code TEXT,
  p_display_name TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_group_id UUID;
  v_name TEXT;
  v_existing RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  SELECT id INTO v_group_id FROM meal_groups
  WHERE invite_code = UPPER(TRIM(COALESCE(p_code, '')));
  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  SELECT COALESCE(NULLIF(TRIM(p_display_name), ''), full_name, 'Member')
    INTO v_name FROM profiles WHERE id = v_uid;
  IF v_name IS NULL THEN
    v_name := COALESCE(NULLIF(TRIM(p_display_name), ''), 'Member');
  END IF;

  SELECT * INTO v_existing FROM meal_group_members
  WHERE group_id = v_group_id AND user_id = v_uid FOR UPDATE;

  IF FOUND THEN
    IF v_existing.status = 'approved' THEN
      RAISE EXCEPTION 'You are already a member of this group';
    ELSIF v_existing.status = 'pending' THEN
      RAISE EXCEPTION 'Your join request is already pending approval';
    END IF;
    -- rejected / left / removed: apply again
    UPDATE meal_group_members
    SET status = 'pending', role = 'member', display_name = v_name, joined_at = NULL
    WHERE id = v_existing.id;
  ELSE
    INSERT INTO meal_group_members (group_id, user_id, display_name, role, status)
    VALUES (v_group_id, v_uid, v_name, 'member', 'pending');
  END IF;

  RETURN v_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION respond_meal_join_request(
  p_member_id UUID,
  p_approve BOOLEAN
) RETURNS VOID AS $$
DECLARE
  v_row RECORD;
BEGIN
  SELECT * INTO v_row FROM meal_group_members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Join request not found';
  END IF;
  IF NOT is_meal_group_manager(v_row.group_id) THEN
    RAISE EXCEPTION 'Only a manager can approve or reject requests';
  END IF;
  IF v_row.status <> 'pending' THEN
    RAISE EXCEPTION 'This request is not pending';
  END IF;

  IF p_approve THEN
    UPDATE meal_group_members SET status = 'approved', joined_at = NOW()
    WHERE id = p_member_id;
  ELSE
    UPDATE meal_group_members SET status = 'rejected' WHERE id = p_member_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION remove_meal_member(p_member_id UUID) RETURNS VOID AS $$
DECLARE
  v_row RECORD;
BEGIN
  SELECT * INTO v_row FROM meal_group_members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF NOT is_meal_group_manager(v_row.group_id) THEN
    RAISE EXCEPTION 'Only a manager can remove members';
  END IF;
  IF v_row.user_id = auth.uid() THEN
    RAISE EXCEPTION 'Use leave group instead of removing yourself';
  END IF;
  IF v_row.role = 'manager' AND v_row.status = 'approved' THEN
    RAISE EXCEPTION 'Demote the manager to member before removing';
  END IF;

  IF v_row.status = 'pending' THEN
    UPDATE meal_group_members SET status = 'rejected' WHERE id = p_member_id;
  ELSE
    UPDATE meal_group_members SET status = 'removed' WHERE id = p_member_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION leave_meal_group(p_group_id UUID) RETURNS VOID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row RECORD;
BEGIN
  SELECT * INTO v_row FROM meal_group_members
  WHERE group_id = p_group_id AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_row.status NOT IN ('approved', 'pending') THEN
    RAISE EXCEPTION 'You are not a member of this group';
  END IF;

  IF v_row.role = 'manager' AND v_row.status = 'approved' THEN
    IF NOT EXISTS (
      SELECT 1 FROM meal_group_members
      WHERE group_id = p_group_id AND status = 'approved'
        AND role = 'manager' AND id <> v_row.id
    ) THEN
      RAISE EXCEPTION 'Assign another manager before leaving the group';
    END IF;
  END IF;

  UPDATE meal_group_members SET status = 'left' WHERE id = v_row.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION set_meal_member_role(
  p_member_id UUID,
  p_role TEXT
) RETURNS VOID AS $$
DECLARE
  v_row RECORD;
BEGIN
  IF p_role NOT IN ('manager', 'member') THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  SELECT * INTO v_row FROM meal_group_members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member not found';
  END IF;
  IF NOT is_meal_group_manager(v_row.group_id) THEN
    RAISE EXCEPTION 'Only a manager can change roles';
  END IF;
  IF v_row.status <> 'approved' THEN
    RAISE EXCEPTION 'Member is not approved';
  END IF;

  IF p_role = 'member' AND v_row.role = 'manager' THEN
    IF NOT EXISTS (
      SELECT 1 FROM meal_group_members
      WHERE group_id = v_row.group_id AND status = 'approved'
        AND role = 'manager' AND id <> v_row.id
    ) THEN
      RAISE EXCEPTION 'The group needs at least one manager';
    END IF;
  END IF;

  UPDATE meal_group_members SET role = p_role WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION regenerate_meal_invite_code(p_group_id UUID) RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
BEGIN
  IF NOT is_meal_group_manager(p_group_id) THEN
    RAISE EXCEPTION 'Only a manager can regenerate the invite code';
  END IF;
  v_code := generate_meal_invite_code();
  UPDATE meal_groups SET invite_code = v_code WHERE id = p_group_id;
  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 5. Meal entry upsert ----------
-- One code path enforces "a member edits their own row, a manager edits
-- anyone's" — hence no INSERT/UPDATE RLS policies on meal_entries.

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

-- ---------- 6. Month summary ----------
-- Single source of truth for the mess math, shared by web and mobile.
--   meal_rate   = total bazar / total weighted meals
--   fixed costs = utility + maid + other, split equally among members active
--                 that month (any meals or deposits); if nobody is active,
--                 among all approved members
--   balance     = deposits - (meals * meal_rate + fixed share)
-- Members listed: all approved + any past member with activity that month.

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
    WHERE mm.group_id = p_group_id
      AND (mm.status = 'approved'
        OR COALESCE(ent.meals, 0) > 0
        OR COALESCE(dep.deposits, 0) > 0)
  ) x;

  RETURN jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'total_meals', v_total_meals,
    'total_bazar', v_total_bazar,
    'total_fixed', v_total_fixed,
    'total_deposits', v_total_deposits,
    'meal_rate', ROUND(v_meal_rate, 2),
    'members', v_members
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
