-- v8: Allow deleting assets that have linked transactions.
-- The original FK on transactions.asset_id had no ON DELETE rule,
-- so deleting an asset with linked expenses failed with a FK violation.
-- This makes the DB unlink transactions automatically (asset_id -> NULL).

ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_asset_id_fkey;
ALTER TABLE transactions
  ADD CONSTRAINT transactions_asset_id_fkey
  FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE SET NULL;
