-- Migration V2: SaaS Financial Management Upgrade

-- 1. Entities (Personal, Family, Business Workspaces)
CREATE TABLE entities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('personal', 'family', 'business')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own entities" ON entities FOR ALL USING (auth.uid() = user_id);

-- Create a default 'Personal' entity for all existing profiles
INSERT INTO entities (user_id, name, type)
SELECT id, 'Personal', 'personal' FROM profiles;

-- 2. Accounts (Cash, Bank, Mobile Banking, etc.)
CREATE TABLE accounts (
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
CREATE POLICY "Users can manage their own accounts" ON accounts FOR ALL USING (auth.uid() = user_id);

-- 3. Family Members
CREATE TABLE family_members (
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
CREATE POLICY "Users can manage their own family members" ON family_members FOR ALL USING (auth.uid() = user_id);

-- 4. Alter Existing Tables
ALTER TABLE assets ADD COLUMN entity_id UUID REFERENCES entities(id);
ALTER TABLE assets ADD COLUMN purchase_value NUMERIC DEFAULT 0;
ALTER TABLE assets ADD COLUMN current_value NUMERIC DEFAULT 0;
ALTER TABLE assets ADD COLUMN depreciation NUMERIC DEFAULT 0;

-- Assign existing assets to the user's personal entity
UPDATE assets SET entity_id = (
  SELECT id FROM entities WHERE entities.user_id = assets.user_id AND type = 'personal' LIMIT 1
);

ALTER TABLE transactions ADD COLUMN entity_id UUID REFERENCES entities(id);
ALTER TABLE transactions ADD COLUMN account_id UUID REFERENCES accounts(id);

-- Assign existing transactions to the user's personal entity
UPDATE transactions SET entity_id = (
  SELECT id FROM entities WHERE entities.user_id = transactions.user_id AND type = 'personal' LIMIT 1
);

ALTER TABLE budgets ADD COLUMN entity_id UUID REFERENCES entities(id);
UPDATE budgets SET entity_id = (
  SELECT id FROM entities WHERE entities.user_id = budgets.user_id AND type = 'personal' LIMIT 1
);

-- 5. Liabilities
CREATE TABLE liabilities (
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
CREATE POLICY "Users can manage their own liabilities" ON liabilities FOR ALL USING (auth.uid() = user_id);

-- 6. Investments
CREATE TABLE investments (
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
CREATE POLICY "Users can manage their own investments" ON investments FOR ALL USING (auth.uid() = user_id);

-- 7. Attachments
CREATE TABLE attachments (
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
CREATE POLICY "Users can manage their own attachments" ON attachments FOR ALL USING (auth.uid() = user_id);

-- 8. Update Trigger for new users
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
