-- v19: Four more meal modules — bazar shopping list, shared bills (non-meal
-- expense splitter), meal calendar (UI-only, no schema), and an in-app
-- notification feed.
--   * Shopping list (meal_shopping_items): the pre-purchase "ki ki lagbe"
--     list. Any member adds items ("chal shesh", "tel lagbe"); whoever does
--     the bazar ticks them off, then converts the bought items into one
--     itemized meal_expense in a click. Converted rows keep expense_id so the
--     active list only shows unconverted items.
--   * Shared bills (meal_shared_expenses + _shares): rent, wifi, gas cylinder
--     — split equally or with custom amounts per member. Deliberately NOT part
--     of the meal month summary (that pot is meal-linked fixed costs); this is
--     a standalone ledger with per-member paid ticks. Manager-only writes;
--     created through create_shared_expense so the shares always sum to the
--     bill amount.
--   * Notifications (meal_notifications): one row per recipient, written by
--     AFTER triggers — new meal request → managers, request approved/rejected
--     → the requester, new notice → all members, new join request → managers.
--     The web app shows a bell with an unread badge; when real push (FCM) is
--     added later it can fan out from this same table.
-- Run this in the Supabase SQL Editor (after v18).

-- ---------- 1. Shopping list ----------

CREATE TABLE IF NOT EXISTS meal_shopping_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  qty TEXT, -- free text: "2 kg", "1 litre"
  is_bought BOOLEAN NOT NULL DEFAULT FALSE,
  bought_by UUID REFERENCES profiles(id),
  bought_at TIMESTAMPTZ,
  -- Set when the bought items are converted into a meal_expense; the active
  -- list only shows rows where this is NULL.
  expense_id UUID REFERENCES meal_expenses(id) ON DELETE SET NULL,
  added_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_meal_shopping_group ON meal_shopping_items(group_id, expense_id);

ALTER TABLE meal_shopping_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view shopping items" ON meal_shopping_items;
CREATE POLICY "Members can view shopping items" ON meal_shopping_items
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Members can add shopping items" ON meal_shopping_items;
CREATE POLICY "Members can add shopping items" ON meal_shopping_items
  FOR INSERT WITH CHECK (is_meal_group_member(group_id) AND added_by = auth.uid());
-- Anyone in the mess can tick items bought / fix a typo — it is a shared list
DROP POLICY IF EXISTS "Members can update shopping items" ON meal_shopping_items;
CREATE POLICY "Members can update shopping items" ON meal_shopping_items
  FOR UPDATE USING (is_meal_group_member(group_id))
  WITH CHECK (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Authors or managers can delete shopping items" ON meal_shopping_items;
CREATE POLICY "Authors or managers can delete shopping items" ON meal_shopping_items
  FOR DELETE USING (is_meal_group_manager(group_id) OR added_by = auth.uid());

-- ---------- 2. Shared bills (non-meal expense splitter) ----------

CREATE TABLE IF NOT EXISTS meal_shared_expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL, -- "Basha bhara July", "Wifi bill"
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date DATE NOT NULL,
  split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'custom')),
  note TEXT,
  added_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meal_shared_expense_shares (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  shared_expense_id UUID REFERENCES meal_shared_expenses(id) ON DELETE CASCADE NOT NULL,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  member_id UUID REFERENCES meal_group_members(id) NOT NULL,
  share_amount NUMERIC NOT NULL CHECK (share_amount >= 0),
  paid BOOLEAN NOT NULL DEFAULT FALSE,
  paid_at TIMESTAMPTZ,
  UNIQUE (shared_expense_id, member_id)
);
CREATE INDEX IF NOT EXISTS idx_meal_shared_group_date ON meal_shared_expenses(group_id, date);
CREATE INDEX IF NOT EXISTS idx_meal_shared_shares_expense ON meal_shared_expense_shares(shared_expense_id);

ALTER TABLE meal_shared_expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view shared expenses" ON meal_shared_expenses;
CREATE POLICY "Members can view shared expenses" ON meal_shared_expenses
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can delete shared expenses" ON meal_shared_expenses;
CREATE POLICY "Managers can delete shared expenses" ON meal_shared_expenses
  FOR DELETE USING (is_meal_group_manager(group_id));
-- inserts go through create_shared_expense (validates the share split)

ALTER TABLE meal_shared_expense_shares ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can view shared expense shares" ON meal_shared_expense_shares;
CREATE POLICY "Members can view shared expense shares" ON meal_shared_expense_shares
  FOR SELECT USING (is_meal_group_member(group_id));
DROP POLICY IF EXISTS "Managers can update shared expense shares" ON meal_shared_expense_shares;
CREATE POLICY "Managers can update shared expense shares" ON meal_shared_expense_shares
  FOR UPDATE USING (is_meal_group_manager(group_id))
  WITH CHECK (is_meal_group_manager(group_id));
-- inserts via RPC; rows go away with the bill (ON DELETE CASCADE)

-- One bill + its per-member shares, atomically. p_shares is
-- [{"member_id": "...", "amount": 123.5}, ...] and must sum to p_amount
-- (±1 taka for rounding an equal split).
CREATE OR REPLACE FUNCTION create_shared_expense(
  p_group_id UUID,
  p_title TEXT,
  p_amount NUMERIC,
  p_date DATE,
  p_split_type TEXT,
  p_shares JSONB,
  p_note TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_expense_id UUID;
  v_share JSONB;
  v_sum NUMERIC := 0;
  v_member_id UUID;
  v_share_amount NUMERIC;
BEGIN
  IF NOT is_meal_group_manager(p_group_id) THEN
    RAISE EXCEPTION 'Only a manager can add shared bills';
  END IF;
  IF p_title IS NULL OR TRIM(p_title) = '' THEN
    RAISE EXCEPTION 'Title is required';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;
  IF p_split_type NOT IN ('equal', 'custom') THEN
    RAISE EXCEPTION 'Invalid split type: %', p_split_type;
  END IF;
  IF p_shares IS NULL OR jsonb_array_length(p_shares) = 0 THEN
    RAISE EXCEPTION 'At least one member share is required';
  END IF;

  FOR v_share IN SELECT * FROM jsonb_array_elements(p_shares) LOOP
    v_share_amount := COALESCE((v_share->>'amount')::NUMERIC, 0);
    IF v_share_amount < 0 THEN
      RAISE EXCEPTION 'Share amounts cannot be negative';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM meal_group_members
      WHERE id = (v_share->>'member_id')::UUID AND group_id = p_group_id
    ) THEN
      RAISE EXCEPTION 'Share member not found in this group';
    END IF;
    v_sum := v_sum + v_share_amount;
  END LOOP;
  IF ABS(v_sum - p_amount) > 1 THEN
    RAISE EXCEPTION 'Shares (%) must add up to the bill amount (%)', v_sum, p_amount;
  END IF;

  INSERT INTO meal_shared_expenses (group_id, title, amount, date, split_type, note, added_by)
  VALUES (p_group_id, TRIM(p_title), p_amount, p_date, p_split_type,
          NULLIF(TRIM(COALESCE(p_note, '')), ''), auth.uid())
  RETURNING id INTO v_expense_id;

  FOR v_share IN SELECT * FROM jsonb_array_elements(p_shares) LOOP
    v_member_id := (v_share->>'member_id')::UUID;
    v_share_amount := COALESCE((v_share->>'amount')::NUMERIC, 0);
    IF v_share_amount > 0 THEN
      INSERT INTO meal_shared_expense_shares
        (shared_expense_id, group_id, member_id, share_amount)
      VALUES (v_expense_id, p_group_id, v_member_id, v_share_amount);
    END IF;
  END LOOP;

  RETURN v_expense_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 3. In-app notifications ----------

CREATE TABLE IF NOT EXISTS meal_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES meal_groups(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) NOT NULL, -- recipient
  type TEXT NOT NULL, -- 'request_new' | 'request_response' | 'notice' | 'join_request'
  title TEXT NOT NULL,
  body TEXT,
  link TEXT, -- app route, e.g. /meals/requests
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_meal_notifications_user
  ON meal_notifications(user_id, is_read, created_at);

ALTER TABLE meal_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own notifications" ON meal_notifications;
CREATE POLICY "Users can view own notifications" ON meal_notifications
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can mark own notifications read" ON meal_notifications;
CREATE POLICY "Users can mark own notifications read" ON meal_notifications
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can delete own notifications" ON meal_notifications;
CREATE POLICY "Users can delete own notifications" ON meal_notifications
  FOR DELETE USING (user_id = auth.uid());
-- inserts come from the triggers below (definer functions)

-- Fan a notification out to every approved manager of a group
CREATE OR REPLACE FUNCTION notify_meal_managers(
  p_group_id UUID, p_type TEXT, p_title TEXT, p_body TEXT, p_link TEXT,
  p_skip_user UUID DEFAULT NULL
) RETURNS VOID AS $$
  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  SELECT p_group_id, user_id, p_type, p_title, p_body, p_link
  FROM meal_group_members
  WHERE group_id = p_group_id AND role = 'manager' AND status = 'approved'
    AND (p_skip_user IS NULL OR user_id <> p_skip_user);
$$ LANGUAGE sql SECURITY DEFINER;

-- New meal request → notify the managers
CREATE OR REPLACE FUNCTION trg_notify_meal_request_new() RETURNS TRIGGER AS $$
DECLARE
  v_name TEXT;
BEGIN
  SELECT display_name INTO v_name FROM meal_group_members WHERE id = NEW.member_id;
  PERFORM notify_meal_managers(
    NEW.group_id, 'request_new',
    'New meal request',
    v_name || ' requested ' ||
      CASE WHEN NEW.type = 'off' THEN 'meal off' ELSE 'a guest meal' END ||
      ' for ' || TO_CHAR(NEW.date, 'DD Mon'),
    '/meals/requests',
    (SELECT user_id FROM meal_group_members WHERE id = NEW.member_id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_request_new_notify ON meal_requests;
CREATE TRIGGER meal_request_new_notify
  AFTER INSERT ON meal_requests
  FOR EACH ROW EXECUTE FUNCTION trg_notify_meal_request_new();

-- Request approved/rejected → notify the requester
CREATE OR REPLACE FUNCTION trg_notify_meal_request_response() RETURNS TRIGGER AS $$
DECLARE
  v_user UUID;
BEGIN
  IF NEW.status IN ('approved', 'rejected') AND OLD.status = 'pending' THEN
    SELECT user_id INTO v_user FROM meal_group_members WHERE id = NEW.member_id;
    INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
    VALUES (NEW.group_id, v_user, 'request_response',
      'Meal request ' || NEW.status,
      'Your ' || CASE WHEN NEW.type = 'off' THEN 'meal off' ELSE 'guest meal' END ||
        ' request for ' || TO_CHAR(NEW.date, 'DD Mon') || ' was ' || NEW.status,
      '/meals/requests');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_request_response_notify ON meal_requests;
CREATE TRIGGER meal_request_response_notify
  AFTER UPDATE ON meal_requests
  FOR EACH ROW EXECUTE FUNCTION trg_notify_meal_request_response();

-- New notice → notify every approved member except the author
CREATE OR REPLACE FUNCTION trg_notify_meal_notice() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO meal_notifications (group_id, user_id, type, title, body, link)
  SELECT NEW.group_id, user_id, 'notice', 'Notice: ' || NEW.title,
         LEFT(COALESCE(NEW.body, ''), 140), '/meals/notices'
  FROM meal_group_members
  WHERE group_id = NEW.group_id AND status = 'approved' AND user_id <> NEW.created_by;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_notice_notify ON meal_notices;
CREATE TRIGGER meal_notice_notify
  AFTER INSERT ON meal_notices
  FOR EACH ROW EXECUTE FUNCTION trg_notify_meal_notice();

-- New join request → notify the managers
CREATE OR REPLACE FUNCTION trg_notify_meal_join_request() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' AND (TG_OP = 'INSERT' OR OLD.status <> 'pending') THEN
    PERFORM notify_meal_managers(
      NEW.group_id, 'join_request',
      'New join request',
      NEW.display_name || ' wants to join the mess',
      '/meals/members',
      NEW.user_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS meal_join_request_notify ON meal_group_members;
CREATE TRIGGER meal_join_request_notify
  AFTER INSERT OR UPDATE ON meal_group_members
  FOR EACH ROW EXECUTE FUNCTION trg_notify_meal_join_request();
