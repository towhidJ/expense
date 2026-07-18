-- v41: 10 new modules — EMI Calculator, Debt Payoff Planner, Vehicle Expense,
-- Committee/Samity Tracker, Kids' Pocket Money, Charity Tracker, Invoicing,
-- Inventory/Stock, Bank Reconciliation, Document Vault. Run this in the
-- Supabase SQL Editor (after v40). Safe to re-run.
--
-- Notes:
--   * Every new table follows the standard entity-scoped pattern
--     (user_id + entity_id, RLS "auth.uid() = user_id", parent/child tables
--     both carry entity_id so useEntityTable.js works on either directly).
--   * Money movements reuse the existing process_transaction RPC (same
--     pattern as utility_bills.transaction_id) — no parallel balance logic.
--   * Bank Reconciliation (/reconcile) needs no new schema — it's a
--     client-side diff of an uploaded CSV against existing `transactions`.
--   * DPS/FDR tracking is NOT a new module — the existing Savings module
--     (`saving_heads` + `savings` + `recurring_savings`, v10/v12/v13) already
--     models exactly this: a named place money accumulates, with
--     saving_type IN ('dps','fdr'), real account-linked deposits via
--     process_saving, and recurring monthly deposits. Section 2 below only
--     adds the interest-rate/tenure/maturity fields Savings didn't have.

-- ============================================================
-- 1. EMI Calculator — saved scenarios (the calculator itself is client-side)
-- ============================================================
CREATE TABLE IF NOT EXISTS emi_scenarios (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  principal NUMERIC NOT NULL CHECK (principal > 0),
  interest_rate NUMERIC NOT NULL DEFAULT 0,
  tenure_months INTEGER NOT NULL CHECK (tenure_months > 0),
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  liability_id UUID REFERENCES liabilities(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE emi_scenarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own emi scenarios" ON emi_scenarios;
CREATE POLICY "Users manage own emi scenarios" ON emi_scenarios FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 2. DPS / FDR maturity tracking — additive columns on the EXISTING
--    saving_heads table (not a new module). Meaningful only when
--    saving_type IN ('dps', 'fdr'); NULL/blank for every other head.
-- ============================================================
ALTER TABLE saving_heads ADD COLUMN IF NOT EXISTS interest_rate NUMERIC;
ALTER TABLE saving_heads ADD COLUMN IF NOT EXISTS tenure_months INTEGER;
ALTER TABLE saving_heads ADD COLUMN IF NOT EXISTS start_date DATE;

-- ============================================================
-- 3. Debt Payoff Planner — reuses `liabilities`, just needs a min payment
-- ============================================================
ALTER TABLE liabilities ADD COLUMN IF NOT EXISTS min_payment NUMERIC;

-- ============================================================
-- 4. Vehicle Expense
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  vehicle_type TEXT,
  reg_number TEXT,
  purchase_date DATE,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  asset_id UUID REFERENCES assets(id) ON DELETE SET NULL, -- link to an existing Assets row (type='Vehicle') instead of double-entering
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Covers the case where this migration already ran before this column existed.
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS asset_id UUID REFERENCES assets(id) ON DELETE SET NULL;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own vehicles" ON vehicles;
CREATE POLICY "Users manage own vehicles" ON vehicles FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS vehicle_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  log_type TEXT NOT NULL CHECK (log_type IN ('fuel', 'service', 'other')),
  log_date DATE NOT NULL DEFAULT CURRENT_DATE,
  odometer NUMERIC,
  amount NUMERIC NOT NULL CHECK (amount >= 0),
  liters NUMERIC,
  notes TEXT,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE vehicle_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own vehicle logs" ON vehicle_logs;
CREATE POLICY "Users manage own vehicle logs" ON vehicle_logs FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_logs_vehicle ON vehicle_logs(vehicle_id);

-- ============================================================
-- 5. Committee / Samity Tracker
-- ============================================================
CREATE TABLE IF NOT EXISTS committees (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  monthly_amount NUMERIC NOT NULL CHECK (monthly_amount > 0),
  total_members INTEGER,
  your_turn_month DATE,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE committees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own committees" ON committees;
CREATE POLICY "Users manage own committees" ON committees FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS committee_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  committee_id UUID REFERENCES committees(id) ON DELETE CASCADE NOT NULL,
  pay_month DATE NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  entry_type TEXT NOT NULL CHECK (entry_type IN ('deposit', 'payout')),
  paid_date DATE NOT NULL DEFAULT CURRENT_DATE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (committee_id, pay_month, entry_type)
);
ALTER TABLE committee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own committee payments" ON committee_payments;
CREATE POLICY "Users manage own committee payments" ON committee_payments FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_committee_payments_committee ON committee_payments(committee_id);

-- ============================================================
-- 6. Kids' Pocket Money — target settings; actual payouts are `transactions`
--    rows with family_member_id set (added v30), logged via process_transaction.
-- ============================================================
CREATE TABLE IF NOT EXISTS family_allowances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  family_member_id UUID REFERENCES family_members(id) ON DELETE CASCADE NOT NULL,
  monthly_target NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (family_member_id)
);
ALTER TABLE family_allowances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own family allowances" ON family_allowances;
CREATE POLICY "Users manage own family allowances" ON family_allowances FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 7. Charity / Sadaqah Tracker
-- ============================================================
CREATE TABLE IF NOT EXISTS charity_donations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  recipient TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'sadaqah' CHECK (category IN ('zakat', 'sadaqah', 'other')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE charity_donations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own charity donations" ON charity_donations;
CREATE POLICY "Users manage own charity donations" ON charity_donations FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 8. Invoicing
-- ============================================================
CREATE TABLE IF NOT EXISTS invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  invoice_number TEXT NOT NULL,
  client_name TEXT NOT NULL,
  client_contact TEXT,
  issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'paid', 'overdue', 'cancelled')),
  account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (entity_id, invoice_number)
);
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own invoices" ON invoices;
CREATE POLICY "Users manage own invoices" ON invoices FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS invoice_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE NOT NULL,
  description TEXT NOT NULL,
  quantity NUMERIC NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0
);
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own invoice items" ON invoice_items;
CREATE POLICY "Users manage own invoice items" ON invoice_items FOR ALL USING (
  EXISTS (SELECT 1 FROM invoices WHERE invoices.id = invoice_items.invoice_id AND invoices.user_id = auth.uid())
);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);

-- ============================================================
-- 9. Inventory / Stock
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  name TEXT NOT NULL,
  sku TEXT,
  unit TEXT NOT NULL DEFAULT 'pcs',
  quantity NUMERIC NOT NULL DEFAULT 0,
  cost_price NUMERIC DEFAULT 0,
  sale_price NUMERIC DEFAULT 0,
  reorder_level NUMERIC DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own inventory items" ON inventory_items;
CREATE POLICY "Users manage own inventory items" ON inventory_items FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  entity_id UUID REFERENCES entities(id) NOT NULL,
  item_id UUID REFERENCES inventory_items(id) ON DELETE CASCADE NOT NULL,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('in', 'out')),
  quantity NUMERIC NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC DEFAULT 0,
  move_date DATE NOT NULL DEFAULT CURRENT_DATE,
  notes TEXT,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own inventory movements" ON inventory_movements;
CREATE POLICY "Users manage own inventory movements" ON inventory_movements FOR ALL USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_item ON inventory_movements(item_id);

-- Quantity is a running balance like accounts.current_balance — must go
-- through this RPC, never a plain UPDATE, to stay race-safe and to keep the
-- optional linked transaction (process_transaction) in sync.
CREATE OR REPLACE FUNCTION process_inventory_movement(
  p_user_id UUID,
  p_entity_id UUID,
  p_item_id UUID,
  p_movement_type TEXT,
  p_quantity NUMERIC,
  p_unit_price NUMERIC DEFAULT 0,
  p_date DATE DEFAULT CURRENT_DATE,
  p_notes TEXT DEFAULT NULL,
  p_account_id UUID DEFAULT NULL,
  p_category_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_movement_id UUID;
  v_txn_id UUID;
  v_item_name TEXT;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive';
  END IF;
  IF p_movement_type NOT IN ('in', 'out') THEN
    RAISE EXCEPTION 'Invalid movement type';
  END IF;

  SELECT name INTO v_item_name FROM inventory_items WHERE id = p_item_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item not found';
  END IF;

  IF p_movement_type = 'in' THEN
    UPDATE inventory_items SET quantity = quantity + p_quantity WHERE id = p_item_id;
  ELSE
    UPDATE inventory_items SET quantity = quantity - p_quantity WHERE id = p_item_id;
  END IF;

  INSERT INTO inventory_movements (user_id, entity_id, item_id, movement_type, quantity, unit_price, move_date, notes)
  VALUES (p_user_id, p_entity_id, p_item_id, p_movement_type, p_quantity, p_unit_price, p_date, p_notes)
  RETURNING id INTO v_movement_id;

  IF p_account_id IS NOT NULL THEN
    v_txn_id := process_transaction(
      p_user_id, p_entity_id, p_account_id, p_category_id, NULL,
      CASE WHEN p_movement_type = 'in' THEN 'expense' ELSE 'income' END,
      p_quantity * COALESCE(p_unit_price, 0),
      p_date,
      v_item_name || ' — ' || CASE WHEN p_movement_type = 'in' THEN 'stock purchase' ELSE 'stock sale' END
    );
    UPDATE inventory_movements SET transaction_id = v_txn_id WHERE id = v_movement_id;
  END IF;

  RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. Bank Statement Reconciliation — no schema; client-side diff of an
--     uploaded CSV against `transactions` (entity-scoped).
-- ============================================================

-- ============================================================
-- 11. Document Vault — reuses the `attachments` table + `documents` bucket.
--     A vault doc is a row with doc_category set and no transaction/
--     liability/asset link.
-- ============================================================
ALTER TABLE attachments ADD COLUMN IF NOT EXISTS doc_category TEXT;
ALTER TABLE attachments ADD COLUMN IF NOT EXISTS expiry_date DATE;
ALTER TABLE attachments ADD COLUMN IF NOT EXISTS title TEXT;

-- ============================================================
-- 12. module_access seed — missing key = free, admin toggles premium later.
-- ============================================================
INSERT INTO module_access (module_key) VALUES
  ('emi'), ('debt-payoff'), ('vehicle'), ('committee'),
  ('pocket-money'), ('charity'), ('invoicing'), ('inventory'),
  ('reconcile'), ('documents')
ON CONFLICT (module_key) DO NOTHING;
