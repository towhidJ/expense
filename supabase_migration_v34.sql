-- v34: Dena-Paona (personal lending ledger).
-- Person-to-person loans reuse the existing liabilities machinery
-- (types loan_given / loan_taken + process_new_loan / process_loan_repayment
-- RPCs, which already move account balances in the right direction).
-- This migration only adds a counterparty column so the new /lending page
-- can group multiple loans + repayments under one person. Loans without a
-- counterparty keep living on the Liabilities page (bank loans, EMIs, etc.).
-- Run this file in the Supabase SQL Editor.

ALTER TABLE liabilities ADD COLUMN IF NOT EXISTS counterparty TEXT;

-- Grouping/filter happens per entity on the lending page.
CREATE INDEX IF NOT EXISTS idx_liabilities_counterparty
  ON liabilities (entity_id, counterparty)
  WHERE counterparty IS NOT NULL;
