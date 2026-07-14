-- v25: Meal item price history (Phase 2 of the feature-idea plan).
-- Reads straight off the existing meal_expenses.items JSONB (added v17) —
-- no new table. Itemized purchases are low-read-volume analytics, so a
-- normalized table isn't worth the double-write cost in ExpensesTab's
-- ItemListEditor; revisit only if usage shows a real performance need.
-- Run this in the Supabase SQL Editor (after v24).

CREATE OR REPLACE FUNCTION get_meal_item_names(p_group_id UUID)
RETURNS TABLE (name TEXT) AS $$
  SELECT DISTINCT item->>'name'
  FROM meal_expenses e, jsonb_array_elements(e.items) AS item
  WHERE e.group_id = p_group_id AND is_meal_group_member(p_group_id)
    AND item->>'name' IS NOT NULL AND TRIM(item->>'name') <> ''
  ORDER BY 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_meal_item_price_history(p_group_id UUID, p_item_name TEXT)
RETURNS TABLE (date DATE, amount NUMERIC, expense_id UUID) AS $$
  SELECT e.date, (item->>'amount')::NUMERIC, e.id
  FROM meal_expenses e, jsonb_array_elements(e.items) AS item
  WHERE e.group_id = p_group_id AND is_meal_group_member(p_group_id)
    AND item->>'name' ILIKE p_item_name
    AND item->>'amount' IS NOT NULL AND item->>'amount' <> ''
  ORDER BY e.date;
$$ LANGUAGE sql SECURITY DEFINER STABLE;
