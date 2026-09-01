// Deletes the calling user's own account, for the "delete my account" path both
// stores require (Google Play "Data deletion" policy; App Store guideline 5.1.1
// (v) for any app that lets users create an account).
//
// Deleting the `auth.users` row is enough to remove every piece of personal
// data: `profiles.id` references `auth.users (id) on delete cascade`, and every
// user-scoped table (likes, preferences, quiz responses, …) cascades from
// `profiles`. `swipes.user_id` is `on delete set null` by design, so aggregate
// swipe counts survive with no link back to a person.
//
// Auth: verify_jwt stays on, so the platform rejects an unauthenticated call
// before this code runs. The user id comes from the caller's own token — never
// from the request body — so a valid token can only ever delete its own owner.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "missing_authorization" }, 401);
  }

  // Read the caller's identity through their own token, not the service role,
  // so an expired or revoked session cannot delete anything.
  const asCaller = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: caller, error: callerError } = await asCaller.auth.getUser();
  const userId = caller?.user?.id;
  if (callerError || !userId) {
    return json({ error: "invalid_session" }, 401);
  }

  const admin = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error("delete-account failed", userId, deleteError.message);
    return json({ error: "delete_failed" }, 500);
  }

  console.log("delete-account succeeded", userId);
  return json({ deleted: true }, 200);
});
