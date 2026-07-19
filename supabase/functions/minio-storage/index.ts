// minio-storage: proxies file upload/delete to a self-hosted MinIO server so
// the MinIO access/secret key never reaches the browser or the mobile app.
// Downloads stay direct — each bucket's anonymous policy is set to
// download-only on the MinIO side (see deploy notes), so the returned
// publicUrl works with no auth, exactly like a Supabase public bucket.
//
// Two request shapes, both routed on `action` (query param or JSON field):
//   upload (web)    - ?action=upload&bucket=..&path=..&contentType=..
//                      body = raw file bytes (browser fetch, no base64 cost).
//   upload (mobile) - JSON body { action:'upload', bucket, path, contentType,
//                      base64 } — same base64-in-JSON shape the `gemini`
//                      function already uses for images from Dart.
//   delete           - JSON body { action:'delete', bucket, paths:[...] },
//                      from either platform. Returns { ok:true }.
//
// Bucket allowlist + permission:
//   documents     - any authenticated user (attachments, meal receipts)
//   app-manuals   - admin only (public user-manual PDFs)
//   app-releases  - admin only (APK OTA releases)
//
// Auth: caller's JWT verified via auth.getUser(); admin-only buckets re-check
// profiles.is_admin with the service-role client, same pattern as admin-users.
//
// Deploy: `supabase functions deploy minio-storage`
// Secrets (never commit these): `supabase secrets set MINIO_ENDPOINT=... MINIO_ACCESS_KEY=... MINIO_SECRET_KEY=...`
//   MINIO_ENDPOINT   - host only, e.g. storage.ruponti.com
//   MINIO_ACCESS_KEY / MINIO_SECRET_KEY
//   MINIO_USE_SSL    - "true" (default) or "false"
//   MINIO_REGION     - optional, defaults to "us-east-1"
import { createClient } from "npm:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch@1.0.20";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const BUCKETS: Record<string, "user" | "admin"> = {
  documents: "user",
  "app-manuals": "admin",
  "app-releases": "admin",
};

const MINIO_ENDPOINT = Deno.env.get("MINIO_ENDPOINT")!;
const MINIO_SSL = (Deno.env.get("MINIO_USE_SSL") ?? "true") !== "false";
const BASE = `${MINIO_SSL ? "https" : "http"}://${MINIO_ENDPOINT}`;

const aws = new AwsClient({
  accessKeyId: Deno.env.get("MINIO_ACCESS_KEY")!,
  secretAccessKey: Deno.env.get("MINIO_SECRET_KEY")!,
  service: "s3",
  region: Deno.env.get("MINIO_REGION") ?? "us-east-1",
});

// Encode each path segment separately so literal "/" stays a path separator.
function encodeKey(key: string): string {
  return key.split("/").map(encodeURIComponent).join("/");
}

function objectUrl(bucket: string, key: string): string {
  return `${BASE}/${bucket}/${encodeKey(key)}`;
}

function validPath(path: string): boolean {
  if (!path || path.length > 512) return false;
  if (path.startsWith("/") || path.includes("..")) return false;
  return true;
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const url = new URL(req.url);
  const isJson = (req.headers.get("content-type") ?? "").includes("application/json");
  const jsonBody: any = isJson ? await req.json() : null;
  const action = url.searchParams.get("action") ?? jsonBody?.action ?? "upload";

  const authHeader = req.headers.get("Authorization") ?? "";
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await anon.auth.getUser();
  if (!user) return json({ error: "Unauthorized" }, 401);

  const service = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  async function assertBucketAccess(bucket: string) {
    const level = BUCKETS[bucket];
    if (!level) throw new Error(`Unknown bucket: ${bucket}`);
    if (level === "admin") {
      const { data: me } = await service
        .from("profiles").select("is_admin").eq("id", user!.id).maybeSingle();
      if (!me?.is_admin) throw new Error("Admins only for this bucket");
    }
  }

  try {
    if (action === "delete") {
      const bucket = String(jsonBody?.bucket ?? "");
      const paths: string[] = Array.isArray(jsonBody?.paths) ? jsonBody.paths : [];
      await assertBucketAccess(bucket);
      for (const p of paths) {
        if (!validPath(p)) continue;
        const res = await aws.fetch(objectUrl(bucket, p), { method: "DELETE" });
        if (!res.ok && res.status !== 404) {
          throw new Error(`MinIO delete failed (${res.status}): ${await res.text()}`);
        }
      }
      return json({ ok: true });
    }

    if (action === "upload") {
      // Mobile sends JSON+base64; web sends raw bytes + query-param metadata
      // (no base64 inflation for the larger APK/PDF uploads).
      const bucket = String(jsonBody?.bucket ?? url.searchParams.get("bucket") ?? "");
      const path = String(jsonBody?.path ?? url.searchParams.get("path") ?? "");
      const contentType = String(
        jsonBody?.contentType ?? url.searchParams.get("contentType") ?? "application/octet-stream",
      );
      await assertBucketAccess(bucket);
      if (!validPath(path)) return json({ error: "Invalid path" }, 400);

      const bytes = jsonBody ? base64ToBytes(String(jsonBody.base64 ?? "")) : await req.arrayBuffer();
      const res = await aws.fetch(objectUrl(bucket, path), {
        method: "PUT",
        body: bytes,
        headers: { "Content-Type": contentType },
      });
      if (!res.ok) {
        throw new Error(`MinIO upload failed (${res.status}): ${await res.text()}`);
      }
      return json({ publicUrl: objectUrl(bucket, path) });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
