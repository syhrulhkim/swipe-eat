Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-04
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
| D5 | `swipes.liked` stays boolean; `super_like` is a second flag, not an enum — an enum would break `get_deck`'s exhaustion branch, `get_liked_restaurants`, and a partial index for no gain. | [Backend-Schema](../Features/Backend-Schema.md) | locked 2026-08-31 |
| D6 | Rewind **deletes** the swipe row; unlike writes `liked = false`. Only a deleted row is dealt again. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D9 | `haversine_km` in SQL, not PostGIS. | [Backend-Schema](../Features/Backend-Schema.md) | locked 2026-08-23 |
| D11 | Profile write RPCs return the whole `profiles` row, so the client never needs a follow-up read. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |
| D13 | `get_super_liked_ids` is a separate call rather than widening `get_liked_restaurants`, to preserve PostgREST embeds. | [Likes-Visits](../Features/Likes-Visits.md) | locked 2026-08-31 |
| D21 | The `tsvector` uses the `'simple'` configuration, not `'english'` — the catalogue is Malay and English. | [Explore-Search](../Features/Explore-Search.md) | locked 2026-08-22 |
| D33 | Discovery filters and radius live on `profiles`, not device storage, so they survive a reinstall. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D35 | `update_preferences` takes an explicit `p_clear_radius`, because null already means "leave unchanged". | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |
| D37 | `restaurants.video_url` is the stable identity of a row and is never rewritten. | [TikTok-Video](../Features/TikTok-Video.md) | locked 2026-08-22 |
| D51 | `reviews.user_id` is `set null`, not cascade — a review is content about a restaurant, not personal data. | [Account-Deletion-Legal](../Features/Account-Deletion-Legal.md) | locked 2026-08-22 |

## Deck & ranking

| ID | Decision | Owner doc | Status |
|---|---|---|---|
| D12 | Passport resolves server-side in `deck_scored`, so the client's per-load GPS fix cannot override it. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D14 | The up-swipe super like is guarded on `\|dx\| < 110` so a diagonal fling cannot spend the scarce signal. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D15 | Celebrate every super like but only 1 in 4 likes — an always-on celebration stops being one. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D16 | An unknown swipe count stays swipeable; only a known-and-spent count blocks. A stats failure must not brick the deck. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D17 | A stale (cached) deck is always labelled as stale, never presented as live. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-30 |
| D18 | `DeckRanker` gives unlocated rows neutral half-credit rather than excluding them. | [Swipe-Deck](../Features/Swipe-Deck.md) | locked 2026-08-31 |
| D34 | Filters are applied in `deck_scored`'s `candidates` CTE so they bind the exhaustion fallback too, not just the fresh-cards query. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-31 |
| D36 | The three taste switches are weights; radius and dietary tags are hard filters. | [Profile-Preferences](../Features/Profile-Preferences.md) | locked 2026-08-23 |

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
   ID must keep meaning the same thing. The highest ID in use is **D78**.
