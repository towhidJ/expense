-- v21: Workspace (entity) delete.
-- Renaming a workspace is a plain RLS-guarded UPDATE (policy exists since v2),
-- but deleting needs an RPC: the entity-scoped tables reference entities(id)
-- WITHOUT ON DELETE CASCADE, so a bare DELETE would hit FK violations.
-- delete_entity wipes every child table in FK-safe order (rows that reference
-- other children go first: attachments/repayments/purchases before
-- transactions, transactions before categories/accounts) and refuses to
-- remove the user's last workspace so the app never ends up entity-less.
-- Run this in the Supabase SQL Editor (after v20).

CREATE OR REPLACE FUNCTION delete_entity(p_entity_id UUID) RETURNS VOID AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM entities WHERE id = p_entity_id AND user_id = v_uid) THEN
    RAISE EXCEPTION 'Workspace not found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM entities WHERE user_id = v_uid AND id <> p_entity_id) THEN
    RAISE EXCEPTION 'Cannot delete your only workspace — create another one first';
  END IF;

  -- Children that reference other children go first
  DELETE FROM attachments      WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM loan_repayments  WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM bazar_purchases  WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM transfers        WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM transactions     WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM recurring_transactions WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM savings          WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM recurring_savings WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM saving_heads     WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM budgets          WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM goals            WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM investments      WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM liabilities      WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM family_members   WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM assets           WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM categories       WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM accounts         WHERE entity_id = p_entity_id AND user_id = v_uid;
  DELETE FROM net_worth_snapshots WHERE entity_id = p_entity_id AND user_id = v_uid;

  DELETE FROM entities WHERE id = p_entity_id AND user_id = v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
