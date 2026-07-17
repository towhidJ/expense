-- ============================================================
-- Migration v37 — Connect utility bills to recurring transactions
--
-- A recurring expense (e.g. fixed internet/TV bill) can now be tagged
-- with a utility type. When it auto-posts via run_due_recurring(),
-- the matching month's utility_bills row is created (or an existing
-- unpaid one is linked) with transaction_id set — i.e. the bill shows
-- up on /utility already marked PAID.
-- Run this whole file in the Supabase SQL Editor.
-- ============================================================

-- 1. Tag column on recurring_transactions (NULL = not a utility bill)
ALTER TABLE recurring_transactions ADD COLUMN IF NOT EXISTS utility_type TEXT
  CHECK (utility_type IN ('electricity', 'gas', 'water', 'internet', 'phone', 'tv', 'other'));

-- 2. run_due_recurring now records the utility bill for each posted period
CREATE OR REPLACE FUNCTION run_due_recurring(
  p_user_id UUID,
  p_entity_id UUID
) RETURNS INTEGER AS $$
DECLARE
  r RECORD;
  v_count INTEGER := 0;
  v_next DATE;
  v_tx_id UUID;
BEGIN
  FOR r IN
    SELECT * FROM recurring_transactions
    WHERE user_id = p_user_id AND entity_id = p_entity_id
      AND is_active AND next_run_date <= CURRENT_DATE
    FOR UPDATE
  LOOP
    v_next := r.next_run_date;
    WHILE v_next <= CURRENT_DATE LOOP
      v_tx_id := process_transaction(
        p_user_id, p_entity_id, r.account_id, r.category_id, NULL,
        r.type, r.amount, v_next, r.title || ' (Recurring)'
      );
      IF r.utility_type IS NOT NULL AND r.type = 'expense' THEN
        -- Create the month's bill as paid; if the user already logged the
        -- bill manually (e.g. with units), just link the payment to it —
        -- but never overwrite a bill that is already paid.
        INSERT INTO utility_bills (user_id, entity_id, type, bill_month, amount, transaction_id)
        VALUES (p_user_id, p_entity_id, r.utility_type, date_trunc('month', v_next)::DATE, r.amount, v_tx_id)
        ON CONFLICT (entity_id, type, bill_month)
        DO UPDATE SET transaction_id = EXCLUDED.transaction_id
        WHERE utility_bills.transaction_id IS NULL;
      END IF;
      v_count := v_count + 1;
      v_next := CASE r.frequency
        WHEN 'daily' THEN v_next + INTERVAL '1 day'
        WHEN 'weekly' THEN v_next + INTERVAL '7 days'
        WHEN 'monthly' THEN v_next + INTERVAL '1 month'
        WHEN 'yearly' THEN v_next + INTERVAL '1 year'
        ELSE v_next + INTERVAL '1 month'
      END;
    END LOOP;
    UPDATE recurring_transactions SET next_run_date = v_next WHERE id = r.id;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
