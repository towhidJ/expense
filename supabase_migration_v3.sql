-- Migration V3: Life Finance OS Upgrade

-- 1. Entities (Personal, Family, Business Workspaces)
CREATE TABLE IF NOT EXISTS entities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('personal', 'family', 'business')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own entities" ON entities;
CREATE POLICY "Users can manage their own entities" ON entities FOR ALL USING (auth.uid() = user_id);

-- Create a default 'Personal' entity for all existing profiles
INSERT INTO entities (user_id, name, type)
SELECT id, 'Personal', 'personal' FROM profiles
WHERE NOT EXISTS (SELECT 1 FROM entities WHERE entities.user_id = profiles.id);

-- 2. Accounts (Cash, Bank, Mobile Banking, etc.)
CREATE TABLE IF NOT EXISTS accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('cash', 'bank', 'mobile', 'wallet', 'credit_card')),
  opening_balance NUMERIC DEFAULT 0,
  current_balance NUMERIC DEFAULT 0,
  currency TEXT DEFAULT '৳',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own accounts" ON accounts;
CREATE POLICY "Users can manage their own accounts" ON accounts FOR ALL USING (auth.uid() = user_id);

-- 3. Family Members
CREATE TABLE IF NOT EXISTS family_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  date_of_birth DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own family members" ON family_members;
CREATE POLICY "Users can manage their own family members" ON family_members FOR ALL USING (auth.uid() = user_id);

-- 4. Alter Existing Tables Safely
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='assets' AND column_name='entity_id') THEN
        ALTER TABLE assets ADD COLUMN entity_id UUID REFERENCES entities(id);
        ALTER TABLE assets ADD COLUMN purchase_value NUMERIC DEFAULT 0;
        ALTER TABLE assets ADD COLUMN current_value NUMERIC DEFAULT 0;
        ALTER TABLE assets ADD COLUMN depreciation NUMERIC DEFAULT 0;
        
        UPDATE assets SET entity_id = (SELECT id FROM entities WHERE entities.user_id = assets.user_id AND type = 'personal' LIMIT 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transactions' AND column_name='entity_id') THEN
        ALTER TABLE transactions ADD COLUMN entity_id UUID REFERENCES entities(id);
        ALTER TABLE transactions ADD COLUMN account_id UUID REFERENCES accounts(id);
        
        UPDATE transactions SET entity_id = (SELECT id FROM entities WHERE entities.user_id = transactions.user_id AND type = 'personal' LIMIT 1);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='budgets' AND column_name='entity_id') THEN
        ALTER TABLE budgets ADD COLUMN entity_id UUID REFERENCES entities(id);
        UPDATE budgets SET entity_id = (SELECT id FROM entities WHERE entities.user_id = budgets.user_id AND type = 'personal' LIMIT 1);
    END IF;
END $$;

-- 5. Liabilities
CREATE TABLE IF NOT EXISTS liabilities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('loan', 'credit_card', 'installment')),
  principal NUMERIC NOT NULL,
  interest_rate NUMERIC DEFAULT 0,
  due_date DATE,
  remaining_balance NUMERIC NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE liabilities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own liabilities" ON liabilities;
CREATE POLICY "Users can manage their own liabilities" ON liabilities FOR ALL USING (auth.uid() = user_id);

-- 6. Investments
CREATE TABLE IF NOT EXISTS investments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('stocks', 'mutual_funds', 'fdr', 'dps', 'crypto')),
  invested_amount NUMERIC NOT NULL,
  current_value NUMERIC DEFAULT 0,
  roi NUMERIC DEFAULT 0,
  profit_loss NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE investments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own investments" ON investments;
CREATE POLICY "Users can manage their own investments" ON investments FOR ALL USING (auth.uid() = user_id);

-- 7. Goals
CREATE TABLE IF NOT EXISTS goals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  title TEXT NOT NULL,
  target_amount NUMERIC NOT NULL,
  saved_amount NUMERIC DEFAULT 0,
  target_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own goals" ON goals;
CREATE POLICY "Users can manage their own goals" ON goals FOR ALL USING (auth.uid() = user_id);

-- 8. Recurring Transactions
CREATE TABLE IF NOT EXISTS recurring_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  account_id UUID REFERENCES accounts(id) NOT NULL,
  category_id UUID REFERENCES categories(id) NOT NULL,
  title TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  amount NUMERIC NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
  next_run_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own recurring transactions" ON recurring_transactions;
CREATE POLICY "Users can manage their own recurring transactions" ON recurring_transactions FOR ALL USING (auth.uid() = user_id);

-- 9. Transfers
CREATE TABLE IF NOT EXISTS transfers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  from_account_id UUID REFERENCES accounts(id) NOT NULL,
  to_account_id UUID REFERENCES accounts(id) NOT NULL,
  amount NUMERIC NOT NULL,
  date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own transfers" ON transfers;
CREATE POLICY "Users can manage their own transfers" ON transfers FOR ALL USING (auth.uid() = user_id);

-- Database function to safely execute transfers
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
  -- Deduct from source
  UPDATE accounts SET current_balance = current_balance - p_amount 
  WHERE id = p_from_account AND user_id = p_user_id;
  
  -- Add to destination
  UPDATE accounts SET current_balance = current_balance + p_amount 
  WHERE id = p_to_account AND user_id = p_user_id;
  
  -- Record transfer
  INSERT INTO transfers (user_id, entity_id, from_account_id, to_account_id, amount, date, notes)
  VALUES (p_user_id, p_entity_id, p_from_account, p_to_account, p_amount, p_date, p_notes)
  RETURNING id INTO v_transfer_id;
  
  RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Attachments
CREATE TABLE IF NOT EXISTS attachments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id),
  transaction_id UUID REFERENCES transactions(id),
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_size INTEGER,
  content_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own attachments" ON attachments;
CREATE POLICY "Users can manage their own attachments" ON attachments FOR ALL USING (auth.uid() = user_id);

-- 11. Database function to process income and expense (updates account balance)
CREATE OR REPLACE FUNCTION process_transaction(
  p_user_id UUID,
  p_entity_id UUID,
  p_account_id UUID,
  p_category_id UUID,
  p_asset_id UUID,
  p_type TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_description TEXT
) RETURNS UUID AS $$
DECLARE
  v_transaction_id UUID;
BEGIN
  -- Update account balance
  IF p_type = 'income' THEN
    UPDATE accounts SET current_balance = current_balance + p_amount 
    WHERE id = p_account_id AND user_id = p_user_id;
  ELSIF p_type = 'expense' THEN
    UPDATE accounts SET current_balance = current_balance - p_amount 
    WHERE id = p_account_id AND user_id = p_user_id;
  END IF;
  
  -- Record transaction
  INSERT INTO transactions (user_id, entity_id, account_id, category_id, asset_id, type, amount, date, description)
  VALUES (p_user_id, p_entity_id, p_account_id, p_category_id, p_asset_id, p_type, p_amount, p_date, p_description)
  RETURNING id INTO v_transaction_id;
  
  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11.5. Loan Repayments History Table
CREATE TABLE IF NOT EXISTS loan_repayments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  liability_id UUID REFERENCES liabilities(id) ON DELETE CASCADE NOT NULL,
  account_id UUID REFERENCES accounts(id),
  amount NUMERIC NOT NULL,
  date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE loan_repayments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own loan repayments" ON loan_repayments;
CREATE POLICY "Users can manage their own loan repayments" ON loan_repayments FOR ALL USING (auth.uid() = user_id);

-- 12. Database function to process loan repayment
CREATE OR REPLACE FUNCTION process_loan_repayment(
  p_user_id UUID,
  p_entity_id UUID,
  p_liability_id UUID,
  p_account_id UUID,
  p_amount NUMERIC,
  p_date DATE,
  p_notes TEXT
) RETURNS UUID AS $$
DECLARE
  v_transaction_id UUID;
  v_liability_type TEXT;
BEGIN
  -- Get liability type to determine cash flow direction
  SELECT type INTO v_liability_type FROM liabilities WHERE id = p_liability_id;

  -- Update account balance
  IF v_liability_type = 'loan_given' THEN
    -- They are paying you back -> Inflow of cash
    UPDATE accounts SET current_balance = current_balance + p_amount 
    WHERE id = p_account_id AND user_id = p_user_id;
  ELSE
    -- You are paying them -> Outflow of cash
    UPDATE accounts SET current_balance = current_balance - p_amount 
    WHERE id = p_account_id AND user_id = p_user_id;
  END IF;
  
  -- Reduce liability remaining balance
  UPDATE liabilities SET remaining_balance = remaining_balance - p_amount 
  WHERE id = p_liability_id AND user_id = p_user_id;
  
  -- Record the repayment history
  INSERT INTO loan_repayments (user_id, entity_id, liability_id, account_id, amount, date, notes)
  VALUES (p_user_id, p_entity_id, p_liability_id, p_account_id, p_amount, p_date, p_notes)
  RETURNING id INTO v_transaction_id;
  
  RETURN v_transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Database function to process a new loan/borrowing (adds money to account)
CREATE OR REPLACE FUNCTION process_new_loan(
  p_user_id UUID,
  p_entity_id UUID,
  p_name TEXT,
  p_type TEXT,
  p_principal NUMERIC,
  p_interest_rate NUMERIC,
  p_due_date DATE,
  p_notes TEXT,
  p_account_id UUID
) RETURNS UUID AS $$
DECLARE
  v_liability_id UUID;
BEGIN
  -- Create the liability record
  INSERT INTO liabilities (user_id, entity_id, name, type, principal, interest_rate, due_date, remaining_balance, notes)
  VALUES (p_user_id, p_entity_id, p_name, p_type, p_principal, p_interest_rate, p_due_date, p_principal, p_notes)
  RETURNING id INTO v_liability_id;

  -- Add or deduct the borrowed amount to/from the target account (if specified)
  IF p_account_id IS NOT NULL THEN
    IF p_type = 'loan_given' THEN
      -- You gave someone money -> Outflow of cash
      UPDATE accounts SET current_balance = current_balance - p_principal 
      WHERE id = p_account_id AND user_id = p_user_id;
    ELSE
      -- You borrowed money -> Inflow of cash
      UPDATE accounts SET current_balance = current_balance + p_principal 
      WHERE id = p_account_id AND user_id = p_user_id;
    END IF;
  END IF;

  RETURN v_liability_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. Update Trigger for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');

  INSERT INTO public.entities (user_id, name, type)
  VALUES (new.id, 'Personal', 'personal');

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 15. Fix constraints for Liabilities (Loan Taken / Given)
ALTER TABLE liabilities DROP CONSTRAINT IF EXISTS liabilities_type_check;
ALTER TABLE liabilities ADD CONSTRAINT liabilities_type_check CHECK (type IN ('loan_taken', 'loan_given', 'credit_card', 'installment', 'loan'));
UPDATE liabilities SET type = 'loan_taken' WHERE type = 'loan';
