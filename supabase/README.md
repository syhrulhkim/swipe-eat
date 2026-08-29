# Supabase backend

Project ref (production): `vpcldlhqpvunnuexecgn`.

## Thumbnail cache pipeline

TikTok CDN thumbnail URLs are signed and expire (~24h). The pipeline caches
the bytes in the public `restaurant-images` Storage bucket and repoints
`restaurant_images.url` at the permanent Storage URL. The stable identity is
always `restaurants.video_url` — it is never rewritten.

Components:

- `functions/refresh-thumbnails` — edge function; downloads each not-yet-cached
  thumbnail (re-fetching a fresh URL from TikTok's official oEmbed endpoint
  when the stored one has expired), uploads it to Storage, marks the row
  `cached`. Retries `failed` rows up to 6 attempts (`refresh_attempts`).
- pg_cron job `refresh-tiktok-thumbnails` — every 6 hours, POSTs `{"batch": 25}`
  to the function. Both the target URL and auth key are read from this
  environment's vault at run time; if either is missing the job logs a
  warning and does nothing.
- `restaurant_images.source_url` / `source_expires_at` — the temporary TikTok
  URL and its expiry. They do **not** govern `url`, which is permanent.

## Bootstrapping a new environment

The pipeline is inert until these secrets exist (by design — a fresh database
must never call production):

1. Create the vault secrets:

   ```sql
   select vault.create_secret('<random hex, e.g. openssl rand -hex 24>',
                              'thumbnail_refresh_key');
   select vault.create_secret(
     'https://<project-ref>.supabase.co/functions/v1/refresh-thumbnails',
     'thumbnail_refresh_url');
   ```

2. Deploy the function (config.toml pins `verify_jwt = false`; without it,
   deploys default the flag back to true and the cron caller gets 401s):

   ```
   supabase functions deploy refresh-thumbnails
   ```

3. Optional but preferred: also set the key as a function secret so auth
   never touches Postgres (the vault RPC is only the fallback):

   ```
   supabase secrets set THUMBNAIL_REFRESH_KEY=<same random hex>
   ```

To invoke manually, send the key in a header file (never inline a secret in a
command line): `curl -X POST <url> -H @header-file -H 'Content-Type: application/json' -d '{"batch":25}'`.

## Known limitation: seed.sql image URLs

`seed.sql` stores absolute production Storage URLs whose paths embed
production row ids (`r11`…`r293`). A fresh database therefore serves images
from the production bucket, and its own row ids will not match the path
convention. The trailing `update` in seed.sql marks these rows `cached` so
the cron never tries to re-download them. Re-scraping in that environment
will rewrite paths to its own ids, which is fine — the convention is
cosmetic, `restaurant_images.url` is the source of truth.
