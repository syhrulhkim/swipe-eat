Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Swipe-Deck.md](Swipe-Deck.md), [Restaurant-Data.md](Restaurant-Data.md), [Backend-Schema.md](Backend-Schema.md), [History/improvement-plan.md](../History/improvement-plan.md)

# TikTok Video & Thumbnails

The video *is* the card. 1,606 of 1,607 restaurants carry a `video_url`, and
the deck's whole premise is that you decide by watching food, not by reading a
listing.

Files: `lib/features/restaurants/data/tiktok_player_factory.dart`,
`state/tiktok_player_cache.dart`, `presentation/tiktok_player.dart`,
`lib/core/ui/tiktok_thumbnail_placeholder.dart`,
`supabase/functions/refresh-thumbnails/`.

## 1. Why an embed and not a video player

TikTok clips are licensed **through TikTok's own player**. The app embeds
`https://www.tiktok.com/player/v1/<id>` in a WebView rather than downloading or
re-hosting the media, because their developer terms require it (D4). Every
constraint below follows from that one decision — the app is driving someone
else's player inside a browser it does not control.

`restaurants.video_url` is the **stable identity** of a row. It is never
rewritten, and `tiktok_video_id(video_url)` (an immutable SQL function) parses
the post id out of it — that id increases with post time, which is also the
deck ranker's freshness signal.

When no video id can be read out of a URL, the player falls back to loading the
URL itself.

## 2. The player handle

`TikTokPlayer` is a WebView controller **plus a load status**, which is the
core lesson of the rewrite. The controller alone cannot answer "did this
work?": a load that fails after the controller is built — no network, a pulled
clip, a geo-blocked post — leaves a black rectangle and throws nothing.

```
enum TikTokPlayerStatus { loading, ready, failed }
```

- `loading` — the view shows a spinner.
- `ready` — the player document finished loading.
- `failed` — the main frame failed; **the view offers a retry**.

`reload()` is both the initial load and the retry path, so it resets `status`
rather than assuming it is still `loading`. The document is kept on the handle
so a retry does not recompute it.

`release()` stops a player without destroying it. `WebViewController` has no
`dispose` in webview_flutter 4.x — the native view goes when the widget and the
controller are both unreferenced — so an evicted player would keep its audio
and its network going until the collector arrives. Release navigates it to a
blank page first.

### Platform specifics

- **iOS**: `allowsInlineMediaPlayback: true` and empty
  `mediaTypesRequiringUserAction`, so a clip plays inline without a tap.
- **Android**: blocks playback started by script or by an `autoplay`
  attribute, and needs its own handling.
- Navigation is restricted to **TikTok's own hosts**, plus the blank page an
  evicted player is parked on. A card must not become a browser.

## 3. Warming and the bounded cache

Creating a WebView and loading the player costs about **a second** — the
difference between a clip already running when the card lands and one that
starts as a black rectangle. So players are warmed ahead.

`TikTokPlayerCache` is **bounded at 5**, kept in least-recently-warmed order,
evicting the oldest when a new one pushes past capacity.

The number is reasoned, not guessed: the deck warms **three** cards ahead and
mounts at most **two**, and every build re-asks for the mounted ones (which
moves them back to the front). Five is comfortably above that, so **the player
the user is watching is never the one evicted**.

The bound matters because a WebView is expensive to hold. Without it, a long
session ends with one live player per card swiped, each still holding its
native view — which is the leak the earlier build had.

`playerFor(url)` returns null for a card with no clip, so callers can pass a
nullable URL straight through instead of branching.

Only the **foreground** card mounts a WebView; the card behind it shows a
static thumbnail. Two videos never run at once.

## 4. Display modes

- **In-card** — the webview is scaled slightly and nudged down to crop
  TikTok's own UI chrome out of the card's frame, with a top gradient scrim for
  text legibility.
- **Full-screen** — plain full-bleed, opened on a card tap via a fade
  transition, with a close button and back handling.

The handover between the two is one of the three behaviours that needs a device
smoke test — it is not exercised by `flutter test`.

## 5. Thumbnails: the cache pipeline

TikTok CDN thumbnail URLs are **signed and expire in about 24 hours**. A card
that showed a photo yesterday would show a broken image today, so the bytes are
cached.

```
restaurant_images row (metadata_status = 'pending')
        ↓
pg_cron  refresh-tiktok-thumbnails  every 6h  →  POST {"batch": 25}
        ↓
edge function  refresh-thumbnails
        ↓
  stored source_url expired?  →  re-fetch from TikTok's official oEmbed endpoint
        ↓
  download bytes  →  upload to Storage bucket  restaurant-images  (public read)
        ↓
  repoint restaurant_images.url at the permanent Storage URL
  metadata_status = 'cached'
```

The state machine lives on `restaurant_images`:

| Column | Role |
|---|---|
| `url` | **Permanent.** The Storage URL once cached. Never governed by the two below |
| `source_url` | The temporary, signed TikTok CDN URL |
| `source_expires_at` | When that signature dies |
| `metadata_status` | `pending` / `cached` / `failed` |
| `refresh_attempts` | Capped at **6**, incremented by `record_thumbnail_refresh_failure` |
| `last_synced_at` | |

`config.toml` pins `verify_jwt = false` for this function — the cron caller has
no user JWT. Deploying without the config file defaults the flag back to true
and the job starts collecting 401s.

Auth is a shared key, read from a function secret
(`THUMBNAIL_REFRESH_KEY`) with the vault RPC `get_thumbnail_refresh_key` as
fallback. **The pipeline is inert until those secrets exist** — deliberately,
so a fresh database never calls production. Bootstrapping steps are in
`supabase/README.md`.

To invoke by hand, put the key in a header file; never inline a secret on a
command line.

## 6. Placeholders

`tiktok_thumbnail_placeholder.dart` renders what a card shows before its
thumbnail resolves — and, given only **287 images** exist for 1,607
restaurants, what most cards show permanently.

## 7. Known gaps

- **No lifecycle pause.** Warm players keep their document loaded when the app
  is backgrounded or the deck is not the visible tab. Bounded at 5, so it is a
  ceiling rather than a leak, but it is not zero.
- **287 of 1,607 rows have any image at all**, so the thumbnail pipeline is
  mostly idle and card galleries are mostly empty.
- **`seed.sql` stores absolute production Storage URLs** whose paths embed
  production row ids, so a fresh database serves images from the production
  bucket. The trailing `update` marks those rows `cached` so the cron never
  tries to re-download them. Cosmetic — `restaurant_images.url` is the source
  of truth.
- A geo-blocked or removed clip surfaces as `failed` + retry, which is honest
  but not recoverable — there is no per-restaurant "this video is gone" flag.

## 8. Out of scope

- **Hosting the video ourselves.** Prohibited by TikTok's terms (D4).
- **A non-TikTok video source.** The catalogue is defined by TikTok posts;
  a second source would be a different product.
- **Preloading beyond three cards ahead** — the cache bound exists precisely to
  stop that.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D4 | Video is embedded via TikTok's own player in a WebView, never downloaded or re-hosted — their developer terms require it. | locked 2026-08-22 |
| D37 | `restaurants.video_url` is the stable identity of a row and is never rewritten. | locked 2026-08-22 |
| D38 | A player handle carries an explicit load status; a WebView that fails silently must be able to offer a retry. | locked 2026-08-29 |
| D39 | The player cache is bounded at 5 — above the 3-warmed + 2-mounted working set, so the watched player is never evicted. | locked 2026-08-29 |
| D40 | Evicted players are navigated to a blank page, because webview_flutter 4.x has no `dispose`. | locked 2026-08-29 |
| D41 | Only the foreground card mounts a WebView; the card behind shows a thumbnail. | locked 2026-08-22 |
| D42 | Thumbnail bytes are cached into Storage and `url` repointed permanently, because TikTok CDN URLs expire in ~24h. | locked 2026-08-22 |
| D43 | The thumbnail pipeline stays inert without its vault secrets, so a fresh database cannot call production. | locked 2026-08-23 |
