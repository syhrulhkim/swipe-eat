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
so the 0.15 quality weight is dead and the jitter runs at its unrated value on
every card — 0.50 when this plan was written, 0.25 since D137 landed. And
**the live data cannot tell you whether a query is slow** — 1,607 rows fit in
memory, so the planner's current choices prove nothing about 50,000. Where a
finding is scale-dependent it is labelled as such rather than dressed up as a
present-day emergency.

## 4. Phase 1 — Ranking

All of it is inside `deck_scored` and `get_deck`. No client change. Built and
verified one term at a time, in this order, because each later term is only
measurable once the earlier one has taken the noise out.

### 4.1 Cuisine diversity, then cut the jitter (D137 — done 2026-09-11)

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

**Landed** in `20260911160000_a_deck_that_is_not_five_satay_stalls`, at **0.02
rather than 0.05**. The plan guessed the constant; the deck was then measured.
The top sixty candidates of a real 30 km deck span 0.211 of score, so 0.05
drops a cuisine's fifth card below the sixtieth-best card — a round robin in
all but name, and it would have cancelled §4.2 before it shipped. Over that
deck:

| Penalty | Distinct in first 10 | Distinct in 30 | Longest run |
|---|---|---|---|
| none | 6 | 10 | 3 |
| 0.02 | 6 | 14 | 1 |
| 0.05 | 8 | 18 | 1 |

0.02 leaves a liked cuisine about eight cards before the penalty eats the edge
§4.2 gives it. Against the pre-D137 deck (jitter still at 0.50) the same
measurement read 5 distinct in the first ten, 8 in thirty, longest run 4.

### 4.2 Per-user cuisine affinity (D136 — done 2026-09-11)

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

**Landed** in `20260911170000_the_deck_learns_from_a_swipe`, as written. The
`affinity` CTE joins `swipes` to `restaurant_cuisines`, the `taste` CTE left
joins it and `matches_pick` becomes `pick_score`,
`max(coalesce(a.p_like, <the old 1-or-0>))`.

Two checks. **A caller with no swipes gets the identical deck** — three
argument sets of `get_deck` (a 30 km Johor deck, a 10 km KL deck, and the
no-location branch) hash the same before and after, which is what the
degenerate prior was for. And the real profile's own 30 km deck moves the way
the swipes say it should:

| Cuisine | Deck swipes | Liked | Onboarding pick | `p_like` | Cards, before → after |
|---|---|---|---|---|---|
| Indian | 8 | 3 | yes | 0.50 | 4 → 2 |
| Chinese | 3 | 3 | no | 0.60 | 2 → 4 |
| Dessert | 3 | 3 | no | 0.60 | 4 → 6 |
| Café | 9 | 5 | no | 0.455 | 3 → 4 |
| Thai | 1 | 0 | no | 0.00 | 1 → 0 |
| Korean | 1 | 0 | yes | 0.667 | 1 → 0 |

The picked cuisine they keep passing on loses half its slots; the unpicked
cuisine they have liked every time doubles. Measured with `halal_only`
temporarily off inside a rolled-back transaction, because with it on the real
profile has 8 candidates in 30 km and has swiped all of them — a separate
finding, recorded in §10.

The same migration repairs a regression this plan created: D142 raised
`deck_scored`'s row estimate to `rows 1600`, and the two `create or replace`
statements after it (§6.1 and §4.1) carried the old `rows 300` forward in the
repo files. Live never had it — both were applied by rewriting the stored
definition, which keeps the attribute — so this was a replay-from-empty bug
only. Both files are corrected in place.

### 4.3 Open now (D138 — done 2026-09-11)

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

**Landed** in `20260911190000_a_place_that_is_shut_ranks_like_it`, as written.
`is_open_at` is called per candidate row from `deck_scored`'s `candidates`
CTE, against a moment `ctx` now resolves: `now()` in production, and that hour
of today in Kuala Lumpur when a caller pins `p_local_hour`, so one argument
steers both this term and morning mode. Verified by pinning it — at 03:00 the
top sixty hold 25 rows with hours, at 12:00 they hold 47.

Over a real 522-card 30 km deck (109 open, 44 shut, 369 with no hours), the
top sixty:

| | Open | Shut | Hours unknown |
|---|---|---|---|
| Before | 24 | 13 | 23 |
| After | **42** | **5** | 13 |

The rows known to be shut mostly leave, which is the point; the rows with no
hours pay for it, which is the honest cost. They rank below a place known to
be open and above one known to be shut, both of which are true statements —
the third line moves when hours coverage moves, not when the weight shrinks
(§10.4).

`is_open_at` is plpgsql, so it cannot be inlined and runs once per candidate:
31.5 ms mean → 33.6 ms over 20 runs. Two milliseconds for a term the user can
act on.

### 4.4 A pass comes back gently (D139 — done 2026-09-11)

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

**Landed** in `20260911200000_a_pass_comes_back_gently`, as written. A
`decayed` CTE sits between `scored` and the diversity penalty, so the penalty
counts positions in the order the user will actually see. `greatest(score, 0)`
guards the multiply: D138's penalty can in principle take a signal-less row
below zero, and multiplying a negative by a fraction raises it.

Two checks. **A deck that is not exhausted is untouched** — two argument sets
hash identically with the decay reverted inside a rolled-back transaction,
which is what "only bucket 1, and bucket 0 sorts first" should mean. And on a
genuinely exhausted deck — every one of 522 candidates passed, ages spread
from 4 to 33 days, backdated with the `swipes_touch_updated_at` trigger
disabled inside a rolled-back transaction — the top thirty hold **0** cards
younger than a week where the undecayed order held 4, and the mean age of the
thirty rises from 18.0 to 20.3 days.

### 4.5 What Phase 1 does not change

The hard filters, the 0.30 proximity term and its `nearby_focus` multiplier, the
0.20 freshness percentile, the 0.10 dietary term, and the rating term that
cannot fire. The weights that move are the taste block's internals, the jitter,
and two new additive terms bounded at ±0.08 and ≤ 0.05 × position.

## 5. Phase 2 — Frontend

### 5.1 The drag stops rebuilding the deck (done 2026-09-11)

`swipe_deck.dart:436-447` drives `onPanUpdate` through `setState`. Every pointer
event — 60 to 120 a second on the app's core gesture — rebuilds the header, the
action bar, **both** `SwipeCard`s (each hosting a WebView) and two Vincenty
distance calculations at `:409, 412, 537, 540`. The `AnimatedBuilder(child:)` at
`:401-428` isolates the fly-out animation only; the drag walks straight past it.

Move the drag offset into a `ValueNotifier<Offset>` and keep the cards in the
builder's `child:`, the pattern the fly-out already uses. Hoist
`distanceLabelFor` and `players.warm` out of `build()` while there — a side
effect in `build()` is a bug waiting for a rebuild that does not come.

**Done.** `_dragOffset` is now a getter/setter pair over a
`ValueNotifier<Offset>`, so all twelve existing read and write sites are
unchanged, and both `AnimatedBuilder`s listen to
`Listenable.merge([_motionController, _drag])` instead of the controller
alone. `onPanUpdate` loses its `setState`; every other `setState` stays,
because `_motionType` gates the gesture callbacks in `build` and a change to
it does need a rebuild. The cards were already in the builders' `child:`.

**The hoist was deliberately not done.** Its whole argument was the per-frame
rebuild: `distanceLabelFor` runs a Vincenty calculation and `players.warm`
mutates the LRU, twice each per build. With the drag no longer rebuilding, the
deck builds on load, on advance and on a controller notification — a handful
of times a session, where it used to be 120 a second. Moving the warm out of
`build` means moving the player lifecycle, which is a change worth making on
its own evidence, not as a rider.

**No widget test.** `SwipeDeck` has never been mountable in the harness — the
suite tests `DeckHeader`, `DeckActionBar` and `SwipeCard` separately for that
reason — and an attempt to mount it for this hung `flutter_tester` outright
rather than failing. The change adds no branch: it moves where a repaint is
requested from.

### 5.2 Tabs load when they are first seen (D140 — done 2026-09-11)

`dashboard_page.dart:300-330` uses an `IndexedStack`, which is right: it is what
stops the deck re-dealing every time the user glances at another tab. The
problem is what the tabs do in `initState`. All five mount at launch, so
`get_nearby`, `get_liked_restaurants`, `wishlist_items`, `get_friends` and
`get_friend_requests` all fire for tabs nobody has opened — about eleven round
trips on the cold-start path, three of them wasted.

Load on first reveal instead. Keep the tabs mounted; move the fetch.

**Done**, and more cheaply than "move the fetch": a 25-line `_RevealOnce`
wrapper around the four tabs behind the deck renders an empty box until its
index is first selected, then the real tab for the rest of the session. No tab
had to change, and "mounted once revealed, mounted forever" is the same
promise the `IndexedStack` was already making.

Two things the first attempt got wrong, both worth the words:

- **The reveal is deferred by one frame.** Tabs fetch from `initState`, and a
  controller that answers synchronously — `PlansController` does, once the
  dashboard has loaded it — notifies while the framework is building that tab.
  The shell is its ancestor and was built earlier in the same frame, so
  marking it dirty is an error, not a late rebuild. The wrapper schedules the
  reveal in a post-frame callback, and `_onPlansChanged` defers its own
  `setState` when a build is in flight. The tab shows an empty box for one
  frame, behind a fade that lasts a good deal longer.
- **An unselected tab is offstage**, so `find.byType` skips it. The test pins
  the behaviour with `skipOffstage: false`, which is the difference between
  "not mounted" and "not painted".

Pinned by `dashboard_bottom_nav_test.dart`: no `NearbyTab` or `CalendarTab` in
the tree at launch, the calendar mounts when its tab is first tapped, and it is
still there after the user goes back to the deck.

### 5.3 The detail screen reuses the player it already has (D150 — done 2026-09-11)

`restaurant_detail_route.dart:95` → `restaurant_detail_page.dart:110` creates a
sixth WebView for the clip already playing behind it. Hand the detail screen the
existing handle.

**Done**, and the page needed no change: `RestaurantDetailPage` already took a
`tiktokPlayerFuture` and already knew not to release a player it did not
create — the route simply never passed one. The handle now rides in the
router's `extra` map under `kLentPlayerKey`, put there by `_openDetail` and
pulled out by the `/restaurant/:id` builder.

The one real constraint: a `WebViewController` cannot be mounted in two
`WebViewWidget`s, and the deck's card stays alive under the route. So the card
gives its clip up for the length of the loan — `SwipeCard.videoLent`, the same
shape as `DetailHero.videoHiddenForFullscreen`, which is this exact trade made
once already. Nobody sees the photo it falls back to: the route above it is
opaque.

Pinned by `swipe_card_test.dart` — a lent card paints no player and no sound
pill.

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

### 6.1 Distance stops being a full scan (D141 — done 2026-09-11)

There is **no geographic index of any kind** in the project — no PostGIS, no
earthdistance, no cube, no GiST, nothing. `haversine_km` is a function call in a
`where` clause, so it is non-sargable, and it is evaluated two to three times per
row across `deck_scored`, `get_nearby` and `search_restaurants`. Four guaranteed
sequential scans of the whole catalogue.

Add a bounding-box predicate on latitude and longitude plus one btree over the
pair, and keep haversine as the exact filter inside the box. PostGIS stays out
of scope (D9); this is the cheap version of the same idea.

Landed in `20260911150000_the_box_before_the_circle`, one partial index on
`(latitude, longitude) where is_active` plus the predicate in `deck_scored` and
`get_nearby`. `search_restaurants` was left alone: the audit found it has no
production caller. Measured, twenty warm calls each:

| Call | Before | After |
|---|---|---|
| `get_nearby(3 km)` | 15.41 ms | **5.66 ms** |
| `get_deck(30 km)` | 26.89 ms | 25.10 ms |
| `get_deck(500 km)` | 28.00 ms | 32.13 ms |

The map is the win, because its whole answer is the circle. The deck barely
moves, because ranking is most of its work either way. At 500 km the box covers
the catalogue and the planner takes the index anyway, paying for a scan it
cannot narrow — no radius the app offers is near that, and a null radius skips
the predicate entirely. The distance filter in isolation goes 3.99 ms → 0.49 ms
at 30 km. Correctness first: 120 random origins at random radii, function row
count against a raw haversine count, zero mismatches.

### 6.2 The deck stops carrying the whole catalogue (D142 — done 2026-09-11)

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
- `rows 300` misinforms the planner about a function that returns up to 1,607.

Landed in `20260911140000_the_deck_ranks_once_and_sorts_on_identity`. Measured
on the live project at 576 candidates: **52 ms → 37 ms**, 3,725 → 2,673 shared
buffers, with the exhaustion path no longer ranking twice. Equivalence checked
before and after on three argument sets and, with the touch trigger disabled
inside a rolled-back transaction, on the resurfacing branch: the same ids in the
same order every time. The three `function_search_path_mutable` warnings are now
in the advisor output and are accepted by name.

### 6.3 A stranger stops being able to vote (D143 — done 2026-09-11)

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

All three landed in `20260911120000_a_vote_needs_a_seat_at_the_table`: the
membership test in the insert *and* update policies' `with check`, the same test
inside `set_plan_vote` so the app hears a sentence rather than an RLS violation,
and a voter filter in `get_plan_votes` that retires any row written before the
fix without deleting it. Verified against the live project afterwards — a
stranger's plain insert is refused, the owner's vote still lands and still shows
in the tally, and both function bodies hash equal to the migration file.

### 6.4 Hygiene, deliberately deferred

The advisor's thirteen "unused index" rows are an artefact of having no traffic —
one profile and 55 swipes. **Do not drop indexes on that evidence.** Re-check
after real usage. The unindexed `friendships_requester_id_fkey` is worth an
index when the graph is non-empty; it is empty today. The duplicate permissive
policies on `plans` and `plan_members` are the shape D109 and D132 chose
deliberately.

## 7. Phase 4 — Features

### 7.1 The end of the deck gets exits (D144 — done 2026-09-11)

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

**Done**, in `swipe_deck.dart`, and it cost nothing structural: `_messageCard`
already took a secondary action that nothing passed. The exhausted card now
reads "Reload brings back places you skipped a few days ago. Widening the
search finds new ones." with **Widen the search** opening the discovery sheet.
The rules-emptied state gets **Change the rules** beside its Reload, on the
same argument — its sentence already named the rule, and the screen that owns
the rule was two taps away through the header.

This is the one-sided market's honest answer to a like limit: the session ends
because you have seen everything near you, not because you spent an allowance.

### 7.2 Find friends from `/friends` (D145 — done 2026-09-11)

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

**Done**, in `find_friends_sheet.dart` plus a row on `FriendsPage`. Both copy
obligations are met: the privacy line is `OnboardingFriendsStep.privacyLine`
itself rather than a second copy of the words, and the empty state now reads
"Nobody yet. Check your contacts above, or wait for a request to come in."
`Friends.md`'s "matched once, at sign-up" paragraph is rewritten on the same
grounds.

`readContacts` is injected into the page the way onboarding injects it (D60),
which is what lets the test drive the whole sequence: three tests cover the row
appearing in an empty book, a match-tick-send round trip that asserts only
hashes left the device, and a contact taken off the list not being asked.

### 7.3 Autoplay (D146 — done 2026-09-11)

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

**Done.** `AutoplaySetting` and `AutoplayController` (prefs-backed, Wi-Fi
watched through an injected `Stream<bool>`), a `Playback` section in the You
tab using the `PrefSegmented` control the spice row already uses, and three
lines of gating in the deck: no warm ahead, no player passed, and
`SwipeCard.autoplay` false, which paints a **Tap to play** pill where the
sound pill would be. Pressing it asks the deck rather than building a player
on the card, so every player still comes from the one cache that knows how to
evict it.

The estimate held — the card already had the "show the photo instead" path
from D41 and D150, so this added a pill and a flag rather than a rendering
mode. Six controller tests and one card test; `connectivity_plus` is in
`pubspec.yaml` and in STACK.md's table.

### 7.4 "Did you go? Would you go back?" (D147 — done 2026-09-11)

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

**Done.** Smaller than its billing, because three of the four pieces already
existed and only needed connecting.

- **`reviews` gained one column**, `rating smallint` 1–5, plus a partial unique
  index on `(user_id, restaurant_id)` so a second visit edits the first rather
  than stacking. No new table: the row already had the restaurant, the author
  and the body.
- **One RPC for the whole sheet.** `record_visit_answer(p_restaurant_id,
  p_went, p_rating, p_body, p_plan_id)` — "I didn't go", "I went", and "I went
  and here are four stars" are one question answered three ways. Security
  definer, because `reviews` has no write policy: this is the only way a review
  is written.
- **`restaurants.rating` follows the stars by trigger**, not from the write
  path, so a row edited or deleted by any route still leaves the column true.
  Measured on a rolled-back transaction: two answers for one restaurant left
  one review row, `rating` 2.0, `visited_at` stamped, and the author name
  taken from the profile.
- **The plan path is `next_visit_prompt(p_today)`** — the caller's most recent
  `kept` plan in the last 14 days they have not rated. Verified against the
  live database: a plan three days old prompted, "I didn't go" moved it to
  `cancelled`, and the next call moved on to the next unrated plan.
- **The fence is a policy, not a query.** An authored review is readable by its
  author and their accepted friends; the six seeded snippets have a null author
  and stay public. Proved by reading the same restaurant's reviews as the
  author (1 row) and as a stranger (0). Worth recording: all six seeded rows sit
  on **inactive** restaurants, so they were already invisible to everyone — the
  "6 reviews across the catalogue" this plan kept citing were never on screen.

The sheet is the existing one with five stars, a 280-character optional line and
a button that renames itself to **Post it** once a star is lit. Six tests
(`visit_prompt_test.dart`); the client asks the backend for a plan prompt
**once per app run**, since `_maybeAskAboutVisit` fires on every resume.

One thing this does not do: **show a review back to anyone.** The detail page
dropped its review card in the redesign, and a friend's stars have no surface
yet. Recorded in [Likes-Visits](../Features/Likes-Visits.md) §6.

## 8. Compliance (D148 — done 2026-09-11, not deployed)

The published privacy page says **"We do not ask for your contacts."** The app
declares `READ_CONTACTS` on Android and `NSContactsUsageDescription` on iOS, and
reads the address book during onboarding. `PrivacyInfo.xcprivacy` declares no
contacts type. The same page still describes passport, removed by D84 and D121.

The contacts sentence and the passport one are the two that are outright wrong,
but the fix is not two sentences. "What we collect" still lists an Explore map
and "marked as visited" and says nothing about friendships, plan membership,
plan votes, the wishlist, or the hashed phone numbers §7.2 would store — so the
section is rewritten against the 22 tables that exist, not patched twice.

D147 adds a second thing that page does not say: **a user's stars and their
line are shown to their friends** — the app's first user-written content that
leaves its author. The rewrite covers it, the store listing's data-safety form
must too.

Per the owner: **fix the text and the manifest, do not deploy.** The edge
function `supabase/functions/legal/index.ts` is edited in the repo and left for
the owner to ship, so nobody publishes legal copy the owner has not read. The
store data-safety forms say the same things in Play Console and App Store
Connect; those are dashboard work and no commit here can change them.

The honest wording says what is true: phone numbers are hashed on the device
before they are sent, the raw contact list never leaves the phone, and the
digest is what is matched.

**Done — in the repo. Nothing is published.**

Reading the schema for the rewrite turned up a third wrong sentence and a real
leak, neither of which was on this list:

- **"Anonymous counts of how often a restaurant was swiped on" do not survive a
  deletion.** `swipes.user_id` is `on delete cascade` and always has been. The
  claim was in the privacy page *and* in `delete-account`'s own header comment,
  which is where it presumably came from. Both are corrected.
- **`reviews.user_id` was `on delete set null`** (D51). That was right while the
  table held six scraped snippets. After D147 it meant: delete your account and
  your review stays, carrying your name, and — because the new read policy
  treats a null `user_id` as a seeded catalogue snippet — it becomes readable by
  **everyone** instead of your friends. Reversed to cascade; the rating trigger
  takes the average back down with the row.

The rewritten "What we collect" is written against the twelve tables that hold
personal data, not the four it used to name: location, taste, what you do with
restaurants (including D149's dwell and sound), plans and their votes, friends,
contacts, reviews, crash reports. `PrivacyInfo.xcprivacy` gains **Contacts** and
**Other user content**, and its passport comment is gone. The terms page gains a
short "What you write". `STORE.md` now lists what each store form must say.

**What is left is not code.** `supabase functions deploy legal` is the owner's
to run, and the two store forms are dashboard work.

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

1. ~~**The two implicit columns.**~~ **Answered 2026-09-11: add both now, and
   landed the same day** as D149, `20260911180000_a_swipe_remembers_how_long_and_how_loud`.
   `dwell_ms` and `unmuted` on `swipes`, written by the deck, read by nothing
   until there are months of rows. Cheap now, impossible to backfill later.
2. **A Later returning to the deck after 14 days**, as a visually distinct card
   ("You saved this — still want it?"), capped at one per deck. It amends D95,
   which is why it is not assumed.
3. **Sound on by default.** Both platforms are already configured for
   gesture-free playback, so an unmuted autoplay is *plausible* — but D89
   assumes otherwise and whether audio actually starts without a gesture is a
   device question. Needs a device before it can be promised.
4. **Where ratings and hours come from.** §7.4 starts collecting ratings from
   people who actually went, but 1,424 rows still have no hours, which caps how
   much §4.3 can ever be worth — and now costs them: since D138 a row with no
   hours ranks 0.08 below one known to be open, so poor coverage is no longer
   merely a missing chip.
5. ~~**What a review is, exactly.**~~ **Answered 2026-09-11: 1–5 stars,
   visible to friends, and `restaurants.rating` becomes the average of those
   stars.** So §7.4 builds a star scale rather than thumbs, a friends-visible
   reviews block on the detail screen, and a write path that moves the rating
   column from imported-and-dead to earned. Two things that answer brings with
   it and the plan did not have before: friend visibility means `reviews` needs
   an RLS policy shaped like the friendship one, and a user-written line that
   other people can read is the app's first piece of user-generated content
   that leaves its author — which the store listing and the privacy page both
   have to say.
6. **`halal_only` is a wall, not a filter.** Found while measuring §4.2: with
   the flag on, the one real profile has **8** candidates inside 30 km and has
   already swiped all of them, so its deck is empty. `is_halal` is set on a
   small minority of rows, and the app treats an unset flag as "not halal".
   Whether the fix is backfilling the flag, or reading it from cuisine and
   dietary tags, or saying out loud that an unknown place might not be halal,
   is a data question and a product question, not a ranking one. **Needs an
   answer before the flag is offered to real users.**

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
