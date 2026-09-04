Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-04
Cross-references: [STACK.md](STACK.md), [Redesign/NGAP-DESIGN-SYSTEM.md](../Redesign/NGAP-DESIGN-SYSTEM.md), [Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md), [General/PLAN.md](../General/PLAN.md)

# Design System

**The Ngap design system, as built.** Phase 2 of
[Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md) landed on 2026-09-04:
the token layer, both faces, the radii, the CTA gradient and the screen glow are
in the app. The target spec is
[Redesign/NGAP-DESIGN-SYSTEM.md](../Redesign/NGAP-DESIGN-SYSTEM.md); this
records what the code actually does.

Files: `lib/core/ui/design_tokens.dart` (palette, radii, type scale, motion,
scrims, `ScreenGlow`, `AppIconButton`, `AppChip`), `app_buttons.dart`,
`app_spacing.dart`, and `lunar/` for the effects.

## 1. The one rule

> Black carries the screen. Orange appears in exactly two roles — a radial glow
> at the top of every screen, and anything the user can act on or has selected.
> Nothing sits on flat white; nothing decorative is orange.

Everything below is downstream of that, and two tests enforce parts of it
(§8).

## 2. Palette

Named by **role**, not by colour, so a retint changes one line rather than every
call site.

### Accents

| Token | Value | Role |
|---|---|---|
| `kAccentEmber` | `#FF8A3D` | Action + selected: CTAs, active tab, chosen chip |
| `kAccentLava` | `#E8541C` | CTA gradient end; the glow's core |
| `kAccentChar` | `#5A160C` | The glow's falloff |
| `kOnAccent` | `#140A05` | Ink on top of either accent |
| `kAccentCream` | `#FFF3E8` | The app's text colour |
| `kCreamSecondary` | `#FFF3E8` @ 72% | Secondary lines |
| `kCreamMuted` | `#FFF3E8` @ 45% | Muted metadata |
| `kFresh` | `#9DF2B8` | **"Open now" only** — the one non-orange accent |

`kFresh` currently has no call site: it needs opening hours, which the schema
does not have. It is defined so the rule that owns it is written down.

### Surfaces

| Token | Value | Role |
|---|---|---|
| `kBackgroundDeep` | `#050302` | Deepest — behind the explore map |
| `kBackgroundDark` | `#0B0605` | The screen. **Warm black, never grey** |
| `kSurfaceDark` | `#171010` | Cards, panels, the bottom nav |
| `kSurfacePanel` | `#221614` | Raised elements on a card, list rows |
| `kBrandColorFallback` | = `kSurfacePanel` | An unbranded or unparseable row |
| `kGlass` / `kGlassStrong` | white @ 7% / 12% | Panels over photography |
| `kFillOnPhoto` | black @ 35% | Controls over a photo or video |
| `kHairline` | white @ 14% | Separates two dark surfaces |

Blacks stay **warm** — more red than blue. A grey black under this much orange
reads as a rendering fault rather than a choice, and a test asserts it.

`kBrandColorFallback` equals the panel colour on purpose, so an unbranded card
is simply neutral rather than obviously wrong. `restaurants.brand_color` is hex
text parsed by `hex_color.dart`; anything unparseable lands here.

### The two composites

```dart
kCtaGradient  // 135°, ember → lava. The app's only gradient fill.
kScreenGlow   // radial: lava → char → transparent, painted by ScreenGlow
```

## 3. Shape

| Token | Value | For |
|---|---|---|
| `kRadiusPill` | 999 | Chips, nav indicator, round buttons |
| `kRadiusCard` | 28 | Large full-bleed cards (the deck) |
| `kRadiusSheet` | 28 | Large bottom sheets |
| `kRadiusPanel` | 18 | Panels, tiles, detail cards |
| `kRadiusThumb` | 10 | Small image tiles |

Nothing hard-codes a corner; setting all five to `0` restores the
square-cornered app, which is exactly what they were between 2026-08-31 and
2026-09-04 (§9).

`kActionButtonSize` 58 (like/pass/route), `kUtilityButtonSize` 44 (back,
settings, more).

## 4. Motion and shadow

```dart
kMotionDuration = 220ms
kMotionEase     = Cubic(0.2, 0.8, 0.2, 1)
kCardShadow     // one deep warm shadow, and there is no second elevation
```

Gestural motion that carries its own physics — the deck's 640ms card exit —
keeps its own timing. Everything else should adopt the pair.

## 5. Type

**Two faces**, both bundled as static instances (D8):

| Role | Family | Weights |
|---|---|---|
| Display — read first | `BricolageGrotesque` | 600, 700, 800 |
| Body — everything else | `InstrumentSans` | 400, 500, 600, 700 |

`_applyAppFonts` in `swipe_eat_app.dart` applies the display face to
`headline*`/`title*` and the text face to the rest, so a call site asks
"display or text?" — a role, not a family. That seam is why the two-face
restoration was a two-line change (D63).

Scale: `kFontSizeHero` 44, `kFontSizeH1` 30, `kFontSizeH2` 20,
`kFontSizeBody` 15, `kFontSizeSmall` 13, `kFontSizeMicro` 11,
`kOverlineFontSize` 11.

### Helpers, not raw styles

`appTitleStyle` (the restaurant name — **identical** on the deck, Bites and
detail, so all three read as one design), `appTitleMutedStyle`,
`appPlaceStyle`, `appPanelTitleStyle`, `appEyebrowStyle`,
`appSectionTitleStyle`. Each reads the Material text theme, which is never null
under a `MaterialApp` — `!`, not a dead fallback.

`appTitleStyle` is w800 at −0.5 tracking: Bricolage is a display grotesk and
wants weight and tight tracking at headline sizes, where Lexend wanted neither.

### No all-caps

The design forbids all-caps labels. `AppEyebrow` was the app's **only**
uppercasing call site, so the rule is kept in that one widget rather than at
each of the eight places that use it, and a test asserts it. Letter-spacing
went with the caps — tracking exists to make caps readable.

## 6. Buttons

| Widget | Fill | Use |
|---|---|---|
| `AppPrimaryButton` | **`kCtaGradient`**, dark ink | The one primary action per screen |
| `AppSecondaryButton` | Dark bar, hairline border | Everything else |

Both share a private `_PillButton`. It stays private deliberately: *"the two
public wrappers above are the vocabulary, and a third fill would mean a third
meaning nobody defined."*

The gradient is painted by a `DecoratedBox` **behind** a transparent `Material`,
so the ink and its ripple still belong to the Material on top.

`kPillButtonHeight` 46, shared so a row of bar buttons lines up without each
call site guessing at padding.

## 7. `ScreenGlow`

The signature. A radial ember glow at the top of every dashboard tab, falling
off to the background before the first third of the page.

The design's ellipse is 130% of the screen wide and 48% tall, centred on the top
edge and lifted 6%. Flutter's `RadialGradient` is circular, so the shape is
produced by painting into a box of that aspect and letting it overflow the sides
rather than by distorting the gradient. It is `IgnorePointer` and sits at the
bottom of the `Stack` — it is the one place orange appears without being
tappable, and the exception is granted only because it never touches a control.

Wired into `DashboardTabShell`, so all five tabs get it.

## 8. Testing

`test/core/ui/design_tokens_test.dart` — 33 tests. Beyond the widget cases, the
palette itself is asserted, which is what makes a retint safe:

- **Every black is warm** — more red than blue, for all four surfaces.
- **Surfaces get lighter as they stack** — deep < dark < surface < panel, since
  they separate by colour rather than by shadow.
- **`kFresh` is the one non-orange accent**, and the three orange accents are
  actually orange.
- **All radii are non-zero and correctly ordered**, pill roundest.
- **Both faces are declared and differ.**
- `AppEyebrow` never upper-cases and sets no tracking.
- `AppPrimaryButton` paints the gradient and leaves its Material transparent;
  `AppSecondaryButton` does not.
- `ScreenGlow` overhangs both edges, sits above the top edge, and never takes a
  tap.

## 9. History

Three migrations, all still legible in the code:

1. **Glassmorphic → flat** (Aug 2026). `lib/core/ui/glass_ui.dart` with frosted
   panels and a lime accent gave way to `design_tokens.dart`.
2. **Rounded → square** (2026-08-31). Every radius token went to `0`, keeping a
   `// was …` comment. `AppCircleButton` was renamed `AppIconButton` in the same
   period.
3. **Flat/Lexend/square → Ngap** (2026-09-04). Warm blacks, ember/lava/char, the
   CTA gradient, the screen glow, radii back to 28/18/pill, and Lexend replaced
   by Bricolage Grotesque + Instrument Sans.

The Bricolage and Instrument files were **restored from git history** — they had
been deleted by `b627d27` when the app moved to Lexend, so the correct static
instances and their licences already existed. Lexend was removed in turn.

## 10. Known gaps

- **`kFresh` has no call site.** It needs opening hours; the schema has none.
- **The nav is not yet a black pill** with a cream expanding label, and the
  bite notch is not built. Both are Phase 3 work.
- **`kMotionDuration`/`kMotionEase` are not yet adopted** by existing
  transitions — they are defined, not yet applied everywhere.
- **No light theme**, and the tokens are literal dark values rather than
  semantic pairs, so this stays a one-way door.
- **`kBackgroundDeep` still has no user** — it is "behind the explore map" and
  no map is built.
- No documented contrast audit for `kCreamMuted` over arbitrary video frames,
  which is the hardest case in the app.

## 11. Out of scope

- **A light theme.** The product is a video-first dark surface.
- **A third button fill** — see §6.
- **Theming per restaurant** beyond `brand_color`.

## 12. Decision log

| ID | Decision | Status |
|---|---|---|
| D8 | Both faces are bundled as static instances, not fetched. Upstream ships them variable, and Flutter cannot instance a variable axis from a `fontWeight` — shipping the variable TTF silently breaks every weight above 400. | locked 2026-08-31, reaffirmed 2026-09-04 |
| D61 | ~~Every radius token is `0`~~ — **superseded 2026-09-04.** Radii are 999/28/28/18/10. The tokens remain the single seam, so the square look is five lines away. | superseded by D74 |
| D62 | Exactly two button fills. A third would mean a third meaning nobody defined. | locked 2026-08-31 |
| D63 | One name per role (`kDisplayFontFamily`, `kTextFontFamily`) even when they held the same family — call sites ask about role, not family. **Vindicated 2026-09-04**: restoring two faces was a two-line change. | locked 2026-08-31 |
| D64 | ~~`kAccentCream` is the primary action's fill~~ — **superseded 2026-09-04.** Cream is now the text colour; the primary action is the ember gradient. | superseded by D75 |
| D65 | `kBrandColorFallback` equals the panel colour, so an unbranded card is neutral rather than visibly wrong. | locked 2026-08-31 |
| D66 | The restaurant title style is identical across deck, Bites and detail. | locked 2026-08-31 |
| D67 | Tokens are named by role, never by colour. | locked 2026-08-31 |
| D68 | `lunar/` effects are kept separate from the token vocabulary. | locked 2026-08-31 |
| D74 | Corners return at 999/28/18/10, and the five radius tokens stay the only seam — the square app is one edit away in either direction. | locked 2026-09-04 |
| D75 | The primary action is filled with `kCtaGradient` (ember → lava) and is the app's only gradient. Orange is reserved for what the user can act on, and nothing acts more than this. | locked 2026-09-04 |
| D76 | The palette is asserted in tests — warm blacks, stacking order, one non-orange accent — so a retint cannot quietly break the rule that governs it. | locked 2026-09-04 |
| D77 | All-caps is forbidden, and the rule lives in `AppEyebrow` because that was the app's only uppercasing call site. | locked 2026-09-04 |
| D78 | `ScreenGlow` is the single exception to "nothing decorative is orange", granted only because it is `IgnorePointer` and never touches a control. | locked 2026-09-04 |
