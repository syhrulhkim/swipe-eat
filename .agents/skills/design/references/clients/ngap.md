# Client: Ngap

Video-first restaurant swiper for Kuala Lumpur. "Ngap" = bite. Swipe restaurants, bite the ones you want, set a date, optionally bring friends.

## Tokens

| Token | Value | Use |
|---|---|---|
| `--bg` | #0B0605 | Screen background. Warm black, never grey |
| `--surface` | #171010 | Cards, panels, bottom nav |
| `--surface-2` | #221614 | Raised elements on a card |
| `--ember` | #FF8A3D | Action + selected: CTAs, active tab, chosen day/chip, time pills |
| `--lava` | #E8541C | CTA gradient end; top of the screen glow |
| `--char` | #5A160C | Glow falloff |
| `--cream` | #FFF3E8 | Text |
| `--glass-line` | rgba(255,255,255,.14) | Outlines |
| `--fresh` | #9DF2B8 | "Open now" indicator only |
| `--on-ember` | #140A05 | Text on orange |

Black carries the screen. Orange appears in exactly two roles: a radial glow at the top of every screen (`radial-gradient(130% 48% at 50% -6%, lava, char 42%, transparent 72%)`) and anything the user can act on or has selected. Nothing sits on flat white; nothing decorative is orange.

## Type

- **Display / headings:** Bricolage Grotesque — 700, 800
- **Body:** Instrument Sans — 400, 500, 600
- **Source:** Google Fonts
- Left-aligned. No all-caps labels, no monospace for data.

## Shape and spacing

- Radius: cards 28px, tiles 18px, chips/buttons pill
- Spacing: 4px grid
- Shadows: one deep warm card shadow (`0 24px 48px -16px rgba(60,12,4,.55)`), nothing else

## Voice

Short, hungry, second person. "Where to eat? Swipe it." Buttons name the action: "Start swiping", "Set a date", "Lock it in", "Send invites". The like action is always "Ngap!", never "like" or a heart alone.

## Signature

The bite: a circular notch in the top-right corner of any restaurant surface the user has saved. Only decorative device in the app.

## Do
- First-run flow is six steps with a thin progress bar (ember = current, cream = done): sign up → location → taste chips → diet & budget → friends (skippable) → how to swipe. Every step explains why it's asking in one line under the heading.
- Wishlist is a plain checklist under Bites: tap to cross off (ember strike-through, photo desaturates, eaten rows sink to the bottom). No confetti, no modal.

- Video is the hero on every restaurant surface; text sits low over a dark scrim
- Black pill bottom nav, active tab expands into a labelled cream pill
- Photography everywhere a restaurant appears: swipe card, tile, map blob, plan logo, calendar day. Unsplash for prototypes; real 9:16 clips in production
- Portrait photos for friends, initials shown until the photo loads
- Malaysian context: RM prices, halal flag, KL neighbourhoods

## Don't
- No emoji as food imagery. Categories are photo tiles; if there's no photo, it's a text chip in a secondary row, never an emoji.
- Never let a Continue button work before its stated minimum is met — disable it and put the remaining count in the label ("Pick 1 more").

- No flat white screens, no grey blacks (#111, #222) — blacks stay warm
- No orange as decoration; if it isn't tappable or selected, it isn't orange (the top glow is the one exception)
- No red heart for like
- No numbered markers or eyebrows
- Don't reuse the ember/lava/char palette for any other client

## Assets

Prototype: ngap-app-screens.html (all nine screens). Prototype imagery is hotlinked from Unsplash — download and self-host before shipping. Still needed: 9:16 restaurant clips, map tiles.
