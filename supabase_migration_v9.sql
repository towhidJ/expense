-- v9: Fix liability type constraint.
-- The v2 table only allowed ('loan', 'credit_card', 'installment') but the UI
-- sends 'loan_taken' / 'loan_given', so saving those failed the CHECK constraint.
-- (This fix existed at the end of v3 but may never have been applied.)

ALTER TABLE liabilities DROP CONSTRAINT IF EXISTS liabilities_type_check;
ALTER TABLE liabilities ADD CONSTRAINT liabilities_type_check
  CHECK (type IN ('loan_taken', 'loan_given', 'credit_card', 'installment', 'loan'));
UPDATE liabilities SET type = 'loan_taken' WHERE type = 'loan';
