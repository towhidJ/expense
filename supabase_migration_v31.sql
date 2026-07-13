-- v31: Bank statement CSV import (Phase 4 of the feature-idea plan).
-- CSV only — PDF bank statements are too format-fragile to parse reliably
-- without the AI/OCR capability this whole plan explicitly excludes.
-- process_transactions_bulk reuses process_transaction's balance-safe logic
-- per row, all inside one transaction, so a bad row rolls back the entire
-- batch instead of leaving accounts.current_balance half-updated.
-- Run this in the Supabase SQL Editor (after v30).

CREATE TABLE IF NOT EXISTS import_category_mappings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  keyword TEXT NOT NULL, -- lowercased substring matched against the bank's description
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, keyword)
);

ALTER TABLE import_category_mappings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own import mappings" ON import_category_mappings;
CREATE POLICY "Users manage own import mappings" ON import_category_mappings
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- p_rows: JSONB array of {account_id, category_id, asset_id, type, amount,
-- date, description} objects, one per CSV row (asset_id/description
-- optional). Loops the exact same balance-update + insert logic as
-- process_transaction, in one transaction — the whole batch fails together.
CREATE OR REPLACE FUNCTION process_transactions_bulk(p_entity_id UUID, p_rows JSONB)
RETURNS SETOF UUID AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row JSONB;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM entities WHERE id = p_entity_id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'Workspace not found';
  END IF;

  FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_id := process_transaction(
      v_uid,
      p_entity_id,
      (v_row->>'account_id')::UUID,
      (v_row->>'category_id')::UUID,
      NULLIF(v_row->>'asset_id', '')::UUID,
      v_row->>'type',
      (v_row->>'amount')::NUMERIC,
      (v_row->>'date')::DATE,
      COALESCE(v_row->>'description', '')
    );
    RETURN NEXT v_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
