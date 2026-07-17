-- v35: "everything pack" — DB pieces for 9 new modules added 2026-07-16.
-- Bill Splitter, Insurance, Utility Bills, Rent Management, Activity Log,
-- Subscriptions flag, Warranty Vault, Multi-currency rate, Meal stock expiry.
-- All guarded with IF NOT EXISTS — safe to run (and re-run) in the SQL Editor.

-- ============================================================
-- 1. Bill Splitter (trips / dinners with friends — snapshot names, no auth users)
-- ============================================================
CREATE TABLE IF NOT EXISTS split_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  event_date DATE DEFAULT CURRENT_DATE,
  notes TEXT,
  is_settled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE split_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own split events" ON split_events;
CREATE POLICY "Users manage own split events" ON split_events FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS split_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  event_id UUID REFERENCES split_events(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  is_me BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE split_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own split members" ON split_members;
CREATE POLICY "Users manage own split members" ON split_members FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS split_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  event_id UUID REFERENCES split_events(id) ON DELETE CASCADE NOT NULL,
  payer_member_id UUID REFERENCES split_members(id) ON DELETE CASCADE NOT NULL,
  description TEXT NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  -- who shares this expense; empty/NULL means "everyone in the event"
  participant_ids UUID[],
  expense_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE split_expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own split expenses" ON split_expenses;
CREATE POLICY "Users manage own split expenses" ON split_expenses FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_split_members_event ON split_members(event_id);
CREATE INDEX IF NOT EXISTS idx_split_expenses_event ON split_expenses(event_id);

-- ============================================================
-- 2. Insurance policies
-- ============================================================
CREATE TABLE IF NOT EXISTS insurance_policies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('life', 'health', 'vehicle', 'property', 'other')),
  provider TEXT,
  policy_number TEXT,
  premium_amount NUMERIC NOT NULL DEFAULT 0,
  premium_frequency TEXT NOT NULL DEFAULT 'yearly' CHECK (premium_frequency IN ('monthly', 'quarterly', 'yearly')),
  next_premium_date DATE,
  coverage_amount NUMERIC,
  maturity_date DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE insurance_policies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own insurance" ON insurance_policies;
CREATE POLICY "Users manage own insurance" ON insurance_policies FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 3. Utility bills (month-wise electricity/gas/water/internet)
-- ============================================================
CREATE TABLE IF NOT EXISTS utility_bills (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('electricity', 'gas', 'water', 'internet', 'phone', 'tv', 'other')),
  bill_month DATE NOT NULL, -- always the 1st of the month
  units NUMERIC,            -- kWh / cubic meter etc. (optional)
  amount NUMERIC NOT NULL CHECK (amount >= 0),
  due_date DATE,
  -- set when paid through an account (payment goes via process_transaction)
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (entity_id, type, bill_month)
);
ALTER TABLE utility_bills ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own utility bills" ON utility_bills;
CREATE POLICY "Users manage own utility bills" ON utility_bills FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 4. Rent management (landlord side)
-- ============================================================
CREATE TABLE IF NOT EXISTS rental_units (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,          -- e.g. "2nd Floor Flat A"
  tenant_name TEXT,
  tenant_phone TEXT,
  monthly_rent NUMERIC NOT NULL DEFAULT 0,
  advance_deposit NUMERIC DEFAULT 0,
  rent_start DATE,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE rental_units ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own rental units" ON rental_units;
CREATE POLICY "Users manage own rental units" ON rental_units FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS rent_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  unit_id UUID REFERENCES rental_units(id) ON DELETE CASCADE NOT NULL,
  rent_month DATE NOT NULL,    -- the 1st of the month the payment covers
  amount NUMERIC NOT NULL CHECK (amount > 0),
  paid_date DATE NOT NULL DEFAULT CURRENT_DATE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (unit_id, rent_month)
);
ALTER TABLE rent_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own rent payments" ON rent_payments;
CREATE POLICY "Users manage own rent payments" ON rent_payments FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_rent_payments_unit ON rent_payments(unit_id);

-- ============================================================
-- 5. Activity log (audit trail; filled by triggers, read-only for the client)
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  entity_id UUID,
  action TEXT NOT NULL,      -- created / updated / deleted
  table_name TEXT NOT NULL,
  record_id UUID,
  summary TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own activity" ON activity_log;
CREATE POLICY "Users read own activity" ON activity_log FOR SELECT USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_user ON activity_log(user_id, entity_id, created_at DESC);

CREATE OR REPLACE FUNCTION log_activity() RETURNS trigger AS $$
DECLARE
  -- Field access on a plain RECORD is validated when the expression is prepared,
  -- even inside non-taken CASE branches — so referencing a column one of the
  -- audited tables lacks (e.g. transactions has no "name") would raise
  -- 'record has no field'. Go through jsonb, where a missing key is just NULL.
  v_js JSONB;
  v_summary TEXT;
BEGIN
  v_js := to_jsonb(COALESCE(NEW, OLD));
  v_summary := CASE TG_TABLE_NAME
    WHEN 'transactions' THEN INITCAP(COALESCE(v_js->>'type', 'transaction')) || ' ৳' || COALESCE(v_js->>'amount', '?') || COALESCE(' — ' || NULLIF(v_js->>'description', ''), '')
    WHEN 'transfers'    THEN 'Transfer ৳' || COALESCE(v_js->>'amount', '?')
    WHEN 'liabilities'  THEN COALESCE(v_js->>'name', 'Liability') || ' (৳' || COALESCE(v_js->>'principal', '?') || ')'
    WHEN 'accounts'     THEN 'Account ' || COALESCE(v_js->>'name', '?')
    ELSE TG_TABLE_NAME
  END;
  INSERT INTO activity_log (user_id, entity_id, action, table_name, record_id, summary)
  VALUES (
    (v_js->>'user_id')::UUID,
    (v_js->>'entity_id')::UUID,
    CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
    TG_TABLE_NAME,
    (v_js->>'id')::UUID,
    v_summary
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_log_transactions ON transactions;
CREATE TRIGGER trg_log_transactions AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION log_activity();
DROP TRIGGER IF EXISTS trg_log_transfers ON transfers;
CREATE TRIGGER trg_log_transfers AFTER INSERT OR DELETE ON transfers
  FOR EACH ROW EXECUTE FUNCTION log_activity();
DROP TRIGGER IF EXISTS trg_log_liabilities ON liabilities;
CREATE TRIGGER trg_log_liabilities AFTER INSERT OR UPDATE OR DELETE ON liabilities
  FOR EACH ROW EXECUTE FUNCTION log_activity();
DROP TRIGGER IF EXISTS trg_log_accounts ON accounts;
CREATE TRIGGER trg_log_accounts AFTER INSERT OR DELETE ON accounts
  FOR EACH ROW EXECUTE FUNCTION log_activity();

-- ============================================================
-- 6. Small column additions
-- ============================================================
-- Subscriptions view over recurring expenses
ALTER TABLE recurring_transactions ADD COLUMN IF NOT EXISTS is_subscription BOOLEAN DEFAULT FALSE;
-- Warranty vault on assets + asset documents
ALTER TABLE assets ADD COLUMN IF NOT EXISTS warranty_expiry DATE;
ALTER TABLE assets ADD COLUMN IF NOT EXISTS warranty_notes TEXT;
ALTER TABLE attachments ADD COLUMN IF NOT EXISTS asset_id UUID REFERENCES assets(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_attachments_asset ON attachments(asset_id);
-- Multi-currency: manual rate to BDT (1 unit of account currency = X BDT)
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC DEFAULT 1;
-- Meal stock expiry tracking
ALTER TABLE meal_stock_items ADD COLUMN IF NOT EXISTS expiry_date DATE;
