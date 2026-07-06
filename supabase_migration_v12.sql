-- v12: Savings enhancements + asset quantities
-- 1. savings.saving_type  : what kind of saving (general / bank / dps / fdr / cash / other)
--    savings.institution  : where the money is kept (bank or place name)
-- 2. recurring_savings    : scheduled automatic savings entries, processed by
--    run_due_recurring_savings() the same way recurring_transactions work.
-- 3. assets.quantity/unit : e.g. gold -> 5 bhori, land -> 10 katha.
-- Run this in the Supabase SQL Editor.

-- ---------- 1. Savings columns ----------
ALTER TABLE savings ADD COLUMN IF NOT EXISTS saving_type TEXT DEFAULT 'general';
ALTER TABLE savings ADD COLUMN IF NOT EXISTS institution TEXT;

-- Recreate process_saving with the new fields. The two new params default to
-- NULL/'general' so older clients that pass 8 args keep working.
DROP FUNCTION IF EXISTS process_saving(UUID, UUID, UUID, TEXT, NUMERIC, DATE, TEXT, TEXT);
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
  p_institution TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO savings (user_id, entity_id, account_id, type, amount, date, purpose, notes, saving_type, institution)
  VALUES (p_user_id, p_entity_id, p_account_id, p_type, p_amount, p_date, p_purpose, p_notes,
          COALESCE(p_saving_type, 'general'), p_institution)
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

-- ---------- 2. Recurring savings ----------
CREATE TABLE IF NOT EXISTS recurring_savings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  account_id UUID REFERENCES accounts(id),
  title TEXT NOT NULL,
  saving_type TEXT DEFAULT 'general',
  institution TEXT,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
  next_run_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE recurring_savings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own recurring savings" ON recurring_savings;
CREATE POLICY "Users can manage their own recurring savings" ON recurring_savings FOR ALL USING (auth.uid() = user_id);

-- Process every due recurring saving (catching up missed periods), same
-- pattern as run_due_recurring for transactions. Returns entries created.
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
        r.saving_type, r.institution
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

-- ---------- 3. Asset quantities ----------
ALTER TABLE assets ADD COLUMN IF NOT EXISTS quantity NUMERIC;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS unit TEXT;
