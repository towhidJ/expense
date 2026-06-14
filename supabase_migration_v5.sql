-- Migration Script V5: Investment metadata (purchase date & notes)

-- 1. Add purchase_date to investments
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='investments' AND column_name='purchase_date') THEN
        ALTER TABLE investments ADD COLUMN purchase_date DATE;
    END IF;
END $$;

-- 2. Add notes to investments
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='investments' AND column_name='notes') THEN
        ALTER TABLE investments ADD COLUMN notes TEXT;
    END IF;
END $$;
