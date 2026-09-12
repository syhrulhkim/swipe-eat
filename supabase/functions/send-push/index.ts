// The one thing that talks to Firebase (D152).
//
// Called only by the `plan_members_notify` trigger, which POSTs
// `{type, plan_id, user_id}` with the vault's `push_key` in `x-push-key`.
// The payload carries the *changed row's* user id; who gets woken depends on
// the type, and the mapping is written into the trigger's header comment in
// `20260912100000_a_plan_can_reach_a_phone.sql` so the two cannot drift:
//
//   plan_invite    — a row was inserted at 'invited'   → tell that person
//   join_request   — a row was inserted at 'requested'  → tell the plan's owner
//   join_accepted  — 'requested' became 'going'        → tell that person
//
// Auth: verify_jwt is off because the caller is Postgres, not a signed-in
// client, and the shared secret is the whole of it — the same shape as
// `refresh-thumbnails`'s x-refresh-key. No key, no send; there is no fallback
// path that would let a caller without it reach a user's devices.
//
// FCM HTTP v1 rather than the retired legacy endpoint: a service account JSON
// in the `FCM_SERVICE_ACCOUNT` secret is signed into a JWT, exchanged for an
// OAuth2 access token, and the token is cached for its lifetime — one token
// exchange per cold start and per hour, not per push. APNs rides the same
// sender, so iOS needs no second code path here.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type Body = { type?: string; plan_id?: number; user_id?: string };

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

let cachedToken: { value: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT is not set");
  return JSON.parse(raw) as ServiceAccount;
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signingKey(pem: string): Promise<CryptoKey> {
  // The JSON carries a PKCS#8 PEM with literal \n already unescaped by
  // JSON.parse; strip the armour and the whitespace to get at the DER.
  const der = Uint8Array.from(
    atob(pem.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "")),
    (c) => c.charCodeAt(0),
  );
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // A minute of slack, so a token that expires mid-request is never used.
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const claim = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const encoder = new TextEncoder();
  const unsigned = `${
    base64url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })))
  }.${base64url(encoder.encode(JSON.stringify(claim)))}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      await signingKey(account.private_key),
      encoder.encode(unsigned),
    ),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(signature)}`,
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error(`token exchange ${res.status}: ${JSON.stringify(data)}`);
  }
  cachedToken = {
    value: data.access_token,
    expiresAt: now + (Number(data.expires_in) || 3600),
  };
  return cachedToken.value;
}

function whenLabel(planDate: string): string {
  // The date is a plain `date`; read it as UTC so the function's own timezone
  // cannot move the day the user chose on their phone.
  return new Intl.DateTimeFormat("en-GB", {
    weekday: "short",
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  }).format(new Date(`${planDate}T00:00:00Z`)).replace(",", "");
}

Deno.serve(async (req: Request) => {
  const expected = Deno.env.get("PUSH_KEY");
  if (!expected || req.headers.get("x-push-key") !== expected) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body: Body = await req.json().catch(() => ({}));
  const { type, plan_id: planId, user_id: rowUserId } = body;
  if (!type || !planId || !rowUserId) {
    return new Response(JSON.stringify({ error: "bad payload" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: plan, error: planError } = await supabase
    .from("plans")
    .select("id, owner_id, plan_date, restaurants(name)")
    .eq("id", planId)
    .maybeSingle();
  if (planError || !plan) {
    return new Response(
      JSON.stringify({ error: planError?.message ?? "no such plan" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  // join_request is the only one that travels the other way: the row belongs
  // to the person asking, and the person to wake is the plan's owner.
  const recipientId = type === "join_request" ? plan.owner_id : rowUserId;
  // …and the name in the copy is always the *other* party.
  const actorId = type === "join_request" ? rowUserId : plan.owner_id;
  if (recipientId === actorId) {
    return new Response(JSON.stringify({ skipped: "self" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: actor } = await supabase
    .from("profiles").select("name").eq("id", actorId).maybeSingle();
  const who = actor?.name ?? "A friend";
  const restaurant =
    (plan.restaurants as unknown as { name: string } | null)?.name ??
      "somewhere good";
  const when = whenLabel(plan.plan_date as string);

  const title = type === "plan_invite"
    ? `${who} invited you`
    : type === "join_request"
    ? `${who} asked to join`
    : `${who} said yes`;

  const { data: tokens } = await supabase
    .from("push_tokens").select("token").eq("user_id", recipientId);
  if (!tokens?.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no devices" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const account = serviceAccount();
  const bearer = await accessToken(account);
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  const dropped: string[] = [];
  for (const { token } of tokens) {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body: `${restaurant}, ${when}` },
          // Every value in an FCM data map must be a string, including the id
          // the app routes on.
          data: { type, plan_id: String(planId) },
        },
      }),
    });
    if (res.ok) {
      sent++;
      continue;
    }
    const err = await res.json().catch(() => ({}));
    const code = err?.error?.details?.find((d: { errorCode?: string }) =>
      d.errorCode
    )?.errorCode;
    // The device uninstalled, or the token was never ours. Keeping it means
    // pushing at nothing forever, so the row goes.
    if (code === "UNREGISTERED" || err?.error?.status === "INVALID_ARGUMENT") {
      await supabase.from("push_tokens").delete().eq("token", token);
      dropped.push(token);
    }
  }

  return new Response(JSON.stringify({ sent, dropped: dropped.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
