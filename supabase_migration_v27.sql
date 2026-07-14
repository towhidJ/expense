-- v27: Stock/inventory tracker (Phase 2 of the feature-idea plan).
-- Manual +/- adjustments only, for both stock-in and stock-out — there's no
-- reliable "consumed" signal, and auto-matching purchased item names to
-- stock rows risks double counting, so this deliberately does not derive
-- from meal_expenses.items.
-- Run this in the Supabase SQL Editor (after v26).

CREATE TABLE IF NOT EXISTS meal_stock_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  quantity NUMERIC NOT NULL DEFAULT 0,
  unit TEXT,
  low_stock_threshold NUMERIC,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, name)
);
CREATE INDEX IF NOT EXISTS idx_meal_stock_items_group ON meal_stock_items(group_id);

ALTER TABLE meal_stock_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view stock items" ON meal_stock_items;
CREATE POLICY "Members can view stock items" ON meal_stock_items
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Members can add stock items" ON meal_stock_items;
CREATE POLICY "Members can add stock items" ON meal_stock_items
  FOR INSERT WITH CHECK (is_meal_group_member(group_id));
-- Any member can record a +/- adjustment — same "shared list" trust model as
-- the shopping list (meal_shopping_items, v19).
DROP POLICY IF EXISTS "Members can update stock items" ON meal_stock_items;
CREATE POLICY "Members can update stock items" ON meal_stock_items
  FOR UPDATE USING (is_meal_group_member(group_id)) WITH CHECK (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can delete stock items" ON meal_stock_items;
CREATE POLICY "Managers can delete stock items" ON meal_stock_items
  FOR DELETE USING (is_meal_group_manager(group_id));

-- Atomic +/- so two members adjusting at once don't clobber each other via a
-- stale client-side quantity.
CREATE OR REPLACE FUNCTION adjust_meal_stock(p_stock_id UUID, p_delta NUMERIC)
RETURNS meal_stock_items AS $$
DECLARE
  v_row meal_stock_items;
BEGIN
  SELECT * INTO v_row FROM meal_stock_items WHERE id = p_stock_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item not found';
  END IF;
  IF NOT is_meal_group_member(v_row.group_id) THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  UPDATE meal_stock_items
  SET quantity = GREATEST(0, quantity + p_delta), updated_at = NOW()
  WHERE id = p_stock_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
