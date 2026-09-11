Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Swipe-Deck.md](Swipe-Deck.md), [Restaurant-Data.md](Restaurant-Data.md), [Backend-Schema.md](Backend-Schema.md), [History/improvement-plan.md](../History/improvement-plan.md)

# TikTok Video & Thumbnails

> **How the sound works, as of 2026-09-10 (D122).** The URL is **always**
> `muted=0`, and the pill drives the volume by posting TikTok's documented
> `x-tiktok-player` message into the player document.
>
> The `muted` parameter cannot do this job, which is why two earlier attempts
> at "Tap for sound" produced no sound. Their docs define `muted=1` as "set the
> default volume to 0 **and prevent the user from changing the volume**", and
> `muted=0` as merely enabling the volume control — so `muted=1` refuses every
> later `unMute` for the life of the page, and reloading with `muted=0` gave
> the same silent clip, from the top, under a pill that had flipped to "Sound
> on". Verified against the live player.
>
> D89's "starts silent" is now enforced by posting `mute` from
> `onPageFinished`, which is also the re-apply for a tap that landed while the
> page was still loading. D4 still stands: this is the interface TikTok
> publishes for driving their embed, not a reach into their DOM. **Nothing
> reloads**, so the clip no longer restarts when the sound comes on.
>
> Two other things changed the same week: a tap anywhere else on the card opens
> the restaurant rather than a fullscreen player — the deck's fullscreen route
> is gone, the detail screen keeps its own — and the card scales the clip to
> *cover* its box rather than by a fixed 1.03, so TikTok's letterbox bars no
> longer show.

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

`load()` is both the initial load and the retry path, so it resets `status`
rather than assuming it is still `loading`. The document (`playerUrl`) is kept
on the handle so a retry does not recompute it, next to `videoUrl` — the clip
this player was built for.

### The sound

`muted` is a `ValueNotifier<bool>` on the handle, constructed **true** (D89).
The pill reads it and `setMuted(bool)` writes it, which is why the two can
never drift: there is one flag, not a widget's idea of one and a player's.

`setMuted` returns early when nothing changes, then calls `_postMuteState()`,
which runs

```js
window.postMessage({'x-tiktok-player':true, type:'unMute'}, '*')
```

in the page — `mute` or `unMute` off the flag — and **swallows whatever it
throws**. The page can be gone, blank or mid-navigation, and losing the sound
on a card the user is only looking at is not worth an error.

`onPageFinished` calls the same method. That is the enforcement of D89's
"starts silent" on any WebView where the autoplay gesture requirement is
switched off, and it is also the re-apply for a tap that beat the page:
`loadRequest` returns when the navigation *starts*, so the handle — and the
pill reading it — go live while the document is still coming.

`release()` sets `muted` back to true before navigating to `about:blank`, so a
handle that is warmed again later still starts silent however it got there.

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

And the detail screen does not build a sixth one. Opening a restaurant from
the deck hands the warmed handle over in the router's `extra` map, under
`kLentPlayerKey`, and the card drops its own `WebViewWidget` for as long as
the loan is out — one controller cannot be mounted in two of them, and the
card is invisible under an opaque route anyway (D150). The page knows it is
borrowing, so it does not release what it did not create. A deep link carries
no handle and the page loads its own, exactly as before.

`peek` is the cache's non-creating lookup, used for the loan and for reading a
clip's sound state at the moment of a swipe (D149) — it starts nothing and
does not count as a use, so asking about a card on its way out cannot evict
the card arriving behind it.

**Warming is conditional since D146.** When the user's autoplay setting says
not to play — "Never", or "On Wi-Fi only" off Wi-Fi — the deck asks the cache
for nothing at all: no warm-ahead, and no player for the foreground card
either. The card shows its cover and a **"Tap to play"** pill, and only that
tap calls `playerFor`. A whole session on mobile data can therefore cost zero
WebViews. See [Profile-Preferences.md](Profile-Preferences.md).

## 4. Display modes

`TikTokFraming { card, hero, fullscreen }`, in `tiktok_player.dart`. TikTok's
player letterboxes — it fits the 9:16 clip inside whatever box it is handed and
pads the rest black — so the framing is a decision about how much of that
padding the surface is willing to show.

| Mode | Nudge | Scale |
|---|---|---|
| `card` | `_kShift` 0.07 of the box height | `max(w / fittedWidth, (1 + 2·0.07) · h / fittedHeight)` |
| `hero` | the same nudge | 1.03 |
| `fullscreen` | none | none |

- **`card`** — the clip *covers* the card, so no bars show, and it is nudged
  down so its subject clears the title block; the scale is computed from the
  **fitted** size rather than guessed, because the nudge exposes more padding
  along the top. On a 360 × 620 card that lands at **1.14**, which a test pins
  to ±0.001. A zero or non-finite box falls back to 1.03. A top gradient scrim
  carries the text; the sound pill is **not** under it — it is the last child
  of the card's stack, in front of every layer, so it is both legible and the
  thing a tap in that corner reaches.
- **`hero`** — the same nudge and a flat 1.03, deliberately **no cover**. The
  detail hero is barely taller than it is wide, and covering a 9:16 clip in
  that box crops it to a two-times zoom on the middle of the frame.
- **`fullscreen`** — TikTok's player untouched: no nudge, no scale, no scrim.
  Opened from the detail screen's hero via a fade transition, with a close
  button and back handling. The deck's cards no longer route here; a card tap
  opens the restaurant.

`MutedHint` is **public** in `tiktok_player.dart` and shared by the card and
the hero — the two private copies that used to live one per surface are gone.

The card-to-fullscreen handover is one of the three behaviours that needs a
device smoke test — it is not exercised by `flutter test`.

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

- **No lifecycle pause.** A clip is **silenced, never paused**: the deck posts
  `mute` when the Swipe tab stops being active, when the detail screen opens
  and when a swiped card is disposed ([Swipe-Deck.md](Swipe-Deck.md) §6), but
  the player keeps its document loaded and keeps playing. Warm players do the
  same when the app is backgrounded. Bounded at 5, so it is a ceiling rather
  than a leak, but it is not zero.
- **Two stale comments about a reload that no longer happens**: the `MutedHint`
  docstring in `tiktok_player.dart` ("The tap reloads the player unmuted") and
  the comment over the pill in `swipe_card.dart`. The code is correct; the
  prose above it describes the pre-D122 behaviour.
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
| D150 | The deck **lends** its warmed player to the detail screen rather than letting it build a second WebView for the same clip; the card gives its own view up while the loan is out, and the borrower never releases what it did not create. | locked 2026-09-11 |
| D146 | Autoplay is a user setting, and "off" means the deck warms nothing — not that it warms a player and pauses it. A card the user never taps costs no WebView. | locked 2026-09-11 |
| D39 | The player cache is bounded at 5 — above the 3-warmed + 2-mounted working set, so the watched player is never evicted. | locked 2026-08-29 |
| D40 | Evicted players are navigated to a blank page, because webview_flutter 4.x has no `dispose`. | locked 2026-08-29 |
| D41 | Only the foreground card mounts a WebView; the card behind shows a thumbnail. | locked 2026-08-22 |
| D42 | Thumbnail bytes are cached into Storage and `url` repointed permanently, because TikTok CDN URLs expire in ~24h. | locked 2026-08-22 |
| D43 | The thumbnail pipeline stays inert without its vault secrets, so a fresh database cannot call production. | locked 2026-08-23 |
| D122 | "Tap for sound" drives TikTok's player through their **documented `x-tiktok-player` postMessage API** (`mute` / `unMute`), not through the URL. Their `muted` parameter cannot do it: `muted=1` pins the volume at 0 *and refuses every later unmute for the life of the page*, and `muted=0` only unlocks the volume control — so the old reload-with-`muted=0` produced a clip that was still silent, under a pill that said "Sound on". The player URL is now always `muted=0`; a clip still starts silent (D89) because the handle posts `mute` on `onPageFinished`. This is not a breach of D4: the message is the interface TikTok publishes for driving their embed, and no reload means the clip no longer restarts from the top. | locked 2026-09-10 |
