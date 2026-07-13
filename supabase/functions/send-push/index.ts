// send-push: delivers one push notification to every device a user has
// registered in fcm_tokens. Invoked by the meal_notification_push_dispatch
// trigger (v22 migration) whenever a row is inserted into meal_notifications
// (and later, finance_notifications — see the phased plan, Phase 3).
//
// Deploy: `supabase functions deploy send-push`
// Secrets required (set with `supabase secrets set`):
//   FIREBASE_PROJECT_ID           - Firebase project id
//   FIREBASE_SERVICE_ACCOUNT_JSON - full service-account JSON, as a string
//   FUNCTIONS_SHARED_SECRET       - must match app.settings.functions_secret
//                                    from the v22 migration (checked below so
//                                    this function can't be called by anyone
//                                    who doesn't know the DB trigger's secret)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY - auto-provided by the platform
import { createClient } from "npm:@supabase/supabase-js@2";

interface PushPayload {
  user_id: string;
  title: string;
  body?: string | null;
  link?: string | null;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${enc(header)}.${enc(claims)}`;

  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const encodedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const jwt = `${unsigned}.${encodedSig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  if (!res.ok) throw new Error(`OAuth token exchange failed: ${await res.text()}`);
  const { access_token, expires_in } = await res.json();
  cachedAccessToken = { token: access_token, expiresAt: Date.now() + expires_in * 1000 };
  return access_token;
}

Deno.serve(async (req) => {
  const sharedSecret = Deno.env.get("FUNCTIONS_SHARED_SECRET");
  const authHeader = req.headers.get("Authorization") ?? "";
  if (sharedSecret && authHeader !== `Bearer ${sharedSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = (await req.json()) as PushPayload;
  if (!payload.user_id || !payload.title) {
    return new Response("user_id and title are required", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: tokens, error } = await supabase
    .from("fcm_tokens")
    .select("id, token")
    .eq("user_id", payload.user_id);
  if (error) return new Response(error.message, { status: 500 });
  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const accessToken = await getAccessToken();
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const invalidTokenIds: string[] = [];
  let sent = 0;

  for (const row of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title: payload.title, body: payload.body ?? "" },
            data: { link: payload.link ?? "" },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else {
      const err = await res.json().catch(() => null);
      const status = err?.error?.status;
      if (status === "NOT_FOUND" || status === "UNREGISTERED" || status === "INVALID_ARGUMENT") {
        invalidTokenIds.push(row.id);
      }
    }
  }

  if (invalidTokenIds.length > 0) {
    await supabase.from("fcm_tokens").delete().in("id", invalidTokenIds);
  }

  return new Response(JSON.stringify({ sent, cleaned: invalidTokenIds.length }), { status: 200 });
});
