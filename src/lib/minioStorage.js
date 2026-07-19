import { supabase } from './supabase';

// All uploads/deletes proxy through the minio-storage edge function so the
// MinIO secret key never ships to the browser — see that function for the
// bucket allowlist and admin-only buckets. Downloads stay direct public URLs.
const FUNCTION_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/minio-storage`;

async function authHeaders(contentType) {
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error('Not signed in');
  return {
    Authorization: `Bearer ${token}`,
    apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
    'Content-Type': contentType,
  };
}

// Upload one file, returns the public URL (same shape as
// supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl).
export async function uploadToMinio(bucket, path, file, contentTypeOverride) {
  const contentType = contentTypeOverride || file.type || 'application/octet-stream';
  const headers = await authHeaders(contentType);
  const qs = new URLSearchParams({ action: 'upload', bucket, path, contentType });
  const res = await fetch(`${FUNCTION_URL}?${qs}`, { method: 'POST', headers, body: file });
  const body = await res.json();
  if (!res.ok) throw new Error(body.error || 'Upload failed');
  return body.publicUrl;
}

// Delete one or more objects (same shape as supabase.storage.from(bucket).remove(paths)).
export async function removeFromMinio(bucket, paths) {
  const headers = await authHeaders('application/json');
  const res = await fetch(`${FUNCTION_URL}?action=delete`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ bucket, paths }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || 'Delete failed');
  }
}
