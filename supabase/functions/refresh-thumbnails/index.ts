// plan.md "Metadata Refresh Job" (RefreshTikTokMetadataJob), adapted to
// Supabase: for each restaurant image not yet cached, download the thumbnail
// (re-fetching a fresh URL from TikTok's official oEmbed endpoint when the
// stored one has expired), store the bytes in the public restaurant-images
// bucket, and repoint the row's url at the permanent Storage URL.
//
// Deliberate deviation from plan.md's refresh-the-temporary-URL model: we
// re-host thumbnail bytes permanently (plan.md only forbids re-hosting
// *videos*). Consequence: url never expires; source_expires_at describes the
// temporary TikTok source_url only and does not govern url validity.
//
// The stable identity is restaurants.video_url / the TikTok video id — it is
// never replaced here (plan.md rule 6). TikTok CDN URLs are only ever kept as
// source_url: temporary cache data.
//
// Auth: verify_jwt is off because clients never call this; callers must send
// x-refresh-key matching THUMBNAIL_REFRESH_KEY (function secret) or, as a
// fallback, the vault secret `thumbnail_refresh_key` read via the
// service-role-only RPC get_thumbnail_refresh_key. The vault value is
// memoized so rejected requests don't drive per-request Postgres work.
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const ALLOWED_STATUSES = ["pending", "stale", "failed"];
const MAX_REFRESH_ATTEMPTS = 6;
const KEY_CACHE_TTL_MS = 10 * 60 * 1000;

class RateLimitedError extends Error {}

let cachedKey: { value: string | null; fetchedAt: number } | null = null;

async function expectedKey(): Promise<string | null> {
  const envKey = Deno.env.get("THUMBNAIL_REFRESH_KEY");
  if (envKey) return envKey;
  const now = Date.now();
  if (cachedKey && now - cachedKey.fetchedAt < KEY_CACHE_TTL_MS) {
    return cachedKey.value;
  }
  const { data, error } = await supabase.rpc("get_thumbnail_refresh_key");
  const value = !error && typeof data === "string" && data ? data : null;
  cachedKey = { value, fetchedAt: now };
  return value;
}

async function authorized(req: Request): Promise<boolean> {
  const key = req.headers.get("x-refresh-key");
  if (!key) return false;
  const expected = await expectedKey();
  return expected !== null && expected === key;
}

function slugify(name: string): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "restaurant";
}

function extensionFor(contentType: string): string {
  if (contentType.includes("webp")) return "webp";
  if (contentType.includes("png")) return "png";
  if (contentType.includes("heic") || contentType.includes("heif")) return "heic";
  return "jpg";
}

function parseExpiry(url: string): string | null {
  const match = /x-expires=(\d+)/.exec(url);
  return match ? new Date(Number(match[1]) * 1000).toISOString() : null;
}

async function freshThumbnailUrl(videoUrl: string): Promise<string> {
  const res = await fetch(
    `https://www.tiktok.com/oembed?url=${encodeURIComponent(videoUrl)}`,
    { headers: { "User-Agent": "swipe-eat/1.0" } },
  );
  if (res.status === 429) throw new RateLimitedError("oembed rate limited");
  if (!res.ok) throw new Error(`oembed responded ${res.status}`);
  const data = await res.json();
  if (typeof data.thumbnail_url !== "string" || !data.thumbnail_url) {
    throw new Error("oembed returned no thumbnail_url");
  }
  return data.thumbnail_url;
}

Deno.serve(async (req: Request) => {
  if (!(await authorized(req))) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = await req.json().catch(() => ({}));
  const batch = Math.min(Math.max(Number(body.batch) || 20, 1), 25);
  const requested: string[] = Array.isArray(body.statuses)
    ? body.statuses.filter((s: unknown) =>
      typeof s === "string" && ALLOWED_STATUSES.includes(s)
    )
    : [];
  const statuses = requested.length ? requested : ALLOWED_STATUSES;

  const { data: rows, error } = await supabase
    .from("restaurant_images")
    .select(
      "id, url, source_url, position, restaurant_id, restaurants(name, video_url)",
    )
    .in("metadata_status", statuses)
    .lt("refresh_attempts", MAX_REFRESH_ATTEMPTS)
    .order("id", { ascending: true })
    .limit(batch);
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let cached = 0;
  let rateLimited = false;
  const failures: { id: number; error: string }[] = [];

  for (const row of rows ?? []) {
    try {
      const restaurant = row.restaurants as unknown as {
        name: string;
        video_url: string | null;
      };
      let source = row.source_url ?? row.url;
      let res = await fetch(source, {
        headers: { "User-Agent": "swipe-eat/1.0" },
      });
      if (res.status === 429) throw new RateLimitedError("source rate limited");
      if (!res.ok) {
        // Stored CDN URL expired: get a fresh one via official oEmbed.
        if (!restaurant?.video_url) {
          throw new Error(`source fetch ${res.status}, no video_url to refresh`);
        }
        source = await freshThumbnailUrl(restaurant.video_url);
        res = await fetch(source, { headers: { "User-Agent": "swipe-eat/1.0" } });
        if (res.status === 429) {
          throw new RateLimitedError("refreshed source rate limited");
        }
        if (!res.ok) throw new Error(`refreshed source fetch ${res.status}`);
      }

      const contentType = res.headers.get("content-type") ?? "";
      if (!contentType.startsWith("image/")) {
        // A 200 carrying HTML/JSON (CDN interstitial, WAF page) must never be
        // committed as a permanent "cached" image.
        throw new Error(`non-image content-type: ${contentType || "unknown"}`);
      }
      const bytes = new Uint8Array(await res.arrayBuffer());
      if (bytes.length === 0) throw new Error("empty image body");

      const path = `r${row.restaurant_id}-p${row.position}-${
        slugify(restaurant?.name ?? "restaurant")
      }.${extensionFor(contentType)}`;
      const { error: uploadError } = await supabase.storage
        .from("restaurant-images")
        .upload(path, bytes, {
          contentType,
          upsert: true,
          cacheControl: "31536000",
        });
      if (uploadError) throw new Error(`upload: ${uploadError.message}`);

      const publicUrl = supabase.storage
        .from("restaurant-images")
        .getPublicUrl(path).data.publicUrl;

      const { error: updateError } = await supabase
        .from("restaurant_images")
        .update({
          url: publicUrl,
          source_url: source,
          source_expires_at: parseExpiry(source),
          metadata_status: "cached",
          refresh_attempts: 0,
          last_synced_at: new Date().toISOString(),
        })
        .eq("id", row.id);
      if (updateError) throw new Error(`update: ${updateError.message}`);
      cached++;
    } catch (err) {
      if (err instanceof RateLimitedError) {
        // TikTok is throttling us: stop the whole batch and leave untouched
        // rows for the next scheduled run instead of marking them failed.
        rateLimited = true;
        failures.push({ id: row.id, error: String(err) });
        break;
      }
      failures.push({ id: row.id, error: String(err) });
      // Never let bookkeeping abort the batch or discard its accounting.
      const { error: failError } = await supabase
        .rpc("record_thumbnail_refresh_failure", { image_id: row.id })
        .then((r) => r, (e) => ({ error: { message: String(e) } }));
      if (failError) {
        failures.push({ id: row.id, error: `failure update: ${failError.message}` });
      }
    }
  }

  const { count: remaining } = await supabase
    .from("restaurant_images")
    .select("id", { count: "exact", head: true })
    .in("metadata_status", statuses)
    .lt("refresh_attempts", MAX_REFRESH_ATTEMPTS);

  return new Response(
    JSON.stringify({
      processed: rows?.length ?? 0,
      cached,
      failures,
      rateLimited,
      remaining,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
