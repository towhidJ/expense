-- v23: bKash/Nagad payment QR for deposits (Phase 2 of the feature-idea plan).
-- One row of payment info per group (manager-set numbers); the QR itself is
-- generated client-side from this plain text — no merchant API integration.
-- Run this in the Supabase SQL Editor (after v22).

CREATE TABLE IF NOT EXISTS meal_group_payment_info (
  group_id UUID PRIMARY KEY REFERENCES meal_groups(id) ON DELETE CASCADE,
  bkash_number TEXT,
  nagad_number TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE meal_group_payment_info ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view payment info" ON meal_group_payment_info;
CREATE POLICY "Members can view payment info" ON meal_group_payment_info
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can upsert payment info" ON meal_group_payment_info;
CREATE POLICY "Managers can upsert payment info" ON meal_group_payment_info
  FOR INSERT WITH CHECK (is_meal_group_manager(group_id));
DROP POLICY IF EXISTS "Managers can update payment info" ON meal_group_payment_info;
CREATE POLICY "Managers can update payment info" ON meal_group_payment_info
  FOR UPDATE USING (is_meal_group_manager(group_id)) WITH CHECK (is_meal_group_manager(group_id));
