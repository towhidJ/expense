-- v29: Full XIRR for investments (Phase 4 of the feature-idea plan).
-- Adds a cash-flow history so recurring-contribution types (dps) and
-- multi-tranche stock buys get an accurate annualized return, not just the
-- Phase 3 lump-sum CAGR approximation. XIRR itself is computed client-side
-- (Newton's method in JS, matching this codebase's existing client-side
-- analytics pattern) — this migration only adds the data it needs.
-- Run this in the Supabase SQL Editor (after v28).

CREATE TABLE IF NOT EXISTS investment_contributions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  investment_id UUID REFERENCES investments(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  amount NUMERIC NOT NULL, -- positive = money in (contribution), negative = withdrawal
  type TEXT NOT NULL DEFAULT 'contribution' CHECK (type IN ('contribution', 'withdrawal')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_investment_contributions_investment
  ON investment_contributions(investment_id, date);

ALTER TABLE investment_contributions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own investment contributions" ON investment_contributions;
CREATE POLICY "Users manage own investment contributions" ON investment_contributions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
