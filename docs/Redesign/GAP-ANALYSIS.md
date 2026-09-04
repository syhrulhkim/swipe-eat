Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-04
Cross-references: [README.md](README.md), [SCREENS.md](SCREENS.md), [NGAP-DESIGN-SYSTEM.md](NGAP-DESIGN-SYSTEM.md), [Features/Backend-Schema.md](../Features/Backend-Schema.md), [General/PLAN.md](../General/PLAN.md)

# Gap Analysis — built vs. Ngap

Every delta between what ships today and what the new design needs. Ordered by
what blocks the most.

**The headline:** the client's presentation layer changes almost completely, but
the hard problem is **data**. The new design asks for opening hours, prices,
dishes, neighbourhoods and a social graph — and today's schema explicitly
declares two of those *not buildable* because no column and no source exist.

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
weight; there is no user-to-user anything in 15 tables and 16 RLS policies.

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
| `profiles.passport_*` ×3 + `set_passport` | Passport is absent from the new design |
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

### 4.1 Spice has three different scales

| Where | Scale |
|---|---|
| `profiles.spice_bias` (built) | 3 values — `low` / `medium` / `high` |
| Diet screen (01e) | **4** segments — Mild / Medium / Pedas / Bring it |
| You screen (10) | **5** pips, 4 lit |

One field, three representations. Pick one before implementing either screen.

### 4.2 "No emoji" vs. `cuisines.emoji`

The brand reference forbids emoji as food imagery. `cuisines.emoji` is a
shipped column and Explore's tiles render it today. The design's replacement is
a photo tile with a text-chip fallback — which means **every cuisine needs a
cover photo**, and `get_cuisine_counts()` already returns a `cover_url`, so the
plumbing exists and the photos do not.

### 4.3 "Real 9:16 clips" vs. D4

D4 locks video to **TikTok's own embedded player**, because their developer
terms require it — the app may not download or re-host the media. The design
says *"real 9:16 clips in production"*.

If that means self-hosted clips, **it violates D4 and TikTok's terms.** If it
means the embed continues and 9:16 describes the framing, D4 is safe. This must
be settled before any player work: it is a legal question, not a design one.

Related: the detail screen says *"tap to unmute"*, so video starts **muted** —
whereas today's player fires timed `unMute` + `play` messages at the iframe.
That is a straightforward simplification, and a welcome one.

### 4.4 Google-hosted fonts vs. D8 — ✅ resolved 2026-09-04

The prototype loads Bricolage Grotesque and Instrument Sans from Google Fonts.
D8 locks fonts as **bundled static instances** so a first offline launch never
falls back to a platform font.

**Resolved in D8's favour.** Both faces are now bundled. No download was
needed: the correct static instances and their licences were still in git
history — deleted by `b627d27` when the app moved to Lexend — so they were
restored from there, and Lexend was removed.

### 4.5 Deck features that vanish

Rewind (D6), the 50-swipe daily limit (D16), the streak on the deck, the match
celebration (D15) and super like (D5, D14) all have locked decisions and none
appear in the new design. The profile keeps a streak — in **weeks**, not days.

Either the design omitted them or it drops them. If it drops them, `undo_swipe`,
`get_swipe_stats` and `swipes.super_like` all retire, and five decisions need
superseding notes.

### 4.6 Auth: phone is primary, email is gone

The design's sign-up offers phone, Apple, Google. Today's app is email/password,
Google, Apple. Phone auth is a Supabase provider that is not enabled and needs
an SMS gateway with a real per-message cost.

Also note the design has **no forgot-password flow** — which neatly sidesteps
the dead-end reset link documented in [Features/Auth.md](../Features/Auth.md).

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
- **`onboarding/`** — 4 steps → 6, with two entirely new ones.
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
| **1** | Opening hours: schema + keep what the scraper already parses + backfill | Cheapest real win; the data is already in the captions. Unblocks 5 screens |
| ~~**2**~~ | ~~The design system: tokens, both fonts bundled, radii, buttons, drop eyebrows~~ | ✅ **Delivered 2026-09-04.** See [Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md) |
| **3** | Reskin the existing five tabs in place, no new features | Ships a coherent Ngap look with today's features. **Partly delivered 2026-09-04** — see below |
| **4** | Price band + neighbourhood + dishes, and the new detail screen | The detail screen is where the product argues for itself |
| **5** | Nearby: the map replaces the cuisine grid | Needs coordinates; the 474 gap becomes urgent here |
| **6** | Wishlist + the up-swipe rebind + retire super like | Small, self-contained, completes the three-gesture story |
| **7** | Plans + Calendar (solo only, no friends) | Delivers "pick a day" — the tagline's third verb — without the social graph |
| **8** | Friends, invites, time voting, and the RLS work | Largest and riskiest; the only phase that relaxes `profiles` |
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

Not yet, and still Phase 3:

- **Explore, Group and Profile tab bodies** are untouched. Only the frame
  around them changed.
- **The bite on the swipe card.** The deck deals unswiped restaurants, so the
  flag would be false at every call site — dead code rather than a reskin. It
  needs the deck to know which places are already saved, which is plumbing, not
  paint (D81).
- **The super-like star** still sits on Bites tiles. §7 of the design system
  says the notch replaces it, but the star means *"must try"*, not *"saved"* —
  a different fact. Retiring it is §4.5's call, not a reskin's (D82).

  This one has a measurable cost. Keeping the badge row forces the tile's bite
  down to two thirds of the specified size: at the prototype's full 30 px the
  notch reaches back past the row on a 320 pt phone and clips the "Remove from
  likes" button. So §4.5's decision is not only tidying — it is what lets the
  redesign's signature device appear at the size the design asked for.

## 7. What this is not

- **Not approved.** DRAFT until a maintainer says otherwise.
- **Not estimated.** No phase here carries a duration.
- **Not a licence to start.** Phase 0's conflicts include a legal question
  (§4.3) and a market question (the KL catalogue) that are not engineering
  calls.
