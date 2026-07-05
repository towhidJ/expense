-- v10: Standalone savings module (separate from goals).
-- Tracks money set aside (deposit) and taken back (withdraw).
-- Does not touch account balances — it's a record of savings, like goals.

CREATE TABLE IF NOT EXISTS savings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'withdraw')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL,
  purpose TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE savings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own savings" ON savings;
CREATE POLICY "Users can manage their own savings" ON savings FOR ALL USING (auth.uid() = user_id);
