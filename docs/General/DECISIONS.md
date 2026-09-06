Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [PLAN.md](PLAN.md), [../README.md](../README.md)

# Decision Log

Every architectural and product decision in the project, in one place, so
"why did we choose X" is queryable rather than buried in chat history or PR
descriptions.

**This is the index, not the source.** Each decision also appears in the doc
that owns its subject, with the surrounding reasoning. Where a decision is
listed in more than one doc, the ID is the same in all of them — cite the ID,
not the row number.

- **locked** — settled. Revisit only with a strong reason and a note here.
- **open** — recorded but not decided. Someone has to choose.

## Foundations

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D1 | Supabase Auth replaces the original Laravel bearer-token API entirely; RLS keyed on `(select auth.uid())` is the security boundary, and the publishable key ships in the binary. | [PLAN](PLAN.md) | locked 2026-08-22 |
| D2 | `ChangeNotifier` + `AnimatedBuilder` for state; no state-management package and no DI container. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-22 |
| D3 | Deck ranking, radius, filters and swipe exclusion live in Postgres RPCs, not the client. | [Backend-Schema](../Features/Backend-Schema.md) | locked 2026-08-23 |
| D4 | Video is embedded via TikTok's own player in a WebView, never downloaded or re-hosted — their developer terms require it. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-22 |
| D7 | Unbuilt surfaces ship an explicit empty state rather than being hidden from the nav. | [Group-Dining](../Features/Group-Dining.md) | locked 2026-08-31 |
| D8 | Fonts (Bricolage Grotesque + Instrument Sans) and Lottie art are bundled as static instances, not fetched — a first offline launch must not fall back to a platform font. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31, reaffirmed 2026-09-04 |

## Schema & data model

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D5 | ~~`swipes.liked` stays boolean; `super_like` is a second flag~~ — **superseded 2026-09-04 by D84.** The super like is gone; the column now stores "save for later". | superseded by D84 |
| D6 | ~~Rewind **deletes** the swipe row~~ — **superseded 2026-09-04 by D84.** Rewind is gone; the design has no undo. Unlike still writes `liked = false`. | superseded by D84 |
| D9 | `haversine_km` in SQL, not PostGIS. | [Backend-Schema](../Features/Backend-Schema.md) | locked 2026-08-23 |
| D11 | Profile write RPCs return the whole `profiles` row, so the client never needs a follow-up read. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |
| D13 | `get_super_liked_ids` is a separate call rather than widening `get_liked_restaurants`, to preserve PostgREST embeds. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D21 | The `tsvector` uses the `'simple'` configuration, not `'english'` — the catalogue is Malay and English. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-22 |
| D33 | Discovery filters and radius live on `profiles`, not device storage, so they survive a reinstall. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D35 | `update_preferences` takes an explicit `p_clear_radius`, because null already means "leave unchanged". | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |
| D37 | `restaurants.video_url` is the stable identity of a row and is never rewritten. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-22 |
| D51 | `reviews.user_id` is `set null`, not cascade — a review is content about a restaurant, not personal data. | [Account-Deletion-Legal](../Features/Account-Deletion-Legal.md) | locked 2026-08-22 |
| D104 | `profiles.spice_level` (1–4) is the stored truth for spice; `spice_bias` is **derived** from it on every write inside `update_preferences` / `complete_onboarding`. The app asks the design's four-step question and the deck's existing three-way term keeps scoring, with no second pass over `deck_scored`. Resolves GAP-ANALYSIS §4.1. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-09-05 |
| D94 | `wishlist_items` replaces `swipes.super_like` as the store behind Later. A wishlist is a list you added to — not a property of your last swipe, which `record_swipe` overwrote — and it has to be able to hold a place that is not in the catalogue at all. The column and `get_super_liked_ids` stay for data safety; the client stops reading them. | [Wishlist](../Features/Wishlist.md) | locked 2026-09-05 |
| D107 | A plan is **one owner, one restaurant, one date**. The triple is a unique index and the ON CONFLICT target of `create_plan`, so locking the same place in twice on one day moves the time instead of writing a second row. | [Plans-Calendar](../Features/Plans-Calendar.md) | locked 2026-09-06 |
| D109 | Plan membership is answered by a `security definer` helper, `public.is_plan_member(bigint)`, rather than by policies on `plans` and `plan_members` that reference each other's tables and recurse. `EXECUTE` stays granted to `authenticated` because a policy expression runs with the querying role's privileges; the advisor warning that follows is accepted and explained in the migration. | [Plans-Calendar](../Features/Plans-Calendar.md) | locked 2026-09-06 |

## Deck & ranking

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D12 | Passport resolves server-side in `deck_scored`, so the client's per-load GPS fix cannot override it. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D14 | The up gesture is guarded on `\|dx\| < 110` so a diagonal fling cannot trigger it. Still true — the gesture now means **Later** rather than super like (D84). | locked 2026-08-31, rebound 2026-09-04 |
| D15 | ~~Celebrate every super like but only 1 in 4 likes~~ — **superseded 2026-09-04 by D84.** The match moment is gone; a restaurant cannot swipe back, and the design does not stop the flow to say so. | superseded by D84 |
| D16 | ~~An unknown swipe count stays swipeable~~ — **superseded 2026-09-04 by D84.** There is no daily limit, so there is nothing to gate and no stats call to fail. | superseded by D84 |
| D17 | A stale (cached) deck is always labelled as stale, never presented as live. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-30 |
| D18 | `DeckRanker` gives unlocated rows neutral half-credit rather than excluding them. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D34 | Filters are applied in `deck_scored`'s `candidates` CTE so they bind the exhaustion fallback too, not just the fresh-cards query. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D36 | The three taste switches are weights; radius and dietary tags are hard filters. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |
| D103 | "Swipe all" hands the map's result **list** to the deck through `DeckHandoff` rather than re-querying; the deck deals what the map already fetched. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-05 |
| D116 | The Nearby map draws the **nearest five** places, sized by distance (`kNearbyPinBigSize` at the origin to `kNearbyPinSmallSize` at the radius edge), laid into the **design's six slots** (`kNearbyPinSlots`) with the two closest in the big ones and each pin on its own side of the me-dot, then spread apart so no two overlap; the camera holds the five and puts the me-dot at 50%/52%. Five is what a thumb can pick between; the results bar and "Swipe all" still speak for the full fetch, and the distance badge carries the truth the position no longer does. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-06 |
| D117 | The Nearby map's "Swipe all" deals only the places the caller has **not already swiped**; the pins still show all of them. `get_nearby` answers `swiped` per row, and the button counts and hands over the rest. Saying what is there is the map's job; not repeating itself is the deck's, and a hand-off of cards the deck has already shown reads as the app forgetting. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-06 |
| D120 | The map's tile template **and its attribution** are `--dart-define`s (`MAP_TILE_URL_TEMPLATE`, `MAP_TILE_ATTRIBUTION`), defaulting to OSM's public server. Shipping on a paid host is then a build flag, not a code change, and the credit cannot be swapped away from its template by accident. `AppConfig.usesDevelopmentTiles` makes "still on the development server" a value the app can read. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-06 |
| D118 | The budget control is a **single upper limit** over a fixed RM 10 floor, as the design draws it ("Budget per person, upper limit"). A second thumb was a question nothing read: `deck_scored` filters on `budget_max` alone. The top stop releases the ceiling rather than setting a RM 100 one. The onboarding habits step no longer asks about spice either — the rules step already took that answer and `complete_onboarding` derives the bias from it (D104). | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-09-06 |
| D105 | `halal_only`, `vegetarian` and `budget_max` are **hard** deck filters: a place the user cannot eat at is a wrong result, not a worse one. Halal requires `is_halal is true` — unknown is not good enough — which is why it is off by default, with only 27 of 1 605 live rows certified. An unknown `price_from` **passes** the budget ceiling, because 1 419 rows have no price and dropping them would empty the deck. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-09-05 |
| D119 | `restaurant_dietary_tags` is **backfilled** from what the catalogue evidences: halal from `restaurants.is_halal is true` (27 rows), vegetarian from a place's own cuisine or its name (6 rows). The other four slugs stay empty rather than guessed. A hard filter over an empty table emptied the deck for anyone who used it, which is worse than an absent switch; guessing a dietary tag is worse still, because a false positive sends someone to eat something they do not eat. An empty deck under any rule the user set now names that rule. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-09-06 |

## Feature behaviour

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D19 | Explore applies the same radius rule as the deck — findable and servable are the same set. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-23 |
| D20 | `search_restaurants` caps at 100 and lets the closest win, rather than paginating a browse surface. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-23 |
| D22 | The Top Picks rail is best-effort; its failure must not fail the tab. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-31 |
| D23 | Cuisine tiles are ordered server-side by count; the client must not re-sort. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-31 |
| D24 | Deck filters are server-side profile state; the Liked tab's filter sheet is client-side. A finite owned list is a view concern. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D25 | Liked segments load lazily — a user who never opens Visited never pays for it. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D26 | The visit prompt only arms when the maps app actually opened, and only for signed-in users. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D27 | "I didn't go" records nothing — a dismissal is not data. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D28 | `confirm()` clears its cache only after the write lands, so a failure re-asks rather than losing the visit. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D29 | Nothing is written until Finish; a quit mid-wizard re-shows the wizard rather than half-configuring an account. | [Onboarding-Taste](../Features/Onboarding-Taste.md) | locked 2026-08-23 |
| D30 | Declining location records `denied` and completes the wizard — a refusal is an answer, not an escape. | [Onboarding-Taste](../Features/Onboarding-Taste.md) | locked 2026-08-23 |
| D31 | Dietary tags filter; cuisines weight. "Halal" must not be outweighed by proximity. | [Onboarding-Taste](../Features/Onboarding-Taste.md) | locked 2026-08-23 |
| D32 | `morning_mode` and `spice_bias` apply through the cuisine taxonomy (`is_breakfast`, `spice_level`), not columns on `restaurants`. | [Onboarding-Taste](../Features/Onboarding-Taste.md) | locked 2026-08-23 |
| D54 | The cold-start taste signal is collected in onboarding, not by a quiz tab — it runs before the first card. | [Quiz](../Features/Quiz.md) | locked 2026-08-23 |
| D55 | Quiz schema retained at the redesign rather than dropped with the tab. | [Quiz](../Features/Quiz.md) | **open** |
| D102 | The Nearby map **replaces** the cuisine grid and the per-cuisine page, which are deleted rather than kept alongside it. This retires the surfaces D22 and D23 govern without striking those decisions: the DB functions behind them (`get_cuisine_counts`, `get_top_picks`) are retained. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-05 |
| D106 | The You tab shows three stat tiles and an editable taste list. "bites" is real; "plans kept" and "eating-out streak" come from a `ProfileStats` parameter a later phase fills and read **0** until then, rather than being hidden — a tile that appears later would change the row's shape. The taste list edits in place through bottom sheets carrying the same switch/segment/range controls as the first-run step, written optimistically and reverted on failure. "Videos autoplay" is **not** shown: the player hard-codes `autoplay=1` and the app cannot detect Wi-Fi, so the row would be a setting that does nothing. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-09-05 |
| D113 | **Phone sign-in is config-gated exactly like Google.** The flow is built (+60 only, a six-digit code, a 30-second resend), but `PHONE_AUTH_ENABLED` is off by default and the button hides itself, because the SMS provider is Supabase dashboard work with a real per-message cost that this repo cannot do. A button that fails at tap time is worse than no button. | [Auth](../Features/Auth.md) | locked 2026-09-06 |
| D114 | **Email/password stays as the fallback until phone is live**, moved behind a "Use email instead" text button on the sign-up screen and folded into one form (sign in, create account, reset). The design drops email entirely, but phone, Google and Apple are each gated by a define, client ids or the platform, so a build with none of them — every developer build, and the reviewer's — would otherwise have no way to sign in at all. It leaves when phone is switched on. | [Auth](../Features/Auth.md) | locked 2026-09-06, revisit when D113 flips |
| D115 | **Guest browsing is gated too.** The design's "Later" needs Supabase's anonymous provider, which is not enabled on the project, so it sits behind `GUEST_BROWSING_ENABLED` and is hidden by default rather than signing nobody in. | [Auth](../Features/Auth.md) | locked 2026-09-06 |
| D95 | A Later is a **like** — the swipe is unchanged (`p_liked: true`, no `p_super_like`) and a `wishlist_items` row is written on top. The wishlist follows the like on removal only: unliking clears the row, re-liking never does. The old flag failed the second half, because `record_swipe` overwrote it on every swipe. | [Wishlist](../Features/Wishlist.md) | locked 2026-09-05 |
| D108 | A past plan is a **kept** plan unless it was cancelled first. `mark_plan_kept()` flips it server-side on load, and there is no "did you go?" prompt anywhere: the calendar records intent, and intent that survived to the day counts. Asking a day later gets a worse answer than not asking. | [Plans-Calendar](../Features/Plans-Calendar.md) | locked 2026-09-06 |
| D110 | A plan's time is one of **five fixed chips** — 12:30, 18:30, 20:00, 21:30, Late — not a time picker. A time is a thing to agree on with other people, and four options are agreed on faster than 1 440. "Late" is a label with no hour, which is why `plans.plan_time` is nullable, and it sorts last within a day. | [Plans-Calendar](../Features/Plans-Calendar.md) | locked 2026-09-06 |

## TikTok player

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D38 | A player handle carries an explicit load status; a WebView that fails silently must be able to offer a retry. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-29 |
| D39 | The player cache is bounded at 5 — above the 3-warmed + 2-mounted working set, so the watched player is never evicted. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-29 |
| D40 | Evicted players are navigated to a blank page, because webview_flutter 4.x has no `dispose`. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-29 |
| D41 | Only the foreground card mounts a WebView; the card behind shows a thumbnail. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-22 |
| D42 | Thumbnail bytes are cached into Storage and `url` repointed permanently, because TikTok CDN URLs expire in ~24h. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-22 |
| D43 | The thumbnail pipeline stays inert without its vault secrets, so a fresh database cannot call production. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-23 |

## Data pipeline

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D10 | Free geocoding (Overture + Nominatim) over paid Google Places, accepting lower precision and no ratings, to keep API spend at zero. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-31 |
| D44 | Scraping and parsing are separate stages — a caption is fetched once and re-parsed as the extractor improves. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-29 |
| D45 | Every script writes a file by default; nothing in the chain writes to Supabase unattended. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-29 |
| D46 | Uncertain candidates carry a confidence and their caption, and require a human/model review pass. No line in `keep.jsonl` means dropped. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-29 |
| D47 | Geocode results coarser than a suburb are discarded — a wrong fix is worse than none, because `0/0` hides the directions button and a bad fix routes people. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-31 |
| D48 | Geocode matching is confined to the row's `negeri` bounding box, so chains cannot resolve across states. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-31 |
| D49 | `negeri` / `negara` are overridable by hand in the review file, because Malaysian street names contain state names. | [Restaurant-Data](../Features/Restaurant-Data.md) | locked 2026-08-31 |

## Client architecture

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D56 | The splash route holds until session **and** profile resolve, so cold start never flashes the wrong screen. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-22 |
| D57 | `/restaurant/:id` routes by id; the earlier `extra`-payload route dropped fields and could not deep-link. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-29 |
| D58 | Repositories resolve `Supabase.instance` per call, not in their constructor, so widgets are testable without an initialised client. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-29 |
| D59 | Catches name their exception type; `AuthRepository` maps each to an actionable sentence. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-29 |
| D60 | Platform-channel dependencies are constructor-injected with defaults, because `flutter test` has no implementation for them. | [Frontend/STACK](../Frontend/STACK.md) | locked 2026-08-29 |
| D101 | The map is `flutter_map` with a **constructor-injected** `TileProvider`. The OpenStreetMap default is development only under their usage policy; production swaps a URL template, and tests pass a fake so the suite never reaches the network. | [Nearby-Map](../Features/Nearby-Map.md) | locked 2026-09-05 |

## Design system

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D61 | ~~Every radius token is `0`~~ | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | **superseded 2026-09-04 by D74** |
| D62 | Exactly two button fills. A third would mean a third meaning nobody defined. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D63 | One typeface; `kDisplayFontFamily` and `kTextFontFamily` are kept as separate names because call sites ask about role, not family. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D64 | ~~`kAccentCream` is reserved for one primary action per screen~~ | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | **superseded 2026-09-04 by D75** |
| D65 | `kBrandColorFallback` equals the panel grey, so an unbranded card is neutral rather than visibly wrong. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D66 | The restaurant title style is identical across deck, Liked and detail, so the three screens read as one design. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D67 | Tokens are named by role, never by colour. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D68 | `lunar/` effects are kept separate from the token vocabulary. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-08-31 |
| D74 | Corners return at 999/28/18/10; the five radius tokens stay the only seam, so the square app is one edit away in either direction. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D75 | The primary action is filled with `kCtaGradient` (ember → lava) and is the app's only gradient fill. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D76 | The palette is asserted in tests — warm blacks, stacking order, one non-orange accent — so a retint cannot quietly break the rule that governs it. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D77 | All-caps is forbidden, and the rule lives in `AppEyebrow` because that was the app's only uppercasing call site. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D78 | `ScreenGlow` is the single exception to "nothing decorative is orange", granted only because it is `IgnorePointer` and never touches a control. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D79 | The saved-marker is a notch **clipped out of** the surface, not a badge drawn on it — a mark that is part of the silhouette cannot be mistaken for a button. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D80 | Only the current bottom-nav tab is labelled, and three signals — fill, ink, filled-vs-outline glyph — mark it without relying on colour. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D81 | The bite is not wired to the swipe card: the deck deals only unswiped places, so the flag would be dead code. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D82 | ~~The super-like star survives the bite~~ — **resolved 2026-09-04 by D84.** The star went with the feature, which is what let the tile's bite go to the specified full size. | resolved by D84 |
| D83 | A `Semantics` that sets `excludeSemantics` re-declares its own `onTap`, and accessibility claims are asserted by driving the semantics action rather than by reading the widget tree. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D84 | The features the new design does not have are **removed, not hidden**: super like, rewind, the daily swipe limit, the deck streak, the match moment and passport. A control for a retired feature is worse than a missing one, and a flag nothing sets is worse than a flag that is gone. | [Redesign/GAP-ANALYSIS](../Redesign/GAP-ANALYSIS.md) §4.5 | locked 2026-09-04 |
| D85 | The up gesture means **Later** — save without deciding. The client speaks of `later` throughout; `swipes.super_like` remains its storage and `p_super_like` its wire name until a database migration renames them, so a client change never needs a schema change to ship. | [Features/Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-09-04 |
| D86 | The deck's primary action is a 72 px gradient circle carrying the **word** "Ngap!", not a heart. It is the largest control in the app because it is the only thing worth doing on that screen, and the word teaches itself. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D87 | Tabs 2 and 4 are named **Nearby** and **Calendar** per the design, ahead of the map and the plans they will hold. This reverses the earlier reading of D7: the design's names are the target, and the empty states now say plainly what is coming rather than describing the old feature. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-04 |
| D88 | **No emoji anywhere as food imagery.** `cuisines.emoji` is not read at all — the field is gone from both models, so a call site cannot reintroduce it. A cuisine with no cover photo falls back to its **name on a chip**. | [Features/Explore-Search](../Features/Explore-Search.md) | locked 2026-09-04 |
| D89 | Video starts **muted**, and the card says so. It is also the only autoplay a browser engine honours without a gesture, so the first frame stops depending on `setMediaPlaybackRequiresUserGesture`. Sound is turned on through TikTok's own control, because D4 forbids driving their player. | [Features/TikTok-Video](../Features/TikTok-Video.md) | locked 2026-09-04 |
| D96 | The design's **chip row** replaces the Bites tab's Liked / Visited / Reviewed segments, and Visited and Reviewed leave the client entirely (their RPCs and data stay). The three plan chips are one enum rather than three booleans that can contradict each other, and "Wishlist →" navigates without ever holding a pressed state — a chip still lit after taking you away is claiming to be a filter it is not. | [Frontend/DESIGN-SYSTEM](../Frontend/DESIGN-SYSTEM.md) | locked 2026-09-05 |
| D90 | Onboarding ends on a **gesture primer** — "Three moves" — and its button says **"Show me dinner"** rather than "Finish". The three words the deck expects (Ngap!, Skip, Later) are taught before the user meets a card that expects them. | [Features/Onboarding-Taste](../Features/Onboarding-Taste.md) | locked 2026-09-04 |
| D111 | The detail screen's facts strip shows **only the facts the catalogue can answer** — a tile it cannot fill is removed and the rest widen, rather than printing a dash where an answer goes. The price tile is a *cheapest dish* (not the design's per-person band, which nobody measured), and the big number is the ngap count rather than a rating that is 0 on almost every row. | [Features/Restaurant-Detail](../Features/Restaurant-Detail.md) | locked 2026-09-06 |
| D112 | **"Set a date" likes the place first.** A plan is a thing you do about a restaurant you want, so a plan on an un-bitten place would be an orphan the Bites tab never lists. A like that will not write stops the push rather than landing the user in a planner whose premise silently failed. | [Features/Restaurant-Detail](../Features/Restaurant-Detail.md) | locked 2026-09-06 |

## Testing

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D69 | Hand-written fakes that `implements` the real interface, not a mocking framework. A fake fails to compile on an interface change; a generated mock keeps lying. | [Tests/CONVENTIONS](../Tests/CONVENTIONS.md) | locked 2026-08-22 |
| D70 | Fakes live beside their tests as `fake_*.dart`, not in `support/` — a fake is test data, not infrastructure. | [Tests/CONVENTIONS](../Tests/CONVENTIONS.md) | locked 2026-08-22 |
| D71 | An interface change lands in its fakes in the same commit. | [Tests/CONVENTIONS](../Tests/CONVENTIONS.md) | locked 2026-08-31 |
| D72 | Widget tests stub the HTTP image stack globally via `ImageHttpOverrides`, because every card carries a network image. | [Tests/CONVENTIONS](../Tests/CONVENTIONS.md) | locked 2026-08-29 |
| D73 | Layout tests assert no-overflow across phone/narrow/tablet plus a huge text scale, in place of golden tests. | [Tests/CONVENTIONS](../Tests/CONVENTIONS.md) | locked 2026-08-29 |

## Compliance

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D50 | Deleting `auth.users` is the whole deletion path; the cascade does the rest. No bespoke cleanup code to drift out of sync with the schema. | [Account-Deletion-Legal](../Features/Account-Deletion-Legal.md) | locked 2026-08-31 |
| D52 | Legal pages are an edge function, not in-app screens, because Google Play needs a URL openable with no app and no account. | [Account-Deletion-Legal](../Features/Account-Deletion-Legal.md) | locked 2026-08-31 |
| D53 | `delete-account` keeps `verify_jwt = true` so the platform rejects unauthenticated callers before the function runs. | [Account-Deletion-Legal](../Features/Account-Deletion-Legal.md) | locked 2026-08-31 |

## Open

One decision is recorded but not made:

- **D55 — the Quiz schema.** Four database objects with no caller. Either drop
  them or build the surface; leaving them orphaned is the only wrong answer.
  See [Features/Quiz.md](../Features/Quiz.md).

## Adding a decision

1. Write it in the doc that owns the subject, in that doc's own **Decision
   log** table, with the reasoning around it.
2. Add the row here, in the matching section, with a link back.
3. Take the next free ID. **Never reuse one** — a decision cited elsewhere by
   ID must keep meaning the same thing. The highest ID in use is **D120**.
