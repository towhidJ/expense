-- v20: Net worth timeline (expense tracker side).
-- One snapshot row per user + entity + month, upserted automatically whenever
-- the dashboard loads: the current month keeps refreshing until it ends, past
-- months stay frozen — so a monthly series builds up with no cron job.
-- Columns mirror exactly what the dashboard's net-worth card computes
-- (cash + assets + investments + receivables − liabilities), so the chart
-- always agrees with the headline number.
-- Run this in the Supabase SQL Editor (after v19).

CREATE TABLE IF NOT EXISTS net_worth_snapshots (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
  cash NUMERIC NOT NULL DEFAULT 0,
  assets NUMERIC NOT NULL DEFAULT 0,
  investments NUMERIC NOT NULL DEFAULT 0,
  receivables NUMERIC NOT NULL DEFAULT 0, -- loan_given remaining (money owed to you)
  liabilities NUMERIC NOT NULL DEFAULT 0,
  net_worth NUMERIC NOT NULL DEFAULT 0,
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, entity_id, year, month)
);
CREATE INDEX IF NOT EXISTS idx_net_worth_snapshots_series
  ON net_worth_snapshots(user_id, entity_id, year, month);

ALTER TABLE net_worth_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own net worth snapshots" ON net_worth_snapshots;
CREATE POLICY "Users can manage their own net worth snapshots" ON net_worth_snapshots
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
