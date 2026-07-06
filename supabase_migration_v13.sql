-- v13: Savings heads + account numbers
-- 1. saving_heads: named places where savings accumulate (e.g. "DBBL DPS",
--    "Islami Bank FDR", "Home Cash"). Each savings entry can point at a head,
--    so you can see how much is sitting in each one.
-- 2. accounts.account_number: bank a/c no, bKash number, card number, etc.
-- Run this in the Supabase SQL Editor (after v12).

-- ---------- 1. Saving heads ----------
CREATE TABLE IF NOT EXISTS saving_heads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  saving_type TEXT DEFAULT 'general',
  institution TEXT,
  account_number TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE saving_heads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own saving heads" ON saving_heads;
CREATE POLICY "Users can manage their own saving heads" ON saving_heads FOR ALL USING (auth.uid() = user_id);

-- Deleting a head keeps its entries; they just lose the link.
ALTER TABLE savings ADD COLUMN IF NOT EXISTS head_id UUID REFERENCES saving_heads(id) ON DELETE SET NULL;
ALTER TABLE recurring_savings ADD COLUMN IF NOT EXISTS head_id UUID REFERENCES saving_heads(id) ON DELETE SET NULL;

-- Recreate process_saving with p_head_id (defaulted, so v12 clients keep working)
DROP FUNCTION IF EXISTS process_saving(UUID, UUID, UUID, TEXT, NUMERIC, DATE, TEXT, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION process_saving(
  p_user_id UUID,
  p_entity_id UUID,
  p_account_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_purpose TEXT,
  p_notes TEXT,
  p_saving_type TEXT DEFAULT 'general',
  p_institution TEXT DEFAULT NULL,
  p_head_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO savings (user_id, entity_id, account_id, type, amount, date, purpose, notes, saving_type, institution, head_id)
  VALUES (p_user_id, p_entity_id, p_account_id, p_type, p_amount, p_date, p_purpose, p_notes,
          COALESCE(p_saving_type, 'general'), p_institution, p_head_id)
  RETURNING id INTO v_id;

  IF p_account_id IS NOT NULL THEN
    IF p_type = 'deposit' THEN
      UPDATE accounts SET current_balance = current_balance - p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    ELSE
      UPDATE accounts SET current_balance = current_balance + p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    END IF;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recurring runs must carry the head through to the created entries
CREATE OR REPLACE FUNCTION run_due_recurring_savings(
  p_user_id UUID,
  p_entity_id UUID
) RETURNS INTEGER AS $$
DECLARE
  r RECORD;
  v_count INTEGER := 0;
  v_next DATE;
BEGIN
  FOR r IN
    SELECT * FROM recurring_savings
    WHERE user_id = p_user_id AND entity_id = p_entity_id
      AND is_active AND next_run_date <= CURRENT_DATE
    FOR UPDATE
  LOOP
    v_next := r.next_run_date;
    WHILE v_next <= CURRENT_DATE LOOP
      PERFORM process_saving(
        p_user_id, p_entity_id, r.account_id, 'deposit',
        r.amount, v_next, r.title || ' (Recurring)', NULL,
        r.saving_type, r.institution, r.head_id
      );
      v_count := v_count + 1;
      v_next := CASE r.frequency
        WHEN 'daily' THEN v_next + INTERVAL '1 day'
        WHEN 'weekly' THEN v_next + INTERVAL '7 days'
        WHEN 'monthly' THEN v_next + INTERVAL '1 month'
        WHEN 'yearly' THEN v_next + INTERVAL '1 year'
        ELSE v_next + INTERVAL '1 month'
      END;
    END LOOP;
    UPDATE recurring_savings SET next_run_date = v_next WHERE id = r.id;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 2. Account numbers ----------
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS account_number TEXT;
