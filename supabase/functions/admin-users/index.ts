// admin-users: service-role admin operations that RLS/anon clients cannot do.
// Routes on a body `action` field:
//   list_users   - all accounts (email + last sign-in from auth.users, merged
//                  with profiles and user_subscriptions)
//   set_password - set a temporary password for a user (admin support flow;
//                  manual bKash/Nagad market, email resets are unreliable)
//   toggle_admin - grant/revoke the is_admin flag
//
// Auth: the caller's JWT is verified via auth.getUser(), then profiles.is_admin
// is re-checked with the service-role client before any auth.admin call.
//
// Deploy: `supabase functions deploy admin-users`
//   SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY - auto-provided
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

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

function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

async function listUsers(service: SupabaseClient) {
  // auth.users is paged; loop until a short page.
  const authUsers: any[] = [];
  for (let page = 1; ; page++) {
    const { data, error } = await service.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    authUsers.push(...data.users);
    if (data.users.length < 1000) break;
  }

  const [{ data: profiles }, { data: subs }] = await Promise.all([
    service.from("profiles").select("id, full_name, is_admin, created_at"),
    service.from("user_subscriptions").select("user_id, expires_at, started_at, is_trial"),
  ]);
  const profileById = new Map((profiles ?? []).map((p: any) => [p.id, p]));
  const subById = new Map((subs ?? []).map((s: any) => [s.user_id, s]));

  return authUsers
    .map((u) => {
      const p = profileById.get(u.id);
      const s = subById.get(u.id);
      const active = !!s && (s.expires_at === null || new Date(s.expires_at) > new Date());
      return {
        id: u.id,
        email: u.email,
        full_name: p?.full_name ?? null,
        is_admin: p?.is_admin ?? false,
        created_at: u.created_at,
        last_sign_in_at: u.last_sign_in_at,
        sub: s
          ? { active, lifetime: active && s.expires_at === null, expires_at: s.expires_at, is_trial: !!s.is_trial }
          : null,
      };
    })
    .sort((a, b) => (b.created_at ?? "").localeCompare(a.created_at ?? ""));
}

async function setPassword(
  service: SupabaseClient,
  callerId: string,
  body: any,
) {
  const userId = String(body.user_id ?? "");
  const newPassword = String(body.new_password ?? "");
  if (!userId) throw new Error("user_id is required");
  if (newPassword.length < 6) throw new Error("Password must be at least 6 characters");

  // Never reset ANOTHER admin's password from here — a compromised admin
  // session must not be able to quietly seize other admin accounts. Admins
  // reset each other via the Supabase dashboard only.
  if (userId !== callerId) {
    const { data: target } = await service
      .from("profiles").select("is_admin").eq("id", userId).maybeSingle();
    if (target?.is_admin) throw new Error("Cannot reset another admin's password here");
  }

  const { error } = await service.auth.admin.updateUserById(userId, {
    password: newPassword,
  });
  if (error) throw error;
  return { ok: true };
}

async function toggleAdmin(
  service: SupabaseClient,
  callerId: string,
  body: any,
) {
  const userId = String(body.user_id ?? "");
  const makeAdmin = !!body.make_admin;
  if (!userId) throw new Error("user_id is required");
  // Can't demote yourself — guarantees at least one admin remains.
  if (userId === callerId && !makeAdmin) {
    throw new Error("You cannot remove your own admin access");
  }
  const { error } = await service
    .from("profiles").update({ is_admin: makeAdmin }).eq("id", userId);
  if (error) throw error;
  return { ok: true };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await anon.auth.getUser();
  if (!user) return json({ error: "Unauthorized" }, 401);

  const service = serviceClient();
  const { data: me } = await service
    .from("profiles").select("is_admin").eq("id", user.id).maybeSingle();
  if (!me?.is_admin) return json({ error: "Admins only" }, 403);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  try {
    switch (body.action) {
      case "list_users":
        return json({ users: await listUsers(service) });
      case "set_password":
        return json(await setPassword(service, user.id, body));
      case "toggle_admin":
        return json(await toggleAdmin(service, user.id, body));
      default:
        return json({ error: `Unknown action: ${body.action}` }, 400);
    }
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
