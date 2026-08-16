# Dashboard Feature Spec

Source: `lib/features/dashboard/presentation/dashboard_page.dart`

## 1. Overview

Dashboard = post-login home. Bottom nav, 5 tab, `IndexedStack` keep state alive across switch.

Entry: `DashboardPage(authController)` at route `/dashboard` (see `lib/app/app_router.dart`). Wraps auth state via `AnimatedBuilder` on `AuthController`.

## 2. Navigation

Bottom nav bar (`_DashboardBottomNav`), floating pill container, 5 items:

| Index | Tab | Icon |
|---|---|---|
| 0 | Swipe | swipe_rounded |
| 1 | Explore | explore_rounded |
| 2 | Like | favorite_rounded |
| 3 | Quiz | quiz_rounded |
| 4 | Profile | person_rounded |

Selection state lives in `_DashboardShellState._selectedIndex`, no persistence across app restarts.

Related routes (`app_router.dart`):
- `/settings` — gear icon top-right of Swipe tab header.
- `/restaurant` (extra: `RestaurantDetailData` payload) — pushed from Explore/Like tab card tap.

## 3. Swipe tab (`_SwipeDeck`)

Core feature. Tinder-style card deck over a fixed local dataset (5 Batu Pahat food spots, hardcoded `_SwipeCardData`).

### 3.1 Card data (`_SwipeCardData`)
Fields: `title, tag, details, color, rating, latitude, longitude, reviewName, reviewText, reviews (List<_ReviewSnippet>), imageUrls (List<String>), videoUrl (String?)`.

### 3.2 Gesture / motion
- Drag via `GestureDetector` (`onPanStart/Update/End`) accumulates `_dragOffset`.
- Threshold ±110px on release → swipe out (like/dislike); else spring back (`_SwipeMotionType.settleBack`).
- Animation driven by single `AnimationController` (640ms) interpolating `_animationStartOffset → _animationEndOffset`, easing `easeInOutCubic`.
- Rotation = `dx / 900`. Like/Nope stamp opacity tied to `dragPercentage = |dx| / 260` clamped 0–1.
- Manual trigger via bottom action bar (Pass/Like) calls `_triggerAction` → same `_animateOut` path.
- Deck exhausted (`_index >= _cards.length`) → "No more cards" card with restart button resetting `_index = 0`.

### 3.3 Card content
- Media: TikTok video if `videoUrl` present (foreground card only — behind card in stack shows static image to save resources), else swipeable image gallery (tap left/right half to page through `imageUrls`).
- Bottom info panel (`_RestaurantInfoPanel`, frosted glass): tag pill, title, rating + distance pills, tap-to-expand reveals `details` + review carousel.
- Review carousel (`_ReviewCarousel`): horizontal `PageView` over `reviews`, dot indicator, blocks the swipe-deck's own pan gesture while user is scrolling reviews (`onReviewInteractionChanged`).
- Tapping the card (outside gallery paging / review carousel) opens full-screen `_TikTokPlayerScreen` if `videoUrl` present.

### 3.4 Distance
`Geolocator.distanceBetween(userPosition, cardPosition)`. **`_userPosition` is hardcoded via `_dummyUserPosition()`** (Peserai, Batu Pahat coords) — no real GPS permission/fetch wired up yet. Format: `<100m` → `"N m"`, `<100km` → `"N.N km"`, else `"100km +"`.

## 4. TikTok integration

Goal: embed TikTok video as card background using TikTok's official oEmbed player, playing muted-off/autoplay inline.

### 4.1 Stack
- `webview_flutter` + `webview_flutter_wkwebview` (pubspec.yaml).
- `_createTikTokPlayerController(videoUrl)`:
  - Extracts numeric video id from URL path (`_extractTikTokVideoId`, last all-digit path segment).
  - Builds player URL: `https://www.tiktok.com/player/v1/<id>?autoplay=1&controls=1&volume_control=1&muted=0&music_info=1&description=1&timestamp=1&rel=0&loop=1`.
  - Loads a local HTML shell (`_buildTikTokPlayerHtml`) embedding that URL in an `<iframe>`, base URL pinned to `https://www.tiktok.com` (required for TikTok embed to allow autoplay/CORS).
  - JS `postMessage` to iframe sends `unMute` + `play` commands ~400ms/1200ms after load (TikTok player message protocol, works around autoplay-muted default).
  - iOS: `WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true, mediaTypesRequiringUserAction: {})` so video plays inline without a user tap.
  - Custom mobile Safari user-agent string forced on all platforms.

### 4.2 Caching / preloading
- `_SwipeDeckState._tiktokPlayerCache: Map<String, Future<WebViewController>>` keyed by video URL — each URL only builds one `WebViewController` for the deck's lifetime.
- On `initState`: preload first 5 cards' videos (`_warmInitialTikTokPlayers`).
- On drag start / first pixel of movement: preload current + next 2 cards (`_warmNeighborTikTokPlayers`), so the next card's video is ready before it becomes visible.
- `_SwipeTikTokPlayer` widget consumes a `Future<WebViewController>` (shared, not rebuilt) via `FutureBuilder`; shows black box + spinner until ready.
- Behind-card (`isBehind: true`) never mounts a webview — avoids running 2 videos concurrently.

### 4.3 Display modes
- **In-card** (`applyCardFraming: true`): webview scaled 1.03x and nudged down 7% of height to crop TikTok's native UI chrome into the card's rounded frame; top gradient scrim overlaid for text legibility.
- **Full-screen** (`_TikTokPlayerScreen`, `applyCardFraming: false`): plain full-bleed webview, opened via `PageRouteBuilder` fade transition, close button top-right, `PopScope` back handling.

### 4.4 Known gaps (not implemented)
- No fallback UI if `_extractTikTokVideoId` fails to parse an id (falls back to raw `videoUrl`, likely broken player).
- No error/retry state if the webview fails to load (network error, TikTok embed blocked, video removed).
- No lifecycle pause — video keeps playing/loaded in cache map even when app is backgrounded or deck no longer visible (only bounded by which 5 cards were warmed).
- Autoplay-unmute relies on timed `postMessage` calls, not an ack from the iframe — can race on slow connections.

## 5. Explore tab

Static list (`_spotCards`, 3 entries) rendered as compact preview cards (`_SpotPreviewLayout.compact`), no swipe actions, tap → `/restaurant` detail page. Includes a non-functional search bar (UI only, no query wiring).

## 6. Like tab

Static "saved places" list (`_savedPlaces`, 2 entries), list-layout preview cards, tap → `/restaurant`. Not connected to any real like/save state — the Swipe tab's Like/Pass actions do not feed this list.

## 7. Quiz tab

Single hardcoded multiple-choice question (`_quizAnswers`, 3 options) with a static suggestion result card that doesn't actually change based on the selected answer (`_QuizResultCard` content is a constant regardless of `_selectedAnswer`).

## 8. Profile tab

Shows `authController.user` (name/email fallback to "Guest" / sign-in prompt) plus 3 static preference toggles (Morning mode, Spice bias, Nearby focus) — display-only, no persistence, no interaction wired.

## 9. Restaurant detail page

`RestaurantDetailPage(data: RestaurantDetailData)`, reached via `context.push('/restaurant', extra: <payload>)`.

- `RestaurantDetailData.fromPayload` deserializes a `Map<String, dynamic>` (built by `_SwipeCardDataPayload.toDetailPayload()`), defensively defaulting every field.
- Shows hero image, title, details, rating/distance/tag chips, photo gallery, location card (distance only, no map), top review card.
- Note: `videoUrl` is included in the payload map but `RestaurantDetailData` has no `videoUrl` field / doesn't read it back — video is dropped when navigating from Swipe/Explore/Like into the detail page.

## 10. Known limitations / stubs across the file (candidates for follow-up work)

- All restaurant/card data is compile-time constant Dart — no backend/API for restaurant listings (contrast with `README.md`'s Laravel auth contract, which is real).
- User location is a hardcoded dummy `Position` (Peserai, Batu Pahat) — `geolocator` dependency present but permission request / live position stream never invoked.
- Swipe left/right (Pass/Like) has no persistence — decisions aren't saved anywhere (Like tab is a separate static list).
- Search bar in Explore tab has no behavior.
- Quiz result doesn't depend on the chosen answer.
- Settings page (`settings_page.dart`) is static placeholder (Language/Notifications rows, no `onTap` logic).
