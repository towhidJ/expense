-- ============================================================
-- Migration v36 — HOTFIX for log_activity() trigger
-- Fixes: creating a transaction failed with
--   ERROR: record "v_row" has no field "name"
-- Cause: plpgsql validates every record field reference when the
--   expression is prepared, even in CASE branches that don't match —
--   transactions has no "name" column, but the liabilities/accounts
--   branches referenced v_row.name. Reading through jsonb instead
--   makes a missing column simply NULL.
-- Run this whole file in the Supabase SQL Editor.
-- ============================================================

CREATE OR REPLACE FUNCTION log_activity() RETURNS trigger AS $$
DECLARE
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
