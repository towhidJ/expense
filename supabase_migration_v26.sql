-- v26: Auto duty rotation (Phase 2 of the feature-idea plan).
-- Manual assignment (DutyRoster.jsx) stays the default; this adds an
-- opt-in "fill next N days" generator per duty type, client-triggered only
-- (no cron — rotation is a rare manager-initiated action, not something
-- that needs to run unattended).
-- Run this in the Supabase SQL Editor (after v25).

ALTER TABLE meal_duty_types ADD COLUMN IF NOT EXISTS auto_rotate BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS meal_duty_rotation_order (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  duty_type_id UUID REFERENCES meal_duty_types(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) ON DELETE CASCADE NOT NULL,
  sort_order INT NOT NULL,
  UNIQUE (duty_type_id, member_id),
  UNIQUE (duty_type_id, sort_order)
);

ALTER TABLE meal_duty_rotation_order ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view rotation order" ON meal_duty_rotation_order;
CREATE POLICY "Members can view rotation order" ON meal_duty_rotation_order
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM meal_duty_types t WHERE t.id = duty_type_id AND is_meal_group_member(t.group_id))
  );
DROP POLICY IF EXISTS "Managers can manage rotation order" ON meal_duty_rotation_order;
CREATE POLICY "Managers can manage rotation order" ON meal_duty_rotation_order
  FOR ALL USING (
    EXISTS (SELECT 1 FROM meal_duty_types t WHERE t.id = duty_type_id AND is_meal_group_manager(t.group_id))
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM meal_duty_types t WHERE t.id = duty_type_id AND is_meal_group_manager(t.group_id))
  );

-- Replaces the full rotation order for one duty type in one call (drag-reorder
-- in the UI sends the whole new order rather than diffing).
CREATE OR REPLACE FUNCTION set_duty_rotation_order(p_duty_type_id UUID, p_member_ids UUID[])
RETURNS VOID AS $$
DECLARE
  v_group_id UUID;
  v_id UUID;
  v_i INT := 0;
BEGIN
  SELECT group_id INTO v_group_id FROM meal_duty_types WHERE id = p_duty_type_id;
  IF v_group_id IS NULL OR NOT is_meal_group_manager(v_group_id) THEN
    RAISE EXCEPTION 'Only a manager can set the rotation order';
  END IF;

  DELETE FROM meal_duty_rotation_order WHERE duty_type_id = p_duty_type_id;
  FOREACH v_id IN ARRAY p_member_ids LOOP
    v_i := v_i + 1;
    INSERT INTO meal_duty_rotation_order (duty_type_id, member_id, sort_order)
    VALUES (p_duty_type_id, v_id, v_i);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fills meal_duty_assignments for p_days days starting p_start_date, cycling
-- through meal_duty_rotation_order round-robin from wherever the most recent
-- existing assignment for this duty type left off. Skips group holidays and
-- dates that already have an assignment for this duty type.
CREATE OR REPLACE FUNCTION generate_duty_rotation(p_duty_type_id UUID, p_start_date DATE, p_days INT)
RETURNS SETOF meal_duty_assignments AS $$
DECLARE
  v_group_id UUID;
  v_order UUID[];
  v_count INT;
  v_cursor INT := 0;
  v_last_member UUID;
  v_date DATE;
  v_d INT;
  v_row meal_duty_assignments;
BEGIN
  SELECT group_id INTO v_group_id FROM meal_duty_types WHERE id = p_duty_type_id;
  IF v_group_id IS NULL OR NOT is_meal_group_manager(v_group_id) THEN
    RAISE EXCEPTION 'Only a manager can generate a rotation';
  END IF;
  IF p_days < 1 OR p_days > 62 THEN
    RAISE EXCEPTION 'days must be between 1 and 62';
  END IF;

  SELECT array_agg(member_id ORDER BY sort_order) INTO v_order
  FROM meal_duty_rotation_order WHERE duty_type_id = p_duty_type_id;
  v_count := COALESCE(array_length(v_order, 1), 0);
  IF v_count = 0 THEN
    RAISE EXCEPTION 'Set a rotation order for this duty first';
  END IF;

  -- Resume after whichever rotation-order member was assigned last (by date)
  SELECT a.member_id INTO v_last_member
  FROM meal_duty_assignments a
  WHERE a.duty_type_id = p_duty_type_id AND a.member_id = ANY(v_order)
  ORDER BY a.date DESC, a.created_at DESC
  LIMIT 1;
  IF v_last_member IS NOT NULL THEN
    SELECT sort_order INTO v_cursor FROM meal_duty_rotation_order
    WHERE duty_type_id = p_duty_type_id AND member_id = v_last_member;
  END IF;

  FOR v_d IN 0..(p_days - 1) LOOP
    v_date := p_start_date + v_d;
    CONTINUE WHEN EXISTS (SELECT 1 FROM meal_holidays h WHERE h.group_id = v_group_id AND h.date = v_date);
    CONTINUE WHEN EXISTS (
      SELECT 1 FROM meal_duty_assignments a WHERE a.duty_type_id = p_duty_type_id AND a.date = v_date
    );

    v_cursor := (v_cursor % v_count) + 1;
    INSERT INTO meal_duty_assignments (group_id, duty_type_id, member_id, date, note)
    VALUES (v_group_id, p_duty_type_id, v_order[v_cursor], v_date, 'Auto-rotated')
    RETURNING * INTO v_row;
    RETURN NEXT v_row;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
