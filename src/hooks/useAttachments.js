import { useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

const BUCKET = 'documents';

// Sanitize a filename so it's safe for a storage key
function safeName(name) {
  return name.replace(/[^a-zA-Z0-9._-]/g, '_');
}

export function useAttachments() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [uploading, setUploading] = useState(false);

  // Upload one file to storage and record it in the attachments table.
  // Pass exactly one of { transactionId, liabilityId, assetId } to link it,
  // or docCategory (Document Vault) for a standalone, unlinked document.
  const uploadAttachment = useCallback(async (file, { transactionId = null, liabilityId = null, assetId = null, docCategory = null, expiryDate = null, title = null } = {}) => {
    if (!file || !user) return null;
    setUploading(true);
    try {
      const path = `${user.id}/${Date.now()}_${safeName(file.name)}`;
      const { error: uploadError } = await supabase.storage
        .from(BUCKET)
        .upload(path, file, { cacheControl: '3600', upsert: false });
      if (uploadError) throw uploadError;

      const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(path);

      const { data, error } = await supabase
        .from('attachments')
        .insert({
          user_id: user.id,
          entity_id: currentEntity?.id || null,
          transaction_id: transactionId,
          liability_id: liabilityId,
          asset_id: assetId,
          doc_category: docCategory,
          expiry_date: expiryDate,
          title,
          file_name: file.name,
          file_url: urlData.publicUrl,
          storage_path: path,
          file_size: file.size,
          content_type: file.type
        })
        .select()
        .single();
      if (error) throw error;
      return data;
    } finally {
      setUploading(false);
    }
  }, [user, currentEntity]);

  // Upload several files for the same record
  const uploadMany = useCallback(async (files, link) => {
    if (!files || files.length === 0) return [];
    const results = [];
    for (const file of files) {
      results.push(await uploadAttachment(file, link));
    }
    return results;
  }, [uploadAttachment]);

  const fetchAttachments = useCallback(async ({ transactionId = null, liabilityId = null, assetId = null, vaultOnly = false } = {}) => {
    if (!user) return [];
    let query = supabase.from('attachments').select('*').eq('user_id', user.id);
    if (transactionId) query = query.eq('transaction_id', transactionId);
    if (liabilityId) query = query.eq('liability_id', liabilityId);
    if (assetId) query = query.eq('asset_id', assetId);
    if (vaultOnly) query = query.not('doc_category', 'is', null);
    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) {
      console.error('Error fetching attachments:', error);
      return [];
    }
    return data || [];
  }, [user]);

  const deleteAttachment = useCallback(async (attachment) => {
    if (!user) return;
    if (attachment.storage_path) {
      await supabase.storage.from(BUCKET).remove([attachment.storage_path]);
    }
    const { error } = await supabase
      .from('attachments')
      .delete()
      .eq('id', attachment.id)
      .eq('user_id', user.id);
    if (error) throw error;
  }, [user]);

  return { uploading, uploadAttachment, uploadMany, fetchAttachments, deleteAttachment };
}
