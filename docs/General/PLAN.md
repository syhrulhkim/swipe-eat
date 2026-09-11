Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-10
Cross-references: [RUNBOOK.md](RUNBOOK.md), [DECISIONS.md](DECISIONS.md), [Features/Backend-Schema.md](../Features/Backend-Schema.md), [Features/Swipe-Deck.md](../Features/Swipe-Deck.md), [Features/Friends.md](../Features/Friends.md), [../README.md](../README.md)

# Product & Architecture Plan

## 1. What this is

Swipe Eat answers one question — *where should I eat?* — with a Tinder-shaped
card deck instead of a search box. Each card is a real restaurant fronted by a
real TikTok video, because the decision "do I want this" is made by watching
food, not by reading a listing.

The catalogue is built from Malaysian food creators' TikTok posts. As of
2026-09-10 the database holds **1,607 restaurants** (1,605 active), of which
**1,606 carry a TikTok video** and **1,133 have coordinates**. Coverage follows
the creators the pipeline scraped: **844 rows in Johor and 741 in Pulau
Pinang**, with 22 between Kedah, Perak, Kuala Lumpur and Perlis.

### Why swiping, not search

Search assumes you already know what you want. The deck assumes you don't. Every
product decision follows from that: the video is the card (not a thumbnail
beside text), the deck is ranked and finite (not an infinite scroll), and a swipe
is a recorded decision (so the app can stop showing you what you rejected).

### Who it is for

One audience today: someone in Johor or Penang deciding where to eat in the next
hour. The radius filter, the distance chip and the `Asia/Kuala_Lumpur` deck seed
all assume a local, present-tense user. Travel planning is not served at all —
the deck's origin is the device's fix, else the profile's stored one, and
nothing else (D121).

## 2. The five surfaces

The app is a bottom-nav shell (`lib/features/dashboard/presentation/dashboard_page.dart`)
over an `IndexedStack`, so every tab keeps its state across switches.

| Index | Tab | Doc | Status |
|---|---|---|---|
| 0 | Swipe | [Swipe-Deck](../Features/Swipe-Deck.md) | ACTIVE |
| 1 | Nearby | [Nearby-Map](../Features/Nearby-Map.md) | ACTIVE |
| 2 | Bites | [Likes-Visits](../Features/Likes-Visits.md) | ACTIVE |
| 3 | Calendar | [Plans-Calendar](../Features/Plans-Calendar.md) | ACTIVE |
| 4 | You | [Profile-Preferences](../Features/Profile-Preferences.md) | ACTIVE |

Only the selected tab is labelled (D80). Everything else is a route pushed over
the shell rather than a sixth tab — `lib/app/app_router.dart` has
`/restaurant/:id`, `/wishlist`, `/friends`, `/plans/new`, `/plans/:id`,
`/plans/:id/invite` and `/settings`, plus the signed-out `/welcome`, `/signup`,
`/signup/phone` and `/onboarding`.

## 3. Architecture

```
Flutter client                          Supabase
┌───────────────────────────┐          ┌────────────────────────────┐
│ presentation/  widgets    │          │ Auth (GoTrue)              │
│ state/         controllers│◀────────▶│ phone (gated)·Google·Apple │
│                           │          │   · email fallback         │
│ data/          repositories│  RPC +  │ Postgres + RLS             │
│ models/        DTOs       │ PostgREST│   22 tables, 48 functions  │
│ domain/        pure logic │          │ Storage  restaurant-images │
└───────────────────────────┘          │ Edge     3 functions       │
        │                              │ pg_cron  thumbnail refresh │
   shared_preferences                  └────────────────────────────┘
   (offline deck/profile cache)
```

### Layering rules

Every feature under `lib/features/<name>/` follows the same four-folder shape,
and the dependency arrow only ever points one way:

```
presentation/  →  state/  →  data/  →  models/
                                   ↘  domain/   (pure, no I/O)
```

- **`presentation/`** — widgets. No Supabase calls, no business rules.
- **`state/`** — `ChangeNotifier` controllers. Own the loading/error/stale
  flags, sequence concurrent loads, and hold optimistic state.
- **`data/`** — repositories. The only place that talks to `Supabase.instance`
  or to `shared_preferences`. Each exposes an interface the test fakes
  implement.
- **`models/`** — DTOs with `fromJson`, defensive about nulls.
- **`domain/`** — pure logic with no I/O, so it is testable without a fake
  (`deck_ranker.dart` is the whole of it today).

`lib/core/` holds what more than one feature needs: `config/` (all
`--dart-define` reading), `location/`, `observability/`, `storage/`,
`supabase/` and `ui/` (the design system).

### Where the logic lives

Ranking, radius filtering, taste weighting and "don't re-show swiped cards" all
live in Postgres functions, not in Dart. The client passes a location and a
seed and renders what comes back in order. This is deliberate (D3): the rules
change more often than the client ships, and a filter the client applies is a
filter a stale client can get wrong.

The one exception is `DeckRanker` (`lib/features/restaurants/domain/deck_ranker.dart`),
which re-ranks a *cached* deck offline, where there is no server to ask.

### State management

`ChangeNotifier` + `AnimatedBuilder`, no Riverpod/Bloc. The app has one
long-lived controller (`AuthController`, wired to `GoRouter` via
`refreshListenable`) and per-tab controllers constructed by their tab. Nothing
in the app needs a dependency-injection container to find them — see D2.

### Offline behaviour

`shared_preferences` caches the last dealt deck (`deck_cache.dart`), the profile
(`profile_cache.dart`) and pending visit prompts (`visit_prompt_cache.dart`). A
cold launch with no connection deals the cached deck, re-ranked locally, and the
deck header says so — `DeckController.isStale` drives a visible staleness label,
because a saved deck shown as live is a lie about how close those places are.

## 4. Current state, honestly

### Works end to end

Email/password auth, Google and Apple sign-in (when console-configured) and a
phone flow behind a define; the onboarding wizard, including contact matching;
the ranked deck with its three-button action bar (Skip / Ngap! / Later); the
Nearby map with its radius stepper and "Swipe all" hand-off; the Bites grid with
its chip row and the visit prompt; discovery settings (radius, cuisines,
dietary needs, rating); the wishlist at `/wishlist`; plans, the Calendar tab and
the plan page's time voting; friends, friend requests and plan invites; the
offline deck fallback; Sentry crash reporting; account deletion and the public
legal pages.

### Known gaps

| Gap | Impact | Detail |
|---|---|---|
| **Ratings are effectively absent** | **2 of 1,607** rows carry a rating, both inactive — **no dealt card has one**. `deck_scored`'s rating term never fires, so every dealt card scores its exploration jitter at the unrated weight, and `filter_min_rating` empties the deck outright. | [Restaurant-Data](../Features/Restaurant-Data.md) |
| **474 restaurants have no coordinates** | They cannot be distance-ranked or radius-filtered; the ranker gives them neutral half-credit so they still appear. | [Restaurant-Data](../Features/Restaurant-Data.md) |
| **Geocoding precision is uneven** | Free Nominatim matched many rows to a nearby feature rather than the address; ~225 rows had state mismatches, most since corrected. | [Restaurant-Data](../Features/Restaurant-Data.md) |
| **Password reset is a dead end** | The recovery link redirects to the project Site URL, which the app never sees. No URL scheme, no set-new-password screen. | [Auth](../Features/Auth.md) |
| **Auth email goes to a sandbox** | Mailtrap Email Testing captures everything; no mail reaches a real address. Must switch before real users. | [Auth](../Features/Auth.md) |
| **Only 287 images and 6 reviews** | Card galleries and review carousels are mostly empty; the video carries the card. | [Restaurant-Data](../Features/Restaurant-Data.md) |
| **The friend graph is empty** | `friendships` holds 0 rows and `plan_members` is only ever written by an invite, so every social surface is exercised by tests and the dev harness rather than by use. | [Friends](../Features/Friends.md) |
| **13 unused indexes, one unindexed FK** | Supabase's performance advisor. Both are artefacts of a database with no traffic; `friendships.requester_id` is the FK. Re-check before dropping anything. | [Backend-Schema](../Features/Backend-Schema.md) |
| **`get_ngap_count` is callable by `anon`** | A `security definer` aggregate over `swipes`, granted to `anon` for a logged-out browse mode that does not exist yet. It returns a count and nothing about who. | [Backend-Schema](../Features/Backend-Schema.md) |
| **Quiz schema is orphaned** | 4 tables + `submit_quiz_answer` exist; no code in `lib/` references them. | [Quiz](../Features/Quiz.md) |
| **Leaked-password protection is off** | A Supabase dashboard toggle that has to be set by hand. | [Auth](../Features/Auth.md) |

## 5. Where this is headed

Ordered by what unblocks the most, not by effort:

1. **Fix the ratings gap.** A deck that cannot say how good a place is loses
   its quality signal, and one of the three discovery filters is dead. This
   needs a paid geocoding/ratings pass or a different source.
2. **Finish the auth loose ends** — production SMTP, a real Site URL, a URL
   scheme and a set-new-password screen, leaked-password protection on. All
   four are prerequisites for real users, not polish.
3. **Geocode the remaining 474** and re-run precision checks on the coarse
   matches.
4. **Decide the Quiz's fate** — either build the surface the schema is waiting
   for, or drop the four tables. Leaving it orphaned is the only wrong answer.
5. **Images and reviews** at catalogue scale.

Two more the owner has raised and nobody has designed — listed so they are not
mistaken for either shipped work or a plan:

- **Adding friends from contacts on `/friends`.** Contact matching exists but
  runs only once, in onboarding step 01f. *Under discussion.*
- **An autoplay setting.** Ruled out once already (D106) because the player
  hard-codes `autoplay=1`. *Under discussion.*

## 6. Out of scope

- **Chat, "Likes You", Boost, mutual matching** — a restaurant never swipes
  back; faking the other side of the market would be a lie. See
  [History/tinder-parity-plan.md](../History/tinder-parity-plan.md).
- **Subscription tiers** — monetisation scaffolding with no user value yet.
- ~~**Price and opening-hours filters**~~ — built 2026-09-05 (D91, D105).
  `hours_text`, `opens_at`, `closes_at`, `closed_dow`, `price_from` and
  `is_halal` all exist; `is_open_at` powers `open_now` in `get_nearby`, and
  `deck_scored` applies the budget ceiling as a hard predicate. What remains
  out of scope is chasing coverage: only 194 rows have hours, 186 a price and
  30 a halal answer, because only those captions said.
- **PostGIS** — `haversine_km` in SQL is enough at 1,607 rows.
- **Realtime** — plans and invites are collaborative, but they are read on
  load and on pull-to-refresh, which is enough for a dinner that is days away.
- **User-authored reviews** — `reviews.user_id` leaves the hook; no write path
  exists.

## 7. Decision log

| ID | Decision | Status |
|---|---|---|
| D1 | Supabase Auth replaces the original Laravel bearer-token API entirely; RLS keyed on `auth.uid()` is the security boundary, and the publishable key ships in the binary. | locked 2026-08-22 |
| D2 | `ChangeNotifier` + `AnimatedBuilder` for state, no DI container and no state-management package. | locked 2026-08-22 |
| D3 | Deck ranking, radius, filters and swipe exclusion live in Postgres RPCs, not in the client. | locked 2026-08-23 |
| D4 | TikTok video is embedded through TikTok's own player in a WebView, not downloaded or re-hosted — their terms require the official player. | locked 2026-08-22 |
| D5 | `swipes.liked` stays a boolean; `super_like` is a second flag rather than an enum, to avoid breaking three call sites and a partial index. | locked 2026-08-31 |
| D6 | Rewind **deletes** the swipe row; unlike writes `liked = false`. Only a deleted row is dealt again. Rewind left the client with D84; the RPC remains, with no caller. | superseded on the client by D84 |
| D7 | Unbuilt surfaces ship an explicit empty state rather than being hidden from the nav. | locked 2026-08-31 |
| D8 | Fonts (Lexend) and Lottie art are bundled, not fetched — a first offline launch must not fall back to a platform font. | locked 2026-08-31 |
| D9 | Distance is computed with a SQL `haversine_km`, not PostGIS. | locked 2026-08-23 |
| D10 | Free geocoding (Overture + Nominatim) over paid Google Places, accepting lower precision and no ratings, to keep API spend at zero. | locked 2026-08-31 |
