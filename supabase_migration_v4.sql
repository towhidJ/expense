-- Migration Script V4: Entity Scoping for Goals and Categories

-- 1. Add entity_id to goals
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goals' AND column_name='entity_id') THEN
        ALTER TABLE goals ADD COLUMN entity_id UUID REFERENCES entities(id);
        -- Link existing goals to the user's primary 'personal' entity
        UPDATE goals SET entity_id = (SELECT id FROM entities WHERE entities.user_id = goals.user_id AND type = 'personal' LIMIT 1);
    END IF;
END $$;

-- 2. Add entity_id to categories
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='categories' AND column_name='entity_id') THEN
        ALTER TABLE categories ADD COLUMN entity_id UUID REFERENCES entities(id);
        -- Link existing categories to the user's primary 'personal' entity
        UPDATE categories SET entity_id = (SELECT id FROM entities WHERE entities.user_id = categories.user_id AND type = 'personal' LIMIT 1);
    END IF;
END $$;
