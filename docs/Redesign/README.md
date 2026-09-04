Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [NGAP-DESIGN-SYSTEM.md](NGAP-DESIGN-SYSTEM.md), [SCREENS.md](SCREENS.md), [GAP-ANALYSIS.md](GAP-ANALYSIS.md), [General/PLAN.md](../General/PLAN.md)

# Redesign — Ngap

**This folder specs a target, not the built app.** Everything in `Features/`
describes what ships today; everything here describes what the new design asks
for. Read them side by side — [GAP-ANALYSIS.md](GAP-ANALYSIS.md) is the
difference.

Nothing here is approved or scheduled. It is DRAFT until a maintainer says
otherwise.

## What this is

A full rebrand and product expansion of Swipe Eat into **Ngap** — Malay for
*bite*.

> **Ngap.** Where to eat? *Swipe it.*
> Fifteen seconds of video per restaurant. Bite the ones you want, pick a day,
> bring whoever's hungry.

## Source material

| File | What it is |
|---|---|
| [assets/ngap-app-screens.html](assets/ngap-app-screens.html) | The clickable prototype. All 16 screens, self-contained. **Open this first** |
| [assets/ngap-brand-reference.md](assets/ngap-brand-reference.md) | The brand reference from the `design` skill's `references/clients/ngap.md` |

The prototype's imagery is **hotlinked from Unsplash** and its restaurant names
are invented. Both must be replaced before anything ships.

## The headline changes

This is not a reskin. Three of the five tabs change purpose, and the product
grows a scheduling and social layer it does not have at all today.

| | Today (Swipe Eat) | Target (Ngap) |
|---|---|---|
| **Name** | Swipe Eat | **Ngap** |
| **City** | Johor + Penang | **Kuala Lumpur** |
| **Tabs** | Swipe · Explore · Liked · Group · Profile | **Swipe · Nearby · Bites · Calendar · You** |
| **Tab 2** | Cuisine grid | **A map** with photo blobs |
| **Tab 3** | Liked / Visited / Reviewed | **Bites** + a wishlist |
| **Tab 4** | Group (empty stub) | **Calendar of plans** |
| **Swipe up** | Super like | **Later** — save without deciding |
| **Like is called** | Like | **"Ngap!"** — never "like", never a heart |
| **Auth** | Email/password, Google, Apple | **Phone**, Apple, Google |
| **Onboarding** | 4 steps | **6 steps** with a progress bar |
| **Typeface** | Lexend | **Bricolage Grotesque** + **Instrument Sans** |
| **Corners** | All `0` | **28px cards, 18px tiles, pill chips** |
| **Surface** | Flat near-black | Warm black + **radial ember glow**, glass panels |

### New product surface with no equivalent today

- **Plans** — pick a date and a time for a restaurant, then it lives in a
  Calendar tab.
- **Friends** — an on-device contact match, a social graph, and invites that
  let guests vote on the time.
- **Wishlist** — a checklist of places to try, separate from likes, with an
  eaten state.
- **Dishes** — a per-restaurant menu with names, descriptions and RM prices.
- **Budget** — RM per person, set as a range in onboarding and filtered on.
- **Halal as a hard filter**, surfaced as a badge.
- **Opening hours** — "open till 2 am", "Open · 24 h", "6 open now". Shown on
  almost every screen.

Today's schema explicitly declares price and opening hours **not buildable**
because no column and no source exist. The new design requires both on nearly
every screen. That is the single largest piece of work here — see
[GAP-ANALYSIS.md](GAP-ANALYSIS.md).

## Documents

| Doc | Covers |
|---|---|
| [NGAP-DESIGN-SYSTEM.md](NGAP-DESIGN-SYSTEM.md) | Tokens, type, shape, motion, voice, "the bite", the do/don't list |
| [SCREENS.md](SCREENS.md) | All 16 screens, screen by screen |
| [GAP-ANALYSIS.md](GAP-ANALYSIS.md) | Every delta from the built app: schema, data, features, client. Ordered by what blocks the most |

## What is kept

Worth stating, because the gap analysis is long and reads like a rewrite. These
survive intact:

- Supabase Auth, RLS, and the whole security model.
- The 1,607-row catalogue, its TikTok video identity, and the scraping
  pipeline.
- `deck_scored` / `get_deck` and the ranking model.
- The swipe gesture thresholds — the prototype uses the same `dx > 110`,
  `dx < -110`, `dy < -140`.
- The bounded TikTok player cache and the thumbnail Storage pipeline.
- Offline caching, Sentry, account deletion, the legal pages.

The client's presentation layer changes almost completely; the data and state
layers mostly grow rather than change.
