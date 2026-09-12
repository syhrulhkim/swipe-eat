# Swipe Eat — Documentation

Living documentation for Swipe Eat: a Flutter app for finding somewhere to eat
by swiping through restaurant cards built from TikTok food videos, backed by
Supabase. Five tabs — Swipe, Nearby, Bites, Calendar, You — plus the plans,
wishlist and friends screens pushed over them.

It is organized by concern, not by chronology — each folder answers a different
question a reader might have.

## How this folder is organized

| Folder | Answers | Contains |
|---|---|---|
| `General/` | Why are we building this, and how do I run it? | Product plan, architecture rules, decision log, local dev runbook |
| `Features/` | What does this feature do, exactly? | One file per feature/domain area — both shipped and planned |
| `Frontend/` | How is the client built? | Stack, conventions, the design system |
| `Tests/` | How do we test this, and what's covered? | Testing conventions and coverage map |
| `Release/` | How does this get to users? | Store submission, signing, compliance |
| `Redesign/` | Where is the design going? | The **Ngap** rebrand — target design system, screens, gap analysis. DRAFT |
| `History/` | What did we plan, and did it land? | Delivered plans and superseded specs, kept for their reasoning |

> **`Features/` describes what ships today. `Redesign/` describes a proposed
> target.** Never read one as the other — [Redesign/GAP-ANALYSIS.md](Redesign/GAP-ANALYSIS.md)
> is the difference between them.

As the product grows, expect new top-level folders to appear the first time
there's real content for them — this taxonomy is deliberately not pre-built
with empty placeholders for concerns that don't exist yet.

## Conventions used across these docs

Every doc in `Features/`, `General/` and `Release/` opens with a header block:

```
Status: DRAFT | ACTIVE | SHIPPED | LOCKED | ORPHANED | SUPERSEDED
Owner: <team or person>
Last updated: <date>
Cross-references: <links to related docs>
```

- **DRAFT** — proposed, not built, open to change.
- **ACTIVE** — implemented and in use; edits should reflect reality.
- **SHIPPED** — implemented and stable; rarely needs to change.
- **LOCKED** — a decision that should not be revisited without a strong reason.
- **ORPHANED** — schema or code exists but nothing reaches it. Documented so
  the next reader knows it is dead weight rather than a feature they missed.
- **SUPERSEDED** — described reality once and no longer does. Kept only for
  its reasoning; never cite it as current behaviour.

Specs that involve a real choice (schema shape, library, UX pattern) end with a
**Decision log** table:

```
| ID | Decision | Status |
|---|---|---|
| D1 | ... | locked YYYY-MM-DD |
```

This keeps "why did we choose X" queryable instead of buried in chat history or
PR descriptions. Most specs also close with an **Out of scope** section — what
was deliberately *not* built, so nobody re-proposes it without reading the
reasoning first.

## Start here

| If you want to… | Read |
|---|---|
| Understand the product and its architecture | [General/PLAN.md](General/PLAN.md) |
| Run, build or deploy it | [General/RUNBOOK.md](General/RUNBOOK.md) |
| See every decision in one place | [General/DECISIONS.md](General/DECISIONS.md) |
| See what is planned next, and why | [General/OPTIMIZATION-PLAN.md](General/OPTIMIZATION-PLAN.md) |
| Understand the database | [Features/Backend-Schema.md](Features/Backend-Schema.md) |
| Work on the core swipe experience | [Features/Swipe-Deck.md](Features/Swipe-Deck.md) |
| Ship to the stores | [Release/STORE.md](Release/STORE.md) |
| Understand the Ngap redesign | [Redesign/README.md](Redesign/README.md) |

## Feature map

| Doc | Status | Covers |
|---|---|---|
| [Auth](Features/Auth.md) | ACTIVE | The welcome and sign-up screens, phone (gated), Google, Apple, the email fallback, Mailtrap SMTP |
| [Backend-Schema](Features/Backend-Schema.md) | ACTIVE | As-built tables, RPCs, RLS, triggers |
| [Onboarding-Taste](Features/Onboarding-Taste.md) | ACTIVE | The four-step wizard and the cold-start taste signal |
| [Swipe-Deck](Features/Swipe-Deck.md) | ACTIVE | The card deck, ranking, the three-button action bar, discovery settings, offline fallback |
| [Nearby-Map](Features/Nearby-Map.md) | ACTIVE | The tab-1 map, its pins, the radius stepper and "Swipe all" |
| [Explore-Search](Features/Explore-Search.md) | SUPERSEDED | Cuisine grid, search, Top Picks rail — the tab is gone (D102) |
| [Likes-Visits](Features/Likes-Visits.md) | ACTIVE | The Bites grid, the chip row, pull-to-refresh, the visit prompt |
| [Wishlist](Features/Wishlist.md) | ACTIVE | The checklist at `/wishlist`, the eaten half, "From &lt;friend&gt;" |
| [Profile-Preferences](Features/Profile-Preferences.md) | ACTIVE | Preferences, diet & budget, radius, discovery filters, location |
| [TikTok-Video](Features/TikTok-Video.md) | ACTIVE | The embedded player, warming, the thumbnail cache job |
| [Restaurant-Data](Features/Restaurant-Data.md) | ACTIVE | Scrape → extract → review → geocode pipeline |
| [Account-Deletion-Legal](Features/Account-Deletion-Legal.md) | SHIPPED | Store-mandated deletion and the public legal pages |
| [Plans-Calendar](Features/Plans-Calendar.md) | ACTIVE | Pick a date, the Calendar tab, and the planned state everywhere |
| [Friends](Features/Friends.md) | ACTIVE | Contact matching in onboarding, the `/friends` lists, plan invites, the plan page's time voting |
| [Group-Dining](Features/Group-Dining.md) | SUPERSEDED | Tab 3 is the Calendar now; the shared-deck sketch survives |
| [Quiz](Features/Quiz.md) | ORPHANED | Schema with no UI reaching it |

`Frontend/` holds the two client-wide references:

| Doc | Covers |
|---|---|
| [Frontend/STACK.md](Frontend/STACK.md) | Packages, layering, routing, the rules a new feature follows |
| [Frontend/DESIGN-SYSTEM.md](Frontend/DESIGN-SYSTEM.md) | Tokens, type, shape, the component vocabulary |

## Proposed: the Ngap redesign

A full rebrand and product expansion — new name, Kuala Lumpur instead of
Johor/Penang, and a scheduling and social layer. **DRAFT.** The rebrand and the
KL catalogue are not built; the scheduling and social layer since has been —
plans, the Calendar tab, friends, invites and time voting all ship today, under
`Features/`. [GAP-ANALYSIS.md](Redesign/GAP-ANALYSIS.md) is still the
difference.

| Doc | Covers |
|---|---|
| [Redesign/README.md](Redesign/README.md) | What it is, the headline changes, what survives |
| [Redesign/NGAP-DESIGN-SYSTEM.md](Redesign/NGAP-DESIGN-SYSTEM.md) | Target tokens, type, shape, voice, "the bite" |
| [Redesign/SCREENS.md](Redesign/SCREENS.md) | All 16 screens |
| [Redesign/GAP-ANALYSIS.md](Redesign/GAP-ANALYSIS.md) | Every delta, seven conflicts, a suggested order |
| [Redesign/assets/](Redesign/assets/) | The clickable prototype and the brand reference |

## Reference

This structure and its conventions match the sibling
[`aviation-lms`](../../aviation-lms/docs/README.md) project's `docs/` folder, so
both repos read the same way in the shared Obsidian vault. Cross-checked against
the [Diátaxis](https://diataxis.fr/) documentation framework (tutorials /
how-to / reference / explanation) to keep each doc single-purpose rather than
mixing planning prose with reference tables.
