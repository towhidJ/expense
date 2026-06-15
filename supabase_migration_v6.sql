-- Migration Script V6: Document Attachments (Storage + linking)
-- Adds a storage bucket for documents and extends the attachments table
-- so files can be linked to transactions (income/expense) AND liabilities (loans).

-- 1. Storage bucket for documents (public read, owner-only write)
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS policies. Files are stored under a folder named after the user id:
--    documents/<user_id>/<filename>
DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
CREATE POLICY "Users can upload their own documents" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can view their own documents" ON storage.objects;
CREATE POLICY "Users can view their own documents" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
CREATE POLICY "Users can delete their own documents" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'documents' AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. Allow attachments to reference a liability and store the storage path
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='liability_id') THEN
        ALTER TABLE attachments ADD COLUMN liability_id UUID REFERENCES liabilities(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='attachments' AND column_name='storage_path') THEN
        ALTER TABLE attachments ADD COLUMN storage_path TEXT;
    END IF;
END $$;

-- 4. Make transaction_id nullable (already nullable by default) and index lookups
CREATE INDEX IF NOT EXISTS idx_attachments_transaction ON attachments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_attachments_liability ON attachments(liability_id);
