Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [README.md](README.md), [SCREENS.md](SCREENS.md), [Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md), [GAP-ANALYSIS.md](GAP-ANALYSIS.md)

# Ngap Design System (target)

The design system the new prototype defines. For the **built** system see
[Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md) — the two share
almost nothing.

Authoritative source: [assets/ngap-brand-reference.md](assets/ngap-brand-reference.md)
and the `:root` block of [assets/ngap-app-screens.html](assets/ngap-app-screens.html).

## 1. The one rule

> Black carries the screen. Orange appears in exactly **two** roles: a radial
> glow at the top of every screen, and anything the user can act on or has
> selected. Nothing sits on flat white; nothing decorative is orange.

Everything below is downstream of that.

## 2. Colour

| Token | Value | Use |
|---|---|---|
| `--bg` | `#0B0605` | Screen background. **Warm black, never grey** |
| `--surface` | `#171010` | Cards, panels, bottom nav |
| `--surface-2` | `#221614` | Raised elements on a card |
| `--ember` | `#FF8A3D` | Action + selected: CTAs, active tab, chosen day/chip, time pills |
| `--lava` | `#E8541C` | CTA gradient end; top-of-screen glow |
| `--char` | `#5A160C` | Glow falloff |
| `--ink` | `#140A05` | Deepest ink |
| `--cream` | `#FFF3E8` | Text |
| `--cream-70` | `rgba(255,243,232,.72)` | Secondary text |
| `--cream-45` | `rgba(255,243,232,.45)` | Muted text |
| `--on-ember` | `#140A05` | Text on orange |
| `--glass` | `rgba(255,255,255,.07)` | Glass fill |
| `--glass-strong` | `rgba(255,255,255,.12)` | Raised glass fill |
| `--glass-line` | `rgba(255,255,255,.14)` | Outlines |
| `--fresh` | `#9DF2B8` | **"Open now" indicator only** |

### The two composites

```css
--grad-cta: linear-gradient(135deg, var(--ember), var(--lava));

/* the orange lives as a glow at the top of every screen, then goes black */
--grad: radial-gradient(130% 48% at 50% -6%,
          var(--lava) 0%, var(--char) 42%, transparent 72%), var(--bg);
```

`--grad` is the app's signature. Every screen carries it.

### Shadow

Exactly one, and nothing else:

```css
--shadow-card: 0 24px 48px -16px rgba(0,0,0,.8);
/* brand reference states it as rgba(60,12,4,.55) — a warm variant.
   Resolve before implementing; the prototype's value is the neutral one. */
```

## 3. Type

| Role | Family | Weights |
|---|---|---|
| Display / headings | **Bricolage Grotesque** | 700, 800 (prototype also loads 500) |
| Body | **Instrument Sans** | 400, 500, 600 |

Source: Google Fonts. **Left-aligned. No all-caps labels. No monospace for
data.**

### Scale

| Token | Size |
|---|---|
| `--fs-hero` | 44px |
| `--fs-h1` | 30px |
| `--fs-h2` | 20px |
| `--fs-body` | 15px |
| `--fs-small` | 13px |
| `--fs-micro` | 11px |

Two consequences for the current codebase:

- **`appOverlineStyle` must go.** It is uppercase by definition, and the design
  forbids all-caps labels.
- **`AppEyebrow` must go.** "No numbered markers or eyebrows" is explicit, and
  `DashboardTabShell` puts an eyebrow above every tab title today.

## 4. Shape and spacing

```css
--r-card: 28px;   --r-tile: 18px;   --r-chip: 999px;   --r-sm: 10px;
--s1:4  --s2:8  --s3:12  --s4:16  --s5:20  --s6:24  --s8:32   /* 4px grid */
```

Corners come back. Every one of today's five radius tokens is `0`; all five
change, and the pill radius becomes a genuine pill rather than a square.

## 5. Motion

```css
--dur: 220ms;   --ease: cubic-bezier(.2,.8,.2,1);
```

One duration, one curve. Today's deck animates at 640ms with
`easeInOutCubic` — the card exit may keep its own longer timing, but every
other transition should adopt these.

## 6. Voice

> Short, hungry, second person.

| Do say | Not |
|---|---|
| "Where to eat? Swipe it." | |
| **"Ngap!"** | "Like", a heart alone |
| "Start swiping" | "Get started" |
| "Set a date" | "Schedule" |
| "Lock it in" | "Confirm" |
| "Send invites" | "Share" |
| "Show me dinner" | "Continue" |
| "Who's hungry?" | "Select friends" |
| "Any rules?" | "Dietary preferences" |

Buttons name the action. Every onboarding step explains **why it is asking** in
one line under the heading.

Real strings from the prototype worth keeping verbatim:

- "Ngap only shows places you can actually get to tonight. We use your location
  while the app is open, nothing more."
- "So we never show you somewhere you can't eat."
- "We don't upload your contacts. Matching happens on your phone."
- "Bitten places land in Your bites. Set a date from there."
- "Eaten ones sink to the bottom."
- "Tap a place once you've eaten there."

## 7. The signature: the bite

> A circular notch in the top-right corner of any restaurant surface the user
> has saved. **The only decorative device in the app**, and it means one thing.

In the prototype it is the `.bite` class, applied to swipe cards, Bites tiles
and map blobs. It replaces every heart, star and badge currently used to mark a
saved place — including the Liked tab's super-like star.

## 8. Navigation

A **black pill bottom nav**; the active tab expands into a labelled cream pill.

| Order | id | Label | Today |
|---|---|---|---|
| 1 | `swipe` | Swipe | Swipe |
| 2 | `nearby` | Nearby | *was Explore (cuisine grid)* |
| 3 | `likes` | **Bites** | *was Liked* |
| 4 | `calendar` | Calendar | *was Group (stub)* |
| 5 | `profile` | **You** | *was Profile* |

Wishlist has no tab of its own — it sits under Bites and keeps the Bites tab
marked current (`data-nav="likes"` in the prototype).

## 9. Imagery

**Photography everywhere a restaurant appears**: swipe card, tile, map blob,
plan logo, calendar day. Portrait photos for friends, with initials shown until
the photo loads.

- Production wants **real 9:16 clips**; Unsplash stills are prototype
  placeholders and are hotlinked — download and self-host before shipping.
- **No emoji as food imagery.** Categories are photo tiles; with no photo it is
  a text chip in a secondary row, never an emoji.

That last rule breaks a shipped feature: `cuisines.emoji` is a column, and
Explore's tiles render it today. See [GAP-ANALYSIS.md](GAP-ANALYSIS.md).

## 10. Malaysian context

Non-negotiable, and mostly missing from the schema today:

- **RM prices** — per dish and as a per-person range.
- **Halal flag** — a hard filter and a visible badge.
- **KL neighbourhoods** — Bangsar, Kampung Baru, Brickfields, Pudu, Kepong,
  Cheras, Chow Kit, TTDI, Kajang, Klang.
- Malay in the product's own voice: *Ngap*, *pedas*, *pasar malam*, *kopitiam*,
  *mamak*, *nasi kandar*, *bak kut teh*, *teh tarik*.

## 11. Don't

Straight from the brand reference:

- No flat white screens; no grey blacks (`#111`, `#222`) — blacks stay warm.
- No orange as decoration — if it isn't tappable or selected, it isn't orange.
  The top glow is the one exception.
- No red heart for like.
- No numbered markers or eyebrows.
- No emoji as food imagery.
- Never let a Continue button work before its stated minimum is met — disable
  it and put the remaining count in the label ("Pick 1 more").
- Don't reuse the ember/lava/char palette for any other client.

## 12. Open questions

1. **Shadow value conflict** — the brand reference says
   `rgba(60,12,4,.55)`; the prototype says `rgba(0,0,0,.8)`. One is right.
2. **Bricolage 500** is loaded by the prototype but the reference specifies
   only 700/800. Trim or document.
3. **Fonts are Google-hosted** in the prototype, but D8 locks bundled fonts —
   a first offline launch must not fall back to a platform font. These must be
   bundled as static instances, same as Lexend is today.
4. **No light theme** is specified, and none is needed — but the token set is
   again defined as literal dark values, so this stays a one-way door.
5. **`--fresh` needs opening hours** to mean anything. Until hours exist, the
   "open now" indicator cannot render.
