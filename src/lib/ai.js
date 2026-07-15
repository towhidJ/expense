import { supabase } from './supabase';

// All AI runs server-side in the `gemini` edge function; these helpers just
// invoke it. The user's JWT is attached automatically by the supabase client,
// so the Gemini key never touches the browser.

async function invoke(action, payload) {
  const { data, error } = await supabase.functions.invoke('gemini', {
    body: { action, ...payload },
  });
  if (error) {
    // supabase-js reports a generic "non-2xx" message; the real reason is in
    // the response body the function returned. Dig it out when available.
    let detail = error.message || 'AI request failed';
    try {
      const body = await error.context?.json?.();
      if (body?.error) detail = body.error;
    } catch { /* keep the generic message */ }
    throw new Error(detail);
  }
  if (data?.error) throw new Error(data.error);
  return data.result;
}

// Free text -> { type, category_id, account_id, amount, description, date }
export function parseTransaction(text, { categories = [], accounts = [] } = {}) {
  const slimCats = categories.map(c => ({ id: c.id, name: c.name, type: c.type }));
  const slimAccts = accounts.map(a => ({ id: a.id, name: a.name }));
  return invoke('parse_transaction', {
    text,
    categories: slimCats,
    accounts: slimAccts,
  });
}

// base64 image (no data: prefix) -> { items: [{ type, amount, description, date, suggested_category }] }
export function parseReceipt(imageBase64, mimeType = 'image/jpeg') {
  return invoke('parse_receipt', { image: imageBase64, mimeType });
}

// aggregated numbers + question -> { answer }
export function getInsights(context, question) {
  return invoke('insights', { context, question });
}

// meal RPC JSON -> { report }
export function getMealReport(summary) {
  return invoke('meal_report', { summary });
}
