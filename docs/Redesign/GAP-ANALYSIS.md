Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [README.md](README.md), [SCREENS.md](SCREENS.md), [NGAP-DESIGN-SYSTEM.md](NGAP-DESIGN-SYSTEM.md), [Features/Backend-Schema.md](../Features/Backend-Schema.md), [General/PLAN.md](../General/PLAN.md)

# Gap Analysis — built vs. Ngap

Every delta between what ships today and what the new design needs. Ordered by
what blocks the most.

**The headline:** the client's presentation layer changes almost completely, but
the hard problem is **data**. The new design asks for opening hours, prices,
dishes, neighbourhoods and a social graph — and today's schema explicitly
declares two of those *not buildable* because no column and no source exist.

> **Status, 2026-09-10.** Most of §1 has since been closed. Hours, prices,
> halal and neighbourhood are columns as of 2026-09-05 (§1.1, §1.2); the social
> graph, contact matching, invites and time voting shipped 2026-09-06/09 (§1.4,
> §1.5) — see [Features/Friends.md](../Features/Friends.md) and
> [Features/Plans-Calendar.md](../Features/Plans-Calendar.md). What is left is
> **coverage, not capability**: only 194 rows have hours, 186 a price, 30 a
> halal answer, and `dishes` is still empty. The analysis below is kept as
> written, because its reasoning is why those things were built the way they
> were; read it against the status notes, not instead of them.

## 1. The blocking gaps

These gate whole screens. Nothing else is worth starting first.

### 1.1 Opening hours — blocks 5 screens

The design shows an open/closed state almost everywhere:

| Screen | String |
|---|---|
| Location (01c) | "38 places **open** within 3 km" |
| Detail (03) | "open till 2 am" |
| Wishlist (08) | "open 24 h" |
| Map (09) | "Open", "Open · 24 h", "Closes 10 pm", "**Open now** 6" |
| — | `--fresh` exists **solely** as the "open now" indicator |

**Today:** no column, no source. [Backend-Schema](../Features/Backend-Schema.md)
lists price and hours under *Out of scope* — "no source populates them, so the
filters they would enable are not buildable."

The scraper *parses* the clock line (`⏰ 9:30am - 9:30pm (Daily)`) — but only to
**terminate the address**. It throws the hours away. That is the cheapest
possible fix in the whole document: the data is already in the captions.

**Needs:** an hours representation (per-weekday open/close, plus 24h and closed
flags), a scraper change to keep what it already reads, and a backfill.

**Built 2026-09-05** (D91): `hours_text`, `opens_at`, `closes_at`, `closed_dow`
on `restaurants`, and `is_open_at()` behind `get_nearby`'s `open_now`. 194 rows
have hours — the captions that carried them.

### 1.2 Price / budget — blocks 4 screens

| Screen | Use |
|---|---|
| Diet (01e) | Budget-per-person range slider, RM 5–100+ |
| Detail (03) | "RM 8–15 per person" fact, **per-dish prices** |
| Map (09) | "From RM 8" |
| You (10) | "Budget per person · RM 10–40" |

**Today:** no column, no source, and it is a *filter* in the new design — so it
cannot be left null the way `rating` was. A budget filter against missing prices
empties the deck, exactly as `filter_min_rating` does now.

**Needs:** a price band on `restaurants` (a low/high RM pair), per-dish prices,
and a source. TikTok captions sometimes carry prices; mostly they do not.

### 1.3 Dishes — blocks the detail screen's core section

"What people bite" is the detail screen's main content, and it **replaces the
review carousel**. Name, description, RM price, thumbnail, per restaurant.

**Today:** no table, nothing like it. `reviews` (6 rows) is the nearest thing
and is being retired from this screen.

**Needs:** a `dishes` table and a source. This is the hardest to populate —
menus are not in the captions.

### 1.4 The social graph — blocks 3 screens

Friends (01f), Invite (05) and half of Calendar (06) and Detail (03).

**Today:** none of it. `profiles` has no relationships; `profiles.role` is dead
weight; there is no user-to-user anything in the 15 tables and 16 RLS policies
of the day (22 and 35 now).

**Shipped 2026-09-06/09** — `friendships`, `phone_hashes`, contact matching,
`/friends`, plan invites and time voting. `profiles` was **not** relaxed: every
cross-user read is a `security definer` function returning id, name and avatar
url and nothing else (D129), and matching is server-side on a peppered hash
rather than on-device, because the copy that promised otherwise was rewritten
(D127). See [Features/Friends.md](../Features/Friends.md).

**Needs:**

- A friendships table with a request/accept state.
- **On-device contact matching** — the privacy promise is explicit: *"We don't
  upload your contacts. Matching happens on your phone."* That means hashing
  contacts locally and querying by hash; the server never sees an address book.
- Friend-visible profile fields: portrait, neighbourhood, bite count, dietary
  tags — each of which is a new RLS problem, because today `profiles` is
  strictly owner-only (`select` where `id = auth.uid()`). **Every friend-facing
  string in the design requires relaxing that policy**, carefully.
- The Invite screen's context lines each need a different join: likes overlap,
  availability, friend home distance to the venue, friend diet, shared plan
  history.

### 1.5 Plans — blocks 3 screens

Pick a date (04), Invite (05), Calendar (06), plus "Set a date" on Detail.

**Today:** nothing. There is no scheduling concept in the product.

**Needs:** a plans table (restaurant, date, time slot, owner), plan members
with an invite state, and **time voting** — *"they'll get a vote on the time"*.
Plus "plans kept" for the profile stat, which implies a plan has an outcome.

## 2. Schema delta

Against the as-built schema in
[Features/Backend-Schema.md](../Features/Backend-Schema.md).

### New tables

| Table | For | Notes |
|---|---|---|
| `restaurant_hours` | §1.1 | Per-weekday; needs 24h and closed cases |
| `dishes` | §1.3 | name, description, price, photo, position |
| `friendships` | §1.4 | Requester/addressee + state; needs a symmetric-read policy |
| `contact_hashes` | §1.4 | For on-device matching, if server-side lookup is used |
| `plans` | §1.5 | restaurant, date, time, owner, state |
| `plan_members` | §1.5 | invite state per person |
| `plan_time_votes` | §1.5 | the "vote on the time" feature |
| `wishlist_items` | Wishlist | **Must allow free text** — the add field accepts a place that is not in the catalogue, so `restaurant_id` is nullable and a `label` is needed |
| `neighbourhoods` | Everywhere | Or a column; see below |

### Changed tables

| Table | Change |
|---|---|
| `restaurants` | `+ price_low`, `+ price_high` (RM); `+ neighbourhood`; `+ is_halal`; `+ wait_minutes`; `+ video_duration_seconds`; `+ ngap_count` (or a view) |
| `profiles` | `+ budget_min`, `+ budget_max`; `+ halal_only`; `+ vegetarian_options`; `+ autoplay_preference`; `+ neighbourhood`; `+ portrait_url` (or reuse `avatar_url`, currently unused); **`spice_bias` must be reconciled — see §4.1** |
| `swipes` | `+ later` / or a separate wishlist path, since up-swipe now means "save for later", not super like. **`super_like` becomes dead** |
| `cuisines` | `+ cover_photo` per cuisine as a **photo**, and `emoji` becomes forbidden output — see §4.2 |
| `dietary_tags` | Halal becomes a first-class hard filter and a badge, not one tag among six |

### Retired

| Thing | Why |
|---|---|
| `swipes.super_like` | No super like in the new design |
| `get_super_liked_ids()` | Same |
| `cuisines.emoji` | "No emoji as food imagery" |
| Quiz tables ×3 + `submit_quiz_answer` | Already orphaned (D55). The redesign is the moment to drop them |
| `profiles.passport_*` ×3 + `set_passport` | Passport is absent from the new design. `set_passport` dropped 2026-09-10 (D121); the columns stay, unread |
| `reviews` on the detail screen | Replaced by dishes. The table may survive for the "1,204 ngaps" count |

### Neighbourhoods

`restaurants` has `negara` (country) and `negeri` (state). The design needs
**KL neighbourhoods** — Bangsar, Kampung Baru, Brickfields, Pudu, Kepong,
Cheras, Chow Kit, TTDI — which is a level finer than `negeri` and appears on
almost every restaurant surface.

## 3. Data delta

The gap that matters more than the schema.

| Field | Have | Need | Gap |
|---|---|---|---|
| Coordinates | **1,133 / 1,607** | Essentially all — the map is a whole tab now | 474 |
| Rating | **2 / 1,607** | Detail facts ("4.7") | 1,605 |
| Images | **287 / 1,607** | *Photography everywhere* — cards, tiles, map blobs, plan logos, calendar days | ~1,320 |
| Opening hours | **0** | 5 screens | all |
| Price band | **0** | 4 screens, and a filter | all |
| Dishes | **0** | The detail screen's main section | all |
| Neighbourhood | **0** | Nearly every surface | all |
| 9:16 video clips | 1,606 TikTok embeds | The design says *"real 9:16 clips in production"* | see §4.3 |
| Friend portraits | 0 | Friends, invites, calendar | all |
| **City** | Johor + Penang | **Kuala Lumpur** | **the entire catalogue** |

### The city problem

This is the largest single item in the document and it is easy to miss.

The catalogue is 1,607 restaurants in **Johor and Penang**, because those are
the creators the pipeline scraped. The design is explicitly *"Video-first
restaurant swiper for **Kuala Lumpur**"*, and every string in the prototype is
KL: Bangsar, Kampung Baru, Brickfields, Kepong, Cheras, Kajang, Klang.

**A KL launch needs a new scrape of KL creators.** The existing 1,607 rows do
not serve the new product's market at all. The pipeline itself transfers
directly — that is the good news — but the data does not.

## 4. Conflicts to resolve

Places where the new design contradicts either itself or a locked decision.

### 4.1 Spice has three different scales — ✅ resolved 2026-09-05

| Where | Scale |
|---|---|
| `profiles.spice_bias` (built) | 3 values — `low` / `medium` / `high` |
| Diet screen (01e) | **4** segments — Mild / Medium / Pedas / Bring it |
| You screen (10) | **5** pips, 4 lit |

One field, three representations.

**Resolved by storing the design's scale and deriving the old one** (D104).
`profiles.spice_level` is a `smallint` 1–4 and is the truth; `update_preferences`
and `complete_onboarding` write `spice_bias` in step with it (1→low, 2→medium,
3 and 4→high), so `deck_scored`'s existing three-way term keeps scoring without
a second migration. The You tab's five pips are five, with `spice_level` of
them lit — "Bring it" leaves one dark exactly as the prototype draws it, which
is what the fifth pip was always for. Null is a real state: the step is
skippable, so "never answered" lights none.

### 4.2 "No emoji" vs. `cuisines.emoji` — ✅ resolved 2026-09-04

The brand reference forbids emoji as food imagery. `cuisines.emoji` was a
shipped column that Explore's tiles, the cuisine page title, the discovery
filter chips and the onboarding taste chips all rendered.

**Resolved in the design's favour** (D88). The column is no longer read
anywhere, and the field is off both `CuisineCount` and `TasteOption` so a call
site cannot reintroduce it. A cuisine with no cover photo falls back to its
**name on a chip**, which is the design's stated replacement.

`get_cuisine_counts()` already returned `cover_url`, so the photo path needed
no plumbing — but the photos still mostly do not exist, so the chip is the
common case rather than the edge. That is a data gap (§3), not a design one.

### 4.3 "Real 9:16 clips" vs. D4

D4 locks video to **TikTok's own embedded player**, because their developer
terms require it — the app may not download or re-host the media. The design
says *"real 9:16 clips in production"*.

If that means self-hosted clips, **it violates D4 and TikTok's terms.** If it
means the embed continues and 9:16 describes the framing, D4 is safe. This must
be settled before any player work: it is a legal question, not a design one.

Related, and **done 2026-09-04**: video starts silent as the design asks (D89),
and the card says "Tap for sound". ~~The player URL sets `muted=1`, and a tap
opens fullscreen, which is where TikTok's volume control is.~~ **Amended
2026-09-10 by D122**: the URL always carries `muted=0` and silence is imposed by
posting TikTok's own `mute` message on load; the pill posts `unMute` in place,
so sound no longer costs a screen. D4 still holds — the messages are TikTok's
documented player API, not a script driving their page. Muting on load also
removed a fragility: a muted autoplay is the only kind a browser engine honours
without a gesture.

### 4.4 Google-hosted fonts vs. D8 — ✅ resolved 2026-09-04

The prototype loads Bricolage Grotesque and Instrument Sans from Google Fonts.
D8 locks fonts as **bundled static instances** so a first offline launch never
falls back to a platform font.

**Resolved in D8's favour.** Both faces are now bundled. No download was
needed: the correct static instances and their licences were still in git
history — deleted by `b627d27` when the app moved to Lexend — so they were
restored from there, and Lexend was removed.

### 4.5 Deck features that vanish — ✅ resolved 2026-09-04

Rewind (D6), the 50-swipe daily limit (D16), the streak on the deck, the match
celebration (D15) and super like (D5, D14) all had locked decisions and none
appear in the new design. Passport (absent from every screen) was in the same
position.

**Resolved: the design drops them, and they are gone from the client** (D84).
Removed, not hidden — a control for a retired feature is worse than a missing
one, and a flag nothing sets is worse than no flag.

| Retired | What went |
|---|---|
| Super like | The action, the star badge, the "Must try only" filter, the profile stat |
| Rewind | The button, the empty-state affordances, `DeckController.rewind` |
| Daily limit | The 50-swipe allowance, its gate, its empty state, the low-swipe chip |
| Deck streak | The flame chip and `streakDays` |
| Match moment | `_MatchOverlay` entirely |
| Passport | The model, the sheet, the tile, the stat, `setPassport`, three `AppUser` fields |

The up gesture is rebound to **Later** (D85). The client says `later`
throughout; `swipes.super_like` is still its storage and `p_super_like` its
wire name, so this shipped without a schema change. Renaming the column stays
a separate migration — see §2.

**Still on the database:** `undo_swipe`, `get_swipe_stats`,
`get_super_liked_ids` and `profiles.passport_*` are now unused by the client but
not dropped. Dropping them destroys data (passport pins, the super-like flags)
and is irreversible, so it wants an explicit decision rather than riding along
with a client change. `set_passport` **was** dropped on 2026-09-10 — it is a
writer, not data, and the columns it wrote were still outranking the device
inside `deck_scored` (D121).

The profile's streak — in **weeks** — is a different statistic and is not
built; it needs plans.

### 4.6 Auth: phone is primary, email is gone — ✅ resolved 2026-09-06

The design's sign-up offers phone, Apple, Google. Today's app is email/password,
Google, Apple. Phone auth is a Supabase provider that is not enabled and needs
an SMS gateway with a real per-message cost.

**Resolved: the design's two screens shipped, and phone is gated by a
build-time define exactly as Google already was** (D113). `PHONE_AUTH_ENABLED`
is off by default, so "Continue with phone number" hides itself rather than
failing at tap time; the flow behind it — +60, a six-digit code, a resend
countdown — is written and tested, and the define is the only thing between it
and users. Switching it on is dashboard work with a per-message bill attached,
so it is listed in [Release/STORE.md](../Release/STORE.md) rather than done
here.

**Email stays, behind a text button** (D114). With phone gated by a define,
Google gated by client ids and Apple gated by the platform, a build with none
of them configured — every developer build, and the reviewer's — would have no
way to sign in at all. `/login` and `/register` are gone as screens; the paths
redirect to `/welcome` so an old link does not 404, and the sign-in, create-
account and reset forms are one form revealed by "Use email instead" on the
sign-up screen. The moment phone is live, that button is the thing to remove.

The design's "Later" (browse without an account) is gated the same way, by
`GUEST_BROWSING_ENABLED`, because the anonymous provider is not enabled either
(D115).

The design has **no forgot-password flow**, but the fallback form keeps one:
the dead-end reset link documented in [Features/Auth.md](../Features/Auth.md)
is still a dead end, and it is still the only recovery an email account has.
It leaves with the email form.

### 4.7 Onboarding: "Skip" vs. a hard minimum

The taste step demands *"Bite at least two"* and the don't-list says never let
Continue work before the minimum is met — but the same screen has a **Skip**
button in the top bar. Diet and Friends are skippable too.

Decide what a skipped taste step means for `deck_scored`, which today weights
the deck on exactly that signal.

## 5. Client delta

### Survives largely intact

`core/config`, `core/observability`, `core/storage`, `core/supabase`,
`core/location` (all four helpers), the repository pattern, the four-folder
feature shape, `DeckRanker`, `TikTokPlayerCache` and the player handle, all
three offline caches, the router's splash-hold, and the whole test approach.

### Rewritten

- **`core/ui/` entirely** — every token, both fonts, all five radii, the button
  vocabulary, and `AppEyebrow` + `appOverlineStyle` deleted outright.
- **All five tab presentations.** Two change purpose (Explore → map,
  Group → calendar), one gains a sub-screen (Bites → wishlist).
- **`onboarding/`** — 4 steps → 6, and the wizard now runs **6 of the design's
  7 first-run steps as of 2026-09-05**. The gesture primer (§01g) landed with
  D90; Diet & budget (§01e) landed with D104/D105, along with the design's
  topbar chrome — a round back button, the three-state `.steps` bar, and a Skip
  on the one skippable step. **Friends (§01f) is the only one still missing**,
  and it is the one that needs a social graph rather than a column.
- **`restaurants/presentation/`** — new action bar, "Ngap!"/"Skip" stamps, the
  bite notch, muted-by-default video, dishes instead of reviews.

### New client code

| Feature folder | For |
|---|---|
| `features/plans/` | Date picker, time slots, calendar, plan cards |
| `features/friends/` | Contact matching, friend list, invites, avatar stacks |
| `features/wishlist/` | The checklist, free-text add, eaten state |
| `features/nearby/` | The map, photo blobs, radius stepper, "swipe all N" |

A map package is a new dependency and the first one the app has needed that
carries a per-tile cost.

## 6. Suggested order

Each phase is independently shippable and each unblocks the next.

| Phase | Work | Why first |
|---|---|---|
| **0** | Settle §4 — the seven conflicts. Especially **4.3 (D4/legal)** and the KL-vs-Johor catalogue question | Two of these can invalidate later work entirely |
| ~~**1**~~ | ~~Opening hours: schema + keep what the scraper already parses + backfill~~ | ✅ **Delivered 2026-09-05** (D91). See [Features/Restaurant-Data.md](../Features/Restaurant-Data.md) §2a. |
| ~~**2**~~ | ~~The design system: tokens, both fonts bundled, radii, buttons, drop eyebrows~~ | ✅ **Delivered 2026-09-04.** See [Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md) |
| **3** | Reskin the existing five tabs in place, no new features | Ships a coherent Ngap look with today's features. **Partly delivered 2026-09-04** — see below |
| ~~**4**~~ | ~~Price band + neighbourhood + dishes, and the new detail screen~~ | ✅ **Delivered 2026-09-06** (detail screen; dishes data still empty). See [Features/Restaurant-Detail.md](../Features/Restaurant-Detail.md) |
| ~~**5**~~ | ~~Nearby: the map replaces the cuisine grid~~ | ✅ **Delivered 2026-09-05.** See [Features/Nearby-Map.md](../Features/Nearby-Map.md). The 474 ungeocoded rows and the missing KL catalogue are now visible rather than urgent: they simply do not pin. |
| ~~**6**~~ | ~~Wishlist + the up-swipe rebind + retire super like~~ | ✅ **Delivered 2026-09-05.** See [Features/Wishlist.md](../Features/Wishlist.md) |
| ~~**7**~~ | ~~Plans + Calendar (solo only, no friends)~~ | ✅ **Delivered 2026-09-06.** See [Features/Plans-Calendar.md](../Features/Plans-Calendar.md) |
| ~~**8**~~ | ~~Friends, invites, time voting, and the RLS work~~ | ✅ **Delivered 2026-09-06/09.** See [Features/Friends.md](../Features/Friends.md) and [Features/Plans-Calendar.md](../Features/Plans-Calendar.md). `profiles` was never relaxed — D129 did it with definer functions instead. |
| **9** | KL catalogue scrape, if §0 decided that way | Can run in parallel from phase 1 |

### Phase 3 progress (2026-09-04)

Landed:

- **The bite** (§7 of the design system) — a `BiteNotch` clip in
  `core/ui/design_tokens.dart`, carried by every tile in the Bites grid.
- **The pill nav** (§8) — the current tab widens into a labelled ember pill;
  the other four are icon-only.
- **The motion tokens adopted** — `kMotionDuration`/`kMotionEase` now drive the
  tab fade, the screen crossfade, the press dip and the nav, replacing four
  hand-rolled durations.

Also landed, once §4.5 was resolved:

- **The retired features are gone** (D84) — the table in §4.5 lists what went.
- **The deck's action bar is the design's three circles**: a 56 px ghost Skip,
  the 72 px gradient **Ngap!** button, a 56 px ghost Later (D86). It was five
  controls; the design has three.
- **The tabs carry the design's names** — Swipe · Nearby · Bites · Calendar ·
  You (D87), and Bites is titled "Your bites".
- **The tile bite is full size.** Retiring the star freed the corner, so
  `kBiteNotchTileScale` is gone and tiles carry the prototype's 30 px.

Not yet, and still Phase 3 and beyond:

- ~~**Nearby is still the cuisine grid, not a map**~~ — **done 2026-09-05**
  (phase 5, [Features/Nearby-Map.md](../Features/Nearby-Map.md)). Calendar is
  still an empty state saying what is coming; it needs a `plans` table.
- **The bite on the swipe card.** The deck deals unswiped restaurants, so the
  flag would be false at every call site — dead code rather than a reskin. It
  needs the deck to know which places are already saved, which is plumbing, not
  paint (D81).
### Phase 6 progress (2026-09-05)

Delivered. See [Features/Wishlist.md](../Features/Wishlist.md) and the
"Changed 2026-09-05" note in
[Features/Likes-Visits.md](../Features/Likes-Visits.md).

- **Later has a place of its own.** `wishlist_items` (D94), with the three
  existing super likes backfilled. A Later is still a like; it adds a row on
  top (D95). `swipes.super_like` and `get_super_liked_ids` are untouched and
  now have no caller.
- **The Wishlist screen** is built at `/wishlist`, pushed from the Bites tab —
  counts, the "Add a place…" bar, the ember strike-through, eaten rows sinking
  to the bottom, "Clear eaten", and plain-text sharing.
- **Bites carries the design's chip row** (D96): All · Not planned yet ·
  Planned · Wishlist → · Halal. The Liked/Visited/Reviewed segments, the sort
  dropdown, the filter sheet and the per-tile buttons are all gone.
- **Tiles read the design's way** — "Cuisine · Neighbourhood", the wishlist
  bookmark, and a planned day pill that is wired but empty.

Still Phase 3 and beyond:

- ~~**Nearby is still the cuisine grid, not a map**, and Calendar is still an
  empty state.~~ — **done 2026-09-05 / 2026-09-06** (phases 5 and 7).
- **The bite on the swipe card** (D81).
- ~~**The plan chips have no ids to filter on.**~~ — **done 2026-09-06**
  (phase 7). `PlansController` feeds `plannedRestaurantIds`, the day pill on a
  tile and the "Planned" label on a wishlist row.
- **Friend rows say "From a friend"**, not "From Aiman" — the friend graph is
  Phase 8.

### Phase 7 progress (2026-09-06)

Delivered. See [Features/Plans-Calendar.md](../Features/Plans-Calendar.md),
which also supersedes [Features/Group-Dining.md](../Features/Group-Dining.md).

- **Plans have a schema.** `plans`, `plan_members` and `plan_time_votes`, with
  `create_plan`, `mark_plan_kept` and `plan_stats`, and membership answered by
  the `security definer` helper `is_plan_member` rather than by policies that
  would recurse (D107–D110). Additive only; nothing was dropped.
- **Pick a date** is built at `/plans/new` — the month grid, the five time
  chips, "Bring friends", and the `.picked` summary that reads the answer back
  before "Lock it in" commits it.
- **The Calendar tab** replaces `GroupTab` at index 3 — the month card with
  covers on planned days, plans grouped under day headings, search over plan
  names, cancel-in-a-sheet, and an empty state that points at the deck.
- **The stubbed planned state is live everywhere** — the Bites chips, the day
  pill on a tile, the wishlist row's label, and the You tab's "plans kept" and
  "week streak".

Still Phase 8 and beyond:

- ~~**Every plan is a party of one.**~~ — **done 2026-09-09** (phase 8).
  `invite_to_plan`, `answer_plan_invite` and `set_plan_vote` are all wired;
  a plan card draws its guests' faces and `/plans/:id` collects the votes.
- ~~**`/plans/:id/invite` does not exist.**~~ — **done 2026-09-06** (phase 8).
- **Other people's plans do not show as pips.** Nothing selects another user's
  plans, so every pip in the grid is your own.

### Phase 8 progress (2026-09-09)

The friend graph, invites and time voting. See
[Features/Friends.md](../Features/Friends.md) for the graph, and
[Features/Plans-Calendar.md](../Features/Plans-Calendar.md) §6a for the plan
screen and D134 for why it exists at all.

- **Friends have a schema and a screen** — `friendships`, contact matching by
  hash, `/friends`, and requests answered in place.
- **Invites work** — `/plans/:id/invite` sends them, a guest answers Going or
  Can't on the plan, and both the calendar card and the plan roster say who
  said what.
- **Time voting works** — the five chips carry tallies on `/plans/:id`, a vote
  replaces your last one, and the owner can move the plan to the winning slot.

Closed after Phase 8:

- **Friends can see each other's plans** — `plans.shared_with_friends` (off by
  default), `get_friends_plans`, a Friends section on the Calendar with its own
  pip, and "Ask to join" answered by the owner on the plan (D153). Invites,
  requests and acceptances are pushed (D155).

Still open after Phase 8:
- **The invite screen's context lines** ("Free Friday evening", "Lives 400 m
  from there") need joins no query does yet.

## 7. What this is not

- **Not approved.** DRAFT until a maintainer says otherwise.
- **Not estimated.** No phase here carries a duration.
- **Not a licence to start.** Phase 0's conflicts include a legal question
  (§4.3) and a market question (the KL catalogue) that are not engineering
  calls.
