-- v24: Meal trend charts (Phase 2 of the feature-idea plan).
-- get_meal_trend returns one row per month for the trailing p_months_back
-- months (oldest first), reusing the same meal-rate formula as
-- get_meal_month_summary (v17) so the two can never drift apart.
-- Run this in the Supabase SQL Editor (after v23).

CREATE OR REPLACE FUNCTION get_meal_trend(p_group_id UUID, p_months_back INT DEFAULT 6)
RETURNS TABLE (
  year INT,
  month INT,
  total_bazar NUMERIC,
  total_fixed NUMERIC,
  total_meals NUMERIC,
  meal_rate NUMERIC,
  top_spender_member_id UUID,
  top_spender_name TEXT,
  top_spender_amount NUMERIC
) AS $$
DECLARE
  v_group RECORD;
  v_month_start DATE;
  v_i INT;
BEGIN
  IF NOT is_meal_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;
  IF p_months_back < 1 OR p_months_back > 24 THEN
    RAISE EXCEPTION 'months_back must be between 1 and 24';
  END IF;

  SELECT * INTO v_group FROM meal_groups WHERE id = p_group_id;

  FOR v_i IN REVERSE (p_months_back - 1)..0 LOOP
    v_month_start := date_trunc('month', CURRENT_DATE)::DATE - (v_i || ' months')::INTERVAL;

    RETURN QUERY
    WITH bounds AS (
      SELECT v_month_start AS s, (v_month_start + INTERVAL '1 month')::DATE AS e
    ),
    bazar AS (
      SELECT COALESCE(SUM(me.amount), 0) AS total
      FROM meal_expenses me, bounds
      WHERE me.group_id = p_group_id AND me.expense_type = 'bazar'
        AND me.date >= bounds.s AND me.date < bounds.e
    ),
    fixed AS (
      SELECT COALESCE(SUM(me.amount), 0) AS total
      FROM meal_expenses me, bounds
      WHERE me.group_id = p_group_id AND me.expense_type <> 'bazar'
        AND me.date >= bounds.s AND me.date < bounds.e
    ),
    meals AS (
      SELECT COALESCE(SUM(
          (e.breakfast + e.guest_breakfast) * v_group.breakfast_value
        + (e.lunch + e.guest_lunch) * v_group.lunch_value
        + (e.dinner + e.guest_dinner) * v_group.dinner_value), 0) AS total
      FROM meal_entries e, bounds
      WHERE e.group_id = p_group_id AND e.date >= bounds.s AND e.date < bounds.e
    ),
    spender AS (
      SELECT me.spent_by, SUM(me.amount) AS spent
      FROM meal_expenses me, bounds
      WHERE me.group_id = p_group_id AND me.expense_type = 'bazar'
        AND me.spent_by IS NOT NULL
        AND me.date >= bounds.s AND me.date < bounds.e
      GROUP BY me.spent_by
      ORDER BY SUM(me.amount) DESC
      LIMIT 1
    )
    SELECT
      EXTRACT(YEAR FROM v_month_start)::INT,
      EXTRACT(MONTH FROM v_month_start)::INT,
      bazar.total,
      fixed.total,
      meals.total,
      COALESCE(bazar.total / NULLIF(meals.total, 0), 0),
      spender.spent_by,
      mm.display_name,
      spender.spent
    FROM bazar, fixed, meals
    LEFT JOIN spender ON TRUE
    LEFT JOIN meal_group_members mm ON mm.id = spender.spent_by;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
