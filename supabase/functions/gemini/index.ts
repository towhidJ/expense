// gemini: single edge function that powers every AI feature in the app.
// Routes on a body `action` field so one deployment serves all of them:
//   parse_transaction - free-text -> structured transaction fields
//   parse_receipt     - receipt/statement image -> line items (vision)
//   insights          - aggregated finance numbers + question -> answer
//   meal_report       - meal RPC JSON -> conversational mess report
//
// Auth: the caller's Supabase JWT is verified (verify_jwt is on by default for
// edge functions) AND re-checked here via auth.getUser(), so every request is
// scoped to a logged-in user. The Gemini key never leaves the server.
//
// The Gemini key is stored in the `app_settings` table (managed from the web
// Admin panel, migration v32) and read here with the service-role key, which
// bypasses RLS. It falls back to a GEMINI_API_KEY env secret if present.
//
// Deploy: `supabase functions deploy gemini`
//   SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY - auto-provided
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "gemini-2.5-flash";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// Resolve the Gemini key from app_settings (service-role read, bypasses RLS),
// falling back to an env secret. Cached briefly so key changes from the Admin
// panel take effect within a few minutes without a DB hit on every request.
let keyCache: { key: string; expiresAt: number } | null = null;

async function getGeminiKey(): Promise<string> {
  if (keyCache && keyCache.expiresAt > Date.now()) return keyCache.key;

  let key = "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (serviceRole) {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, serviceRole);
    const { data } = await admin
      .from("app_settings")
      .select("value")
      .eq("key", "gemini_api_key")
      .maybeSingle();
    key = data?.value ?? "";
  }
  if (!key) key = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!key) throw new Error("Gemini API key is not configured");

  keyCache = { key, expiresAt: Date.now() + 5 * 60_000 };
  return key;
}

// Call Gemini and return the parsed JSON object it produced. `parts` lets a
// caller mix text and inline image data. `schema` constrains the output so we
// always get parseable JSON instead of prose.
async function callGemini(
  systemPrompt: string,
  parts: unknown[],
  schema: unknown,
): Promise<unknown> {
  const key = await getGeminiKey();

  const res = await fetch(`${GEMINI_URL}?key=${key}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents: [{ role: "user", parts }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: "application/json",
        ...(schema ? { responseSchema: schema } : {}),
      },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini returned no content");
  return JSON.parse(text);
}

const todayISO = () => new Date().toISOString().split("T")[0];

// ---- action handlers --------------------------------------------------------

async function parseTransaction(body: any) {
  const categories = Array.isArray(body.categories) ? body.categories : [];
  const accounts = Array.isArray(body.accounts) ? body.accounts : [];
  const catList = categories
    .map((c: any) => `${c.id} = ${c.name} (${c.type})`)
    .join("\n");
  const accList = accounts.map((a: any) => `${a.id} = ${a.name}`).join("\n");

  const system =
    `You extract a single personal-finance transaction from a short note. ` +
    `The note may be in Bangla, English, or Banglish (romanized Bangla). ` +
    `Amounts are in Bangladeshi Taka. Today is ${todayISO()}.\n\n` +
    `Resolve relative dates: "aj"/"today" = today, "gtokal"/"gotokal"/"yesterday" = ` +
    `yesterday, "porshu" = day before yesterday. Output date as YYYY-MM-DD.\n\n` +
    `Pick the single best matching category_id and account_id from these lists. ` +
    `If nothing fits, return an empty string for that field.\n\n` +
    `Categories:\n${catList || "(none)"}\n\nAccounts:\n${accList || "(none)"}`;

  const schema = {
    type: "object",
    properties: {
      type: { type: "string", enum: ["expense", "income"] },
      category_id: { type: "string" },
      account_id: { type: "string" },
      amount: { type: "number" },
      description: { type: "string" },
      date: { type: "string" },
    },
    required: ["type", "amount", "date"],
  };

  const result = await callGemini(
    system,
    [{ text: String(body.text ?? "") }],
    schema,
  );
  return { result };
}

async function parseReceipt(body: any) {
  const image = String(body.image ?? "");
  const mime = String(body.mimeType ?? "image/jpeg");
  if (!image) throw new Error("image (base64) is required");

  const system =
    `You read a receipt or bank/mobile-money statement image and extract every ` +
    `purchase/transaction line. Amounts are Bangladeshi Taka. Today is ${todayISO()}. ` +
    `For each line give amount, a short description, date (YYYY-MM-DD; use the ` +
    `receipt/statement date, else today), and a suggested_category guess. Set ` +
    `type to "income" only for clear credits/deposits, otherwise "expense".`;

  const schema = {
    type: "object",
    properties: {
      items: {
        type: "array",
        items: {
          type: "object",
          properties: {
            type: { type: "string", enum: ["expense", "income"] },
            amount: { type: "number" },
            description: { type: "string" },
            date: { type: "string" },
            suggested_category: { type: "string" },
          },
          required: ["amount", "description", "date"],
        },
      },
    },
    required: ["items"],
  };

  const result = await callGemini(
    system,
    [
      { text: "Extract all line items from this image." },
      { inlineData: { mimeType: mime, data: image } },
    ],
    schema,
  );
  return { result };
}

async function insights(body: any) {
  const question = String(body.question ?? "Give me a short financial summary.");
  const context = JSON.stringify(body.context ?? {});
  const system =
    `You are a concise personal-finance assistant for a Bangladeshi user ` +
    `(currency Taka, ৳). You are given aggregated numbers as JSON — never ask ` +
    `for raw data. Answer the user's question grounded ONLY in these numbers. ` +
    `Be specific with figures, keep it short (a few sentences or tight bullets), ` +
    `and give one actionable tip when useful.\n\nData:\n${context}`;

  const schema = {
    type: "object",
    properties: { answer: { type: "string" } },
    required: ["answer"],
  };

  const result = await callGemini(system, [{ text: question }], schema);
  return { result };
}

async function mealReport(body: any) {
  const summary = JSON.stringify(body.summary ?? {});
  const system =
    `You write a short, friendly monthly mess (shared-meal) report for a ` +
    `Bangladeshi household. Input is JSON from the meal-summary RPCs (meal rate, ` +
    `deposits, expenses, per-member balances, trends). Currency is Taka (৳). ` +
    `Summarize the meal rate, total bazar vs fixed costs, the top spender, and ` +
    `who should pay or receive money. Keep it conversational and brief.\n\n` +
    `Data:\n${summary}`;

  const schema = {
    type: "object",
    properties: { report: { type: "string" } },
    required: ["report"],
  };

  const result = await callGemini(
    system,
    [{ text: "Write the mess report." }],
    schema,
  );
  return { result };
}

// ---- entrypoint -------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  // Re-verify the caller so every request is tied to a real logged-in user.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "Unauthorized" }, 401);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  try {
    switch (body.action) {
      case "parse_transaction":
        return json(await parseTransaction(body));
      case "parse_receipt":
        return json(await parseReceipt(body));
      case "insights":
        return json(await insights(body));
      case "meal_report":
        return json(await mealReport(body));
      default:
        return json({ error: `Unknown action: ${body.action}` }, 400);
    }
  } catch (err) {
    console.error("gemini action failed:", err);
    return json({ error: String(err?.message ?? err) }, 500);
  }
});
