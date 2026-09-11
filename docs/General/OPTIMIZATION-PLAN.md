Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [PLAN.md](PLAN.md), [DECISIONS.md](DECISIONS.md), [Features/Swipe-Deck.md](../Features/Swipe-Deck.md), [Features/Backend-Schema.md](../Features/Backend-Schema.md), [Features/Friends.md](../Features/Friends.md), [Features/TikTok-Video.md](../Features/TikTok-Video.md), [Features/Plans-Calendar.md](../Features/Plans-Calendar.md), [Release/STORE.md](../Release/STORE.md)

# Optimization Plan

## 1. What this is

One plan covering four things the owner asked for on 2026-09-10: make the
frontend faster, make the backend and the database structure hold up, improve
the UI/UX, and take what dating apps have learned about ranking and session
design and apply the parts that survive the translation to restaurants.

It is built on three inputs, in this order of authority:

1. **The code and the live database**, read directly. Every number here was
   either queried against the project or read out of a file named with its
   line. Where something could not be verified, it says so.
2. **A performance and structure audit** of the Flutter app and the SQL, ranked
   by cost × likelihood, with a deliberate list of what was considered and
   rejected.
3. **Published accounts of how Tinder, Hinge and Bumble rank and pace**, mapped
   term by term onto a ranker that already exists in Postgres.

The third input is the one that needs the most discipline, because the
translation is not free. Swipe Eat is a **one-sided market**: a restaurant
cannot swipe back, cannot be offended, and cannot be out of your league. Every
mechanism a dating app uses to protect the *other* side — reciprocity scoring,
like limits, boosts, exposure fairness, the match moment — has no counterpart
here and is left out on purpose. §7 lists those rejections by name so nobody
re-proposes them in six months.

**Scope approved 2026-09-11**, one question at a time — the nine answers are
in §2. Each decision in §11 locks as its phase lands, not before, and the two
questions in §10 that change a schema are asked again before the migration that
would answer them by accident.

## 2. What the owner approved

Asked one question at a time on 2026-09-10 and 2026-09-11.

| # | Question | Answer |
|---|---|---|
| 1 | Fix the `swiped_at` ranking bug? | **Fix it now, own migration.** Done — D135, shipped 2026-09-11 |
| 2 | How much of the deck's ranking changes in one go? | **All four terms, plus the jitter cut** |
| 3 | What goes on the end-of-deck card? | **Widen the search**, and **explain what Reload does** |
| 4 | Contact matching reachable from `/friends`? | **Yes, a Find friends row**, no automatic re-scan |
| 5 | Autoplay setting shape? | **Always / On Wi-Fi only / Never** |
| 6 | Implicit signals and the "would you go back" prompt? | **"If they already go, ask for review."** Build the post-plan review properly; the two implicit columns are not settled — see §8 |
| 7 | Which frontend findings? | **All three**: the drag rebuild, the cold-start storm, the duplicate player |
| 8 | Which database findings? | **All three**: the geo index, the deck's column set, the vote hole |
| 9 | The privacy page contradicts the app | **Fix the page and the manifest, do not deploy** |

## 3. Where the app stands today

Verified against the live project on 2026-09-11.

| | |
|---|---|
| Restaurants | 1,607 rows, 1,133 geocoded, 1,605 with a video |
| Ratings | 2 rows non-zero, **both inactive** — no dealable card has a rating |
| Hours | 194 rows with `hours_text`, 181 `opens_at`, 186 `closes_at` |
| Swipes | 55, from 1 real profile |
| Friendships | 0 |
| Schema | 22 tables, 48 functions, 35 RLS policies, 3 edge functions, 1 cron job |

Two consequences run through everything below. **The rating term never fires**,
so the 0.15 quality weight is dead and the jitter runs at its unrated value of
0.50 on every card. And **the live data cannot tell you whether a query is
slow** — 1,607 rows fit in memory, so the planner's current choices prove
nothing about 50,000. Where a finding is scale-dependent it is labelled as
such rather than dressed up as a present-day emergency.

## 4. Phase 1 — Ranking

All of it is inside `deck_scored` and `get_deck`. No client change. Built and
verified one term at a time, in this order, because each later term is only
measurable once the earlier one has taken the noise out.

### 4.1 Cuisine diversity, then cut the jitter (D137)

**The problem.** `get_deck` can hand back five satay stalls in a row: proximity
dominates the score, satay stalls cluster geographically, and the jitter is
per-restaurant rather than per-position, so it cannot break up a run.

**The fix.** A soft penalty inside `get_deck`'s ordering, not a round-robin. A
round-robin would be wrong here: there are only 22 cuisines in use against a
30-card deck, so partitioning would hand nearly every cuisine exactly one slot
and give the cuisine the user demonstrably likes no more room than the one they
do not — which would cancel §4.2 before it shipped.

```sql
order by d.score - 0.05 * (row_number() over (
           partition by c.cuisine_id order by d.score desc) - 1) desc, r.id
```

`restaurant_cuisines` is many-to-many and carries no position column, but no
restaurant currently holds more than one cuisine, so "the" cuisine is
unambiguous today. Define it as `min(cuisine_id)` per restaurant so the query
stays correct the day that changes.

**Then the jitter comes down, 0.50 → 0.25.** Most of what the jitter buys today
is exactly this anti-clustering, bought blindly. Once diversity is explicit the
randomness can halve, and proximity, taste and open-now become things the user
can actually feel. This ordering is not negotiable: cutting the jitter first
would expose the clustering the jitter was hiding.

**Verify:** deal a deck before and after, count the longest same-cuisine run and
the number of distinct cuisines in the first ten cards.

### 4.2 Per-user cuisine affinity (D136)

**The problem.** Nothing in the app learns from a single swipe. The taste term
reads only the cuisines picked during onboarding, so a user who picked
"Western" and has passed on every Western place for a month still gets Western.

**The fix.** An `affinity` CTE that turns swipes into a per-cuisine like rate,
shrunk toward the onboarding pick:

```sql
affinity as (
  select rc.cuisine_id,
         (sum(case when s.liked then 1 else 0 end) + 2.0 * prior)
       / (count(*) + 2.0) as p_like
  from public.swipes s
  join public.restaurant_cuisines rc on rc.restaurant_id = s.restaurant_id
  where s.user_id = (select auth.uid())
    and s.source = 'deck'
  group by rc.cuisine_id
)
```

`prior` is written out as an `exists` against `profile_cuisines`: **1.0** when
the cuisine is an onboarding pick, **0.0** otherwise. Fold it into the existing
0.25 taste block by replacing `0.60 × matches_pick` with
`0.60 × coalesce(a.p_like, matches_pick)`.

**Why 1.0 and 0.0 and not something softer.** The obvious version is wrong.
Today `matches_pick` is 1 or 0 and spans 0.60 of the 0.25 block, which is 0.15
of the total score. Priors of 0.65 and 0.35 would span 0.045 of score, inside
the jitter's shadow even at 0.25 — the onboarding pick would quietly stop
mattering the day this shipped. The degenerate prior makes the zero-swipe case
**exactly today's behaviour** and lets evidence move a cuisine at the rate the
pseudo-count allows: two likes in a picked cuisine barely move it, two passes
pull it to 0.5.

That `2.0` pseudo-count **is** the cold-start handling. No branch on new versus
established user, just shrinkage that decays as evidence arrives.

`source = 'deck'` matters: a "Set a date" like (D112) and a Nearby-map swipe are
not deck exposures and would poison the rate.

The indiscriminate swiper needs no special code. If a user's global like rate is
above about 0.9 their affinities all sit at their prior anyway, which the
shrinkage handles for free.

**Honest caveat:** with 55 swipes this term is nearly inert on day one. It is
worth shipping anyway, because the alternative is never starting to learn.

### 4.3 Open now (D138)

`deck_scored` already resolves `local_hour` in Asia/Kuala_Lumpur and uses it for
nothing but `morning_mode`. `opens_at`, `closes_at` and `closed_dow` exist, the
past-midnight and all-day cases are documented on the column comments, and
`lib/features/restaurants/domain/opening_hours.dart` already parses exactly
those columns — so the client vocabulary exists and the server term only has to
agree with it.

One term: **+0.08** when the row is open at `local_hour`, **0** when the hours
are unknown, **−0.08** when it is known to be closed.

**Never a filter.** 1,424 of 1,605 rows have no hours at all; a filter would
delete 89% of the catalogue. That is the D119 lesson, already paid for once.

0.08 only registers once the jitter is at 0.25, which is why this follows §4.1.

### 4.4 A pass comes back gently (D139)

Three rules, currently collapsed into one.

- **A pass returns after three days.** Keep the floor — a place passed ten
  minutes ago must not reappear this session — and add a decay above it,
  `score × least(1, age_days / 7)`, so a four-day-old pass returns quietly and a
  month-old one at full strength. The floor is what stops a decayed near-zero
  score winning on jitter alone.
- **A Ngap never returns.** Correct as it stands. It lives in Bites.
- **A Later never returns either**, because D95 makes it a like. That is the
  real gap: a wishlist place is by definition unfinished business. Not built in
  this phase — see §8.

D135 already fixed the column this window measures from.

### 4.5 What Phase 1 does not change

The hard filters, the 0.30 proximity term and its `nearby_focus` multiplier, the
0.20 freshness percentile, the 0.10 dietary term, and the rating term that
cannot fire. The weights that move are the taste block's internals, the jitter,
and two new additive terms bounded at ±0.08 and ≤ 0.05 × position.

## 5. Phase 2 — Frontend

### 5.1 The drag stops rebuilding the deck

`swipe_deck.dart:436-447` drives `onPanUpdate` through `setState`. Every pointer
event — 60 to 120 a second on the app's core gesture — rebuilds the header, the
action bar, **both** `SwipeCard`s (each hosting a WebView) and two Vincenty
distance calculations at `:409, 412, 537, 540`. The `AnimatedBuilder(child:)` at
`:401-428` isolates the fly-out animation only; the drag walks straight past it.

Move the drag offset into a `ValueNotifier<Offset>` and keep the cards in the
builder's `child:`, the pattern the fly-out already uses. Hoist
`distanceLabelFor` and `players.warm` out of `build()` while there — a side
effect in `build()` is a bug waiting for a rebuild that does not come.

### 5.2 Tabs load when they are first seen (D140)

`dashboard_page.dart:300-330` uses an `IndexedStack`, which is right: it is what
stops the deck re-dealing every time the user glances at another tab. The
problem is what the tabs do in `initState`. All five mount at launch, so
`get_nearby`, `get_liked_restaurants`, `wishlist_items`, `get_friends` and
`get_friend_requests` all fire for tabs nobody has opened — about eleven round
trips on the cold-start path, three of them wasted.

Load on first reveal instead. Keep the tabs mounted; move the fetch.

### 5.3 The detail screen reuses the player it already has

`restaurant_detail_route.dart:95` → `restaurant_detail_page.dart:110` creates a
sixth WebView for the clip already playing behind it. Hand the detail screen the
existing handle.

### 5.4 The map's filter sheet stops drawing twice (done 2026-09-11)

`NearbyController.applyDiscoveryFilters` called `applyUser` after *both* writes.
The first call adopted the new radius under the old filters, so saving the sheet
refetched the map twice and threw the first answer away. `DeckController`'s copy
of the same method had already been fixed and carries the comment saying why;
the map's copy had drifted. It now holds the written row and applies it once, in
`finally`, exactly as the deck does. Pinned by
`test/features/nearby/nearby_discovery_apply_test.dart`.

### 5.5 Carried, not yet scheduled

Recorded with file and line in the audit, worth doing but not in this round:
image decode sizing (13 sites, no `cacheWidth` anywhere), no disk image cache,
the wishlist refetched per detail open, three sequential RPCs in
`plans.refresh()`, the two `ListView(children:)` sites that build every row per
keystroke, and the Bites grid's `get_liked_restaurants` fetching 200 rows with
every review body and dish row attached to paint a grid that shows a photo and a
name.

## 6. Phase 3 — Database structure

### 6.1 Distance stops being a full scan (D141)

There is **no geographic index of any kind** in the project — no PostGIS, no
earthdistance, no cube, no GiST, nothing. `haversine_km` is a function call in a
`where` clause, so it is non-sargable, and it is evaluated two to three times per
row across `deck_scored`, `get_nearby` and `search_restaurants`. Four guaranteed
sequential scans of the whole catalogue.

Add a bounding-box predicate on latitude and longitude plus one btree over the
pair, and keep haversine as the exact filter inside the box. PostGIS stays out
of scope (D9); this is the cheap version of the same idea.

### 6.2 The deck stops carrying the whole catalogue (D142)

Three things in one migration, all in `get_deck`:

- It sorts the whole scored catalogue carrying `r.*` — **including the `search`
  tsvector**. Sort on `(id, score)` and join the columns back after the limit.
- It runs the **entire ranker twice** whenever the first query returns fewer
  than the limit, which is the exhaustion path, not an edge case. One CTE.
- `set search_path` on `haversine_km`, `tiktok_video_id` and `deck_jitter`
  blocks SQL inlining, so every evaluation goes through the function executor
  instead of folding into arithmetic. Three lines, and it multiplies everything
  above. The security note this trades against is real and needs stating in the
  decision: these three are pure arithmetic helpers touching no table. Dropping
  `set search_path` re-raises Supabase's `function_search_path_mutable` advisor
  warning on all three, which D142 accepts on the record the way D109 accepted
  its own warning.
- `rows 300` misinforms the planner by 166×.

### 6.3 A stranger stops being able to vote (D143)

`plan_time_votes`'s insert policy checks `user_id = (select auth.uid())` and
nothing else. The `set_plan_vote` RPC is not the way in — it ends in
`returning`, and Postgres applies the *select* policy to an
`insert ... returning`, so a non-member's call raises. **Verified 2026-09-11**
against the live project with a throwaway table: a plain insert under a
`with check (true)` / `using (false)` pair is allowed; the same insert with
`returning` is refused.

The way in is a direct PostgREST insert asking for `Prefer: return=minimal`.
`get_plan_votes` does not filter the voters it returns, so the row lands in
everyone else's tally with the stranger's name on it, counts toward the leading
slot, and can put a time on the owner's "Move it to" button that nobody at the
dinner picked. Not a read leak — it corrupts the answer.

Add the membership test to the insert policy's `with check`. Belt and braces:
the same test inside `set_plan_vote`, and a voter join in `get_plan_votes`.

### 6.4 Hygiene, deliberately deferred

The advisor's thirteen "unused index" rows are an artefact of having no traffic —
one profile and 55 swipes. **Do not drop indexes on that evidence.** Re-check
after real usage. The unindexed `friendships_requester_id_fkey` is worth an
index when the graph is non-empty; it is empty today. The duplicate permissive
policies on `plans` and `plan_members` are the shape D109 and D132 chose
deliberately.

## 7. Phase 4 — Features

### 7.1 The end of the deck gets exits (D144)

The screen exists: `swipe_deck.dart:363` renders "That is everyone" / "No more
cards" / "Reload to keep swiping" with a single Reload action. Recycling old
passes is not automatic — it happens because the user presses Reload and the
next `get_deck` falls through to its three-day branch.

Two changes, per the owner's answer:

- **Widen the search**, opening the discovery sheet that owns the radius. The
  honest reason a deck ends is almost always the radius, and the fix should be
  one tap from the sentence that says so.
- **Say what Reload does** — that it brings back places skipped a few days ago.
  An unexplained reappearance is precisely what reads as a bug.

Wishlist and Make-a-plan exits were offered and not taken.

This is the one-sided market's honest answer to a like limit: the session ends
because you have seen everything near you, not because you spent an allowance.

### 7.2 Find friends from `/friends` (D145)

The app already promises this. `onboarding_steps.dart:671` tells a user who
matched nobody *"You can add friends later from the You tab"*, and nothing there
does it. This makes existing copy true.

`FriendsController.matchContacts` already exists and hashes on the way past;
`ContactsReader` is an injected typedef (D60); `sendRequests` already tolerates
partial failure. The work is a row above the requests heading that runs the same
read → match → tick → send sequence onboarding runs, rendered in a sheet that
closes.

**Do not extract a shared widget** from `OnboardingFriendsStep`. Its three
states are wired to a wizard draft. Reuse the controller, not the widget.

Two copy obligations: the privacy line (D127, D128) appears here verbatim, and
the empty state at `friends_page.dart:133` — "contacts are matched once, during
sign-up, and nothing re-scans them" — becomes false the moment this ships and
must be rewritten. No automatic re-scan: the owner chose the explicit row.

### 7.3 Autoplay (D146)

A three-state control in the You tab — **Always / On Wi-Fi only / Never** —
defaulting to **Always**, because changing the default would change the product
on day one for a video app.

Cheaper than it looks: D41 means the card *behind* the top one already renders a
thumbnail rather than a WebView, so "off" is that treatment on the front card
plus a play glyph, and a tap mounts the player. No new rendering path;
`TikTokPlayerCache` simply stops being warmed.

**Wi-Fi only needs `connectivity_plus`**, which is not in `pubspec.yaml` today.
It must be constructor-injected per D60, because `flutter test` has no platform
channel for it.

**Skip auto-advance.** A card that leaves on its own is a decision the user did
not make, and every card exit here writes a row to `swipes`.

### 7.4 "Did you go? Would you go back?" (D147)

The owner's instruction: *if they already go, ask for review — if the feature is
not there, develop it as good as it can.*

The pieces that exist: `visit_prompt_sheet.dart` and `VisitPromptController`
already ask about a trip, triggered by the directions button, and stamp
`swipes.visited_at`. The `reviews` table exists with 6 rows. What does not exist
is any path from a *plan* to that question, or any way for a user to leave a
rating at all.

To build:

- A prompt after a plan's date has passed: *did you go?*
- On yes, the review: a rating and an optional line, written to `reviews`, with
  `visited_at` stamped.
- The restaurant's own `rating` follows from those rows rather than staying the
  dead column it is today.

This is the strongest signal the app can collect and the only one that is not a
proxy for intent. It is also the only realistic route out of "2 of 1,607 rows
are rated", which is the root cause of both the inert quality term and the
oversized jitter.

Sizing and the exact write path are settled when this phase is designed; it is
the largest item in the plan and the one most worth getting right.

## 8. Compliance (D148)

The published privacy page says **"We do not ask for your contacts."** The app
declares `READ_CONTACTS` on Android and `NSContactsUsageDescription` on iOS, and
reads the address book during onboarding. `PrivacyInfo.xcprivacy` declares no
contacts type. The same page still describes passport, removed by D84 and D121.

The contacts sentence and the passport one are the two that are outright wrong,
but the fix is not two sentences. "What we collect" still lists an Explore map
and "marked as visited" and says nothing about friendships, plan membership,
plan votes, the wishlist, or the hashed phone numbers §7.2 would store — so the
section is rewritten against the 22 tables that exist, not patched twice.

Per the owner: **fix the text and the manifest, do not deploy.** The edge
function `supabase/functions/legal/index.ts` is edited in the repo and left for
the owner to ship, so nobody publishes legal copy the owner has not read. The
store data-safety forms say the same things in Play Console and App Store
Connect; those are dashboard work and no commit here can change them.

The honest wording says what is true: phone numbers are hashed on the device
before they are sent, the raw contact list never leaves the phone, and the
digest is what is matched.

## 9. What this plan will not do, and why

Every one of these is a mechanism a dating app uses that does not survive the
translation to a one-sided market.

| Rejected | Why |
|---|---|
| Reciprocity / "likes you" scoring | A restaurant cannot swipe back. There is no other side to protect. |
| Daily swipe limit, Swipe Surge, Boost | Scarcity mechanics that exist to ration attention between *people*. Here they would ration a catalogue against its own user. D84 already removed the limit once. |
| A match celebration | Removed by D84. A restaurant cannot agree to meet you. |
| Popularity prior (rank by what everyone likes) | Would need to be earned, not assumed; with one profile and 55 swipes there is no population to learn from. Revisit when there is. |
| Thompson sampling / bandit exploration | The jitter already buys exploration, and at 0.25 it will be better calibrated than a bandit fitted to 55 observations. |
| Video watch percentage as a signal | Would require scripting TikTok's player beyond its documented message API. Not attempted. Whether the player exposes `onCurrentTime` through a JavaScript channel is **unverified** and would need a device test, not a code reading. |
| Auto-advancing cards | Writes a swipe row the user did not choose to write. |
| Dropping the 13 "unused" indexes | The lint is an artefact of having no traffic. |
| PostGIS | D9 stands. The bounding box in §6.1 buys most of it for none of the operational cost. |

## 10. Open questions

1. **The two implicit columns.** `dwell_ms` and `unmuted` on `swipes`, written by
   the deck, read by nothing until there are months of rows. Offered alongside
   the review prompt; the owner's answer addressed the review and not these.
   Cheap now, impossible to backfill later. **Needs a yes or no.**
2. **A Later returning to the deck after 14 days**, as a visually distinct card
   ("You saved this — still want it?"), capped at one per deck. It amends D95,
   which is why it is not assumed.
3. **Sound on by default.** Both platforms are already configured for
   gesture-free playback, so an unmuted autoplay is *plausible* — but D89
   assumes otherwise and whether audio actually starts without a gesture is a
   device question. Needs a device before it can be promised.
4. **Where ratings and hours come from.** §7.4 starts collecting ratings from
   people who actually went, but 1,424 rows still have no hours, which caps how
   much §4.3 can ever be worth.
5. **What a review is, exactly.** Three answers §7.4 cannot invent for itself:
   the scale (thumbs, or 1–5), whether one person's review is visible to anyone
   but them, and whether `restaurants.rating` becomes a blend of real reviews or
   stays the imported number with user reviews kept beside it. **Asked before
   §7.4 starts**, not during.

## 11. Decisions this plan proposes

To be added to [DECISIONS.md](DECISIONS.md) as each phase lands. D135 is
already locked; these are reserved.

| ID | Decision |
|---|---|
| D136 | Cuisine affinity is a shrunk like-rate over deck exposures, with the onboarding pick as a degenerate prior |
| D137 | Deck diversity is a soft per-position penalty, not a round-robin; the jitter halves only once it is in |
| D138 | Open-now is a ±0.08 bonus, never a filter |
| D139 | A pass returns on a decay above a three-day floor |
| D140 | A tab loads on first reveal, not on mount; the IndexedStack stays |
| D141 | Distance is filtered by bounding box first, haversine second; still no PostGIS |
| D142 | `get_deck` sorts on identity and score, ranks once, and lets its arithmetic helpers inline |
| D143 | A vote write tests plan membership, not just caller identity |
| D144 | The end of the deck is an explained state with an exit, not a dead end |
| D145 | Contact matching is reachable from `/friends` on an explicit tap, never automatically |
| D146 | Autoplay is a three-state setting defaulting to Always; no auto-advance |
| D147 | The post-plan question collects a real review, and is the app's only non-proxy signal |
| D148 | The privacy page describes contact matching honestly; hashing happens on the device |

## 12. Order of work

1. **Phase 3 §6.3** — the vote hole. Correctness first, and it is small.
2. **Phase 3 §6.2** — the `get_deck` rewrite, *before* any ranking term. §4.1
   and §4.4 both edit the body §6.2 restructures, and §4.4's decay lives inside
   the exhaustion branch §6.2 removes. Written in the other order, `get_deck` is
   rewritten twice and verified twice.
3. **Phase 3 §6.1** — the bounding box and its index, on the new shape.
4. **Phase 1** — ranking, one term at a time in the order §4 gives.
5. **Phase 2** — the three frontend fixes.
6. **Phase 4** — end-of-deck exits, then contacts, then autoplay, then the
   review prompt, which is the largest and goes last.
7. **§8** — the privacy text, any time; it blocks a submission, not a build.

Every step ends on the gate — `flutter analyze lib test` then `flutter test` —
and every migration is verified by re-reading the live definition afterwards,
the way D135 was.
