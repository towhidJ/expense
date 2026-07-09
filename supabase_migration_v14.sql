-- v14: Bazar (বাজার) — shop credit ledger for daily/monthly grocery shopping
-- Standard "baki khata" model:
--   * Each shop is a liability row (type 'shop_due'); its remaining_balance is
--     the current due, so Dashboard/net-worth pick it up automatically.
--   * Every bazar purchase (cash or due) creates an expense transaction, so
--     Reports and Budgets stay correct. Cash purchases deduct the account;
--     due purchases increase the shop's due instead.
--   * Paying the shop uses the existing process_loan_repayment RPC: account
--     goes down, shop due goes down, and NO expense is created (the expense
--     was already recorded at purchase time — no double counting).
-- Run this in the Supabase SQL Editor (after v13).

-- ---------- 1. Shops live in liabilities ----------
ALTER TABLE liabilities DROP CONSTRAINT IF EXISTS liabilities_type_check;
ALTER TABLE liabilities ADD CONSTRAINT liabilities_type_check
  CHECK (type IN ('loan_taken', 'loan_given', 'credit_card', 'installment', 'loan', 'shop_due'));

-- Shop contact number (harmless for other liability types)
ALTER TABLE liabilities ADD COLUMN IF NOT EXISTS phone TEXT;

-- ---------- 2. Link a due-purchase expense to its shop ----------
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS liability_id UUID REFERENCES liabilities(id) ON DELETE SET NULL;

-- ---------- 3. Bazar purchase ledger (every buy, cash or due) ----------
CREATE TABLE IF NOT EXISTS bazar_purchases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  liability_id UUID REFERENCES liabilities(id) ON DELETE SET NULL, -- shop, when bought on due
  account_id UUID REFERENCES accounts(id),                          -- account, when paid cash
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  payment_type TEXT NOT NULL CHECK (payment_type IN ('cash', 'due')),
  amount NUMERIC NOT NULL,
  date DATE NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE bazar_purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own bazar purchases" ON bazar_purchases;
CREATE POLICY "Users can manage their own bazar purchases" ON bazar_purchases FOR ALL USING (auth.uid() = user_id);

-- ---------- 4. Record a bazar purchase (balance-safe) ----------
CREATE OR REPLACE FUNCTION process_bazar_purchase(
  p_user_id UUID,
  p_entity_id UUID,
  p_category_id UUID,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT,
  p_payment_type TEXT,
  p_account_id UUID DEFAULT NULL,
  p_liability_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_txn_id UUID;
  v_purchase_id UUID;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Purchase amount must be positive';
  END IF;

  IF p_payment_type = 'cash' THEN
    IF p_account_id IS NULL THEN
      RAISE EXCEPTION 'Cash purchase requires an account';
    END IF;
    UPDATE accounts SET current_balance = current_balance - p_amount
    WHERE id = p_account_id AND user_id = p_user_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Account not found';
    END IF;

    INSERT INTO transactions (user_id, entity_id, account_id, category_id, type, amount, date, description)
    VALUES (p_user_id, p_entity_id, p_account_id, p_category_id, 'expense', p_amount, p_date, p_description)
    RETURNING id INTO v_txn_id;

  ELSIF p_payment_type = 'due' THEN
    IF p_liability_id IS NULL THEN
      RAISE EXCEPTION 'Due purchase requires a shop';
    END IF;
    UPDATE liabilities SET
      principal = principal + p_amount,
      remaining_balance = remaining_balance + p_amount
    WHERE id = p_liability_id AND user_id = p_user_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Shop not found';
    END IF;

    -- No account: money has not left yet. Expense is still recognized now.
    INSERT INTO transactions (user_id, entity_id, account_id, category_id, liability_id, type, amount, date, description)
    VALUES (p_user_id, p_entity_id, NULL, p_category_id, p_liability_id, 'expense', p_amount, p_date, p_description)
    RETURNING id INTO v_txn_id;

  ELSE
    RAISE EXCEPTION 'Invalid payment type: %', p_payment_type;
  END IF;

  INSERT INTO bazar_purchases (user_id, entity_id, liability_id, account_id, transaction_id, payment_type, amount, date, description)
  VALUES (p_user_id, p_entity_id,
          CASE WHEN p_payment_type = 'due' THEN p_liability_id END,
          CASE WHEN p_payment_type = 'cash' THEN p_account_id END,
          v_txn_id, p_payment_type, p_amount, p_date, p_description)
  RETURNING id INTO v_purchase_id;

  RETURN v_purchase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 5. Delete a bazar purchase (reverses everything) ----------
CREATE OR REPLACE FUNCTION delete_bazar_purchase(
  p_user_id UUID,
  p_purchase_id UUID
) RETURNS VOID AS $$
DECLARE
  v_old RECORD;
BEGIN
  SELECT * INTO v_old FROM bazar_purchases
  WHERE id = p_purchase_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN; -- already gone
  END IF;

  IF v_old.payment_type = 'cash' AND v_old.account_id IS NOT NULL THEN
    UPDATE accounts SET current_balance = current_balance + v_old.amount
    WHERE id = v_old.account_id AND user_id = p_user_id;
  ELSIF v_old.payment_type = 'due' AND v_old.liability_id IS NOT NULL THEN
    UPDATE liabilities SET
      principal = GREATEST(principal - v_old.amount, 0),
      remaining_balance = GREATEST(remaining_balance - v_old.amount, 0)
    WHERE id = v_old.liability_id AND user_id = p_user_id;
  END IF;

  IF v_old.transaction_id IS NOT NULL THEN
    DELETE FROM attachments WHERE transaction_id = v_old.transaction_id AND user_id = p_user_id;
    -- Deleting the transaction cascades to the bazar_purchases row
    DELETE FROM transactions WHERE id = v_old.transaction_id AND user_id = p_user_id;
  ELSE
    DELETE FROM bazar_purchases WHERE id = p_purchase_id AND user_id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 6. Keep Transactions-page edits/deletes consistent with shop dues ----------
-- A due purchase edited or deleted from the Transactions page must also adjust
-- the shop's due (and its bazar ledger row), otherwise balances drift.
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

  -- Shop-due purchase: adjust the shop's due by the amount delta
  IF v_old.liability_id IS NOT NULL AND p_amount <> v_old.amount THEN
    UPDATE liabilities SET
      principal = GREATEST(principal + (p_amount - v_old.amount), 0),
      remaining_balance = GREATEST(remaining_balance + (p_amount - v_old.amount), 0)
    WHERE id = v_old.liability_id AND user_id = p_user_id;
  END IF;

  -- Keep the bazar ledger row in sync (no-op for non-bazar transactions)
  UPDATE bazar_purchases SET amount = p_amount, date = p_date, description = p_description
  WHERE transaction_id = p_transaction_id AND user_id = p_user_id;

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

  -- Shop-due purchase: removing the expense also removes the due it created
  IF v_old.liability_id IS NOT NULL THEN
    UPDATE liabilities SET
      principal = GREATEST(principal - v_old.amount, 0),
      remaining_balance = GREATEST(remaining_balance - v_old.amount, 0)
    WHERE id = v_old.liability_id AND user_id = p_user_id;
  END IF;

  DELETE FROM attachments WHERE transaction_id = p_transaction_id AND user_id = p_user_id;
  -- bazar_purchases row (if any) goes away via ON DELETE CASCADE
  DELETE FROM transactions WHERE id = p_transaction_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
