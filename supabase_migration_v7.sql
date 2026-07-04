-- Migration Script V7: Balance-safe transaction edit/delete + transfer hardening
-- Fixes: editing or deleting an account-linked transaction previously left the
-- account's current_balance unchanged, silently corrupting balances.

-- 1. Update a transaction and correct account balances atomically.
--    Reverses the old row's effect on its old account, then applies the new
--    values (supports moving the transaction to a different account).
CREATE OR REPLACE FUNCTION update_transaction_with_balance(
  p_user_id UUID,
  p_transaction_id UUID,
  p_account_id UUID,
  p_category_id UUID,
  p_asset_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT
) RETURNS VOID AS $$
DECLARE
  v_old RECORD;
BEGIN
  SELECT * INTO v_old FROM transactions
  WHERE id = p_transaction_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  -- Reverse the old effect on the old account
  IF v_old.account_id IS NOT NULL THEN
    IF v_old.type = 'income' THEN
      UPDATE accounts SET current_balance = current_balance - v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    ELSIF v_old.type = 'expense' THEN
      UPDATE accounts SET current_balance = current_balance + v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    END IF;
  END IF;

  -- Apply the new effect on the (possibly different) account
  IF p_account_id IS NOT NULL THEN
    IF p_type = 'income' THEN
      UPDATE accounts SET current_balance = current_balance + p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    ELSIF p_type = 'expense' THEN
      UPDATE accounts SET current_balance = current_balance - p_amount
      WHERE id = p_account_id AND user_id = p_user_id;
    END IF;
  END IF;

  UPDATE transactions SET
    account_id = p_account_id,
    category_id = p_category_id,
    asset_id = p_asset_id,
    type = p_type,
    amount = p_amount,
    date = p_date,
    description = p_description
  WHERE id = p_transaction_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Delete a transaction and restore the account balance atomically.
CREATE OR REPLACE FUNCTION delete_transaction_with_balance(
  p_user_id UUID,
  p_transaction_id UUID
) RETURNS VOID AS $$
DECLARE
  v_old RECORD;
BEGIN
  SELECT * INTO v_old FROM transactions
  WHERE id = p_transaction_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN; -- already gone
  END IF;

  IF v_old.account_id IS NOT NULL THEN
    IF v_old.type = 'income' THEN
      UPDATE accounts SET current_balance = current_balance - v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    ELSIF v_old.type = 'expense' THEN
      UPDATE accounts SET current_balance = current_balance + v_old.amount
      WHERE id = v_old.account_id AND user_id = p_user_id;
    END IF;
  END IF;

  DELETE FROM attachments WHERE transaction_id = p_transaction_id AND user_id = p_user_id;
  DELETE FROM transactions WHERE id = p_transaction_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Harden process_transfer: reject invalid transfers instead of corrupting balances.
CREATE OR REPLACE FUNCTION process_transfer(
  p_user_id UUID,
  p_entity_id UUID,
  p_from_account UUID,
  p_to_account UUID,
  p_amount NUMERIC,
  p_date DATE,
  p_notes TEXT
) RETURNS UUID AS $$
DECLARE
  v_transfer_id UUID;
BEGIN
  IF p_from_account = p_to_account THEN
    RAISE EXCEPTION 'Source and destination accounts must be different';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be positive';
  END IF;

  UPDATE accounts SET current_balance = current_balance - p_amount
  WHERE id = p_from_account AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source account not found';
  END IF;

  UPDATE accounts SET current_balance = current_balance + p_amount
  WHERE id = p_to_account AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Destination account not found';
  END IF;

  INSERT INTO transfers (user_id, entity_id, from_account_id, to_account_id, amount, date, notes)
  VALUES (p_user_id, p_entity_id, p_from_account, p_to_account, p_amount, p_date, p_notes)
  RETURNING id INTO v_transfer_id;

  RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Run all due recurring transactions for a user in one call.
--    Creates the transactions (updating balances) and advances next_run_date,
--    looping so items overdue by several periods catch up fully.
CREATE OR REPLACE FUNCTION run_due_recurring(
  p_user_id UUID,
  p_entity_id UUID
) RETURNS INTEGER AS $$
DECLARE
  r RECORD;
  v_count INTEGER := 0;
  v_next DATE;
BEGIN
  FOR r IN
    SELECT * FROM recurring_transactions
    WHERE user_id = p_user_id AND entity_id = p_entity_id
      AND is_active AND next_run_date <= CURRENT_DATE
    FOR UPDATE
  LOOP
    v_next := r.next_run_date;
    WHILE v_next <= CURRENT_DATE LOOP
      PERFORM process_transaction(
        p_user_id, p_entity_id, r.account_id, r.category_id, NULL,
        r.type, r.amount, v_next, r.title || ' (Recurring)'
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
    UPDATE recurring_transactions SET next_run_date = v_next WHERE id = r.id;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
