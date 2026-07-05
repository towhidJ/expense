-- v11: Link savings entries to an account so the money is properly accounted for.
-- Deposit  -> amount is deducted from the chosen account (money set aside).
-- Withdraw -> amount is added back to the chosen account.
-- Account is optional: entries without one don't touch any balance.

ALTER TABLE savings ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);

-- Insert a savings entry and adjust the account balance atomically
CREATE OR REPLACE FUNCTION process_saving(
  p_user_id UUID,
  p_entity_id UUID,
  p_account_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_purpose TEXT,
  p_notes TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO savings (user_id, entity_id, account_id, type, amount, date, purpose, notes)
  VALUES (p_user_id, p_entity_id, p_account_id, p_type, p_amount, p_date, p_purpose, p_notes)
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

-- Delete a savings entry, restoring the account balance first
CREATE OR REPLACE FUNCTION delete_saving_with_balance(
  p_user_id UUID,
  p_saving_id UUID
) RETURNS VOID AS $$
DECLARE
  v RECORD;
BEGIN
  SELECT * INTO v FROM savings WHERE id = p_saving_id AND user_id = p_user_id;
  IF v.id IS NULL THEN
    RETURN;
  END IF;

  IF v.account_id IS NOT NULL THEN
    IF v.type = 'deposit' THEN
      UPDATE accounts SET current_balance = current_balance + v.amount
      WHERE id = v.account_id AND user_id = p_user_id;
    ELSE
      UPDATE accounts SET current_balance = current_balance - v.amount
      WHERE id = v.account_id AND user_id = p_user_id;
    END IF;
  END IF;

  DELETE FROM savings WHERE id = p_saving_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
