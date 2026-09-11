Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-10
Cross-references: [STACK.md](STACK.md), [Redesign/NGAP-DESIGN-SYSTEM.md](../Redesign/NGAP-DESIGN-SYSTEM.md), [Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md), [General/PLAN.md](../General/PLAN.md)

# Design System

**The Ngap design system, as built.** Phase 2 of
[Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md) landed on 2026-09-04:
the token layer, both faces, the radii, the CTA gradient and the screen glow are
in the app. Part of Phase 3 followed the same day — the bite, the pill nav and
the motion tokens in use. The target spec is
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

`kFresh` has two call sites, both of them the same sentence: the Nearby pin's
open line and the deck card's open chip. It says "open now" and nothing else.

### Surfaces

| Token | Value | Role |
|---|---|---|
| `kBackgroundDeep` | `#050302` | Deepest. Only the `lunar/` dev gallery uses it |
| `kBackgroundDark` | `#0B0605` | The screen. **Warm black, never grey** |
| `kSurfaceDark` | `#171010` | Cards, panels, the bottom nav |
| `kSurfacePanel` | `#221614` | Raised elements on a card, list rows |
| `kBrandColorFallback` | = `kSurfacePanel` | An unbranded or unparseable row |
| `kGlass` / `kGlassStrong` | white @ 7% / 12% | Panels over photography — and, since 2026-09-10, the fill of `SimpleCard` and of a calendar plan row, both of which sit over the screen glow rather than over a photo |
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

`kActionButtonSize` 56 (like/pass/route), `kNgapButtonSize` 72 (the deck's one
primary action, and the largest control in the app), `kUtilityButtonSize` 44
(back, settings, more). The deck's bar spaces those with `kDeckActionGap` 20
between the three columns and `kDeckActionCaptionGap` 6 between a ghost's disc
and the word under it (§7c).

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

The signature. A radial ember glow at the top of a screen, falling off to the
background before the first third of the page.

The CSS gives the ellipse **radii** of 130 % of the screen width and 48 % of it
in height, centred on the top edge and lifted 6 %. Flutter's `RadialGradient`
is circular and sized by its *box*, so the box is twice those radii —
`width = screen width × 2.6`, height `= width × 0.96` — centred, top at −6 %,
and left to overflow the sides rather than distorting the gradient. Halving
that (the pre-2026-09-10 `× 1.3`) stopped the falloff short of the screen
edges. It is `IgnorePointer` and sits at the bottom of the `Stack` — it is the
one place orange appears without being tappable, and the exception is granted
only because it never touches a control.

**Every screen paints its own, and paints exactly one.** There is no shared
wrapper that supplies it: `DashboardTabShell` paints one (so Bites, which is
the only tab built on the shell, gets it that way), and Calendar and You each
paint their own because they build their own frame. Swipe and Nearby paint none
— both are full-bleed over a card or a map, with no ground for a glow to sit
on. The dashboard page itself paints **none**, deliberately: it used to paint
one behind the `IndexedStack`, which doubled the glow on the three tabs that
already had theirs.

Off the dashboard it is on splash, sign-up, phone sign-in, onboarding,
settings, the restaurant screen, the plan page, the plan date picker, the
wishlist, friends and invite. `grep -rn 'ScreenGlow()' lib` is the list.

## 7a. The bite

> A circular notch out of the top-right corner of any restaurant surface the
> user has saved. The app's **only** decorative device, and it means one thing.

`BiteNotch` is a `ClipPath`, not a painted circle: whatever sits behind the
surface shows through the notch, which is what makes it read as a bite rather
than as a dot someone put in the corner. Geometry is the prototype's mask —
a circle of `kBiteNotchRadius` (30) centred `kBiteNotchInset` (6) inside the
corner, so it takes a bite out of *two* edges instead of shaving one.

Because the mark is part of the silhouette, it cannot be mistaken for a
button — which every badge, heart and star it replaces could be (D79).

`bitten: false` returns a plain `ClipRRect`, so a caller hands it a saved or
unsaved restaurant without branching.

**Where it is:** the detail hero's media and the auth cover's blob.

**Where it was:** every Bites tile, until D125. The tile is now a photo over
a caption strip, and its saved mark is the ember check of §7g — a full circle
drawn inside the photo, which a notch at inset 6 / radius 30 (a quarter-disc
hanging off the corner) cannot be. D79 still governs the hero and the blob.

**Where it is not:**

- **The swipe card.** The deck only ever deals unswiped places, so the flag
  would be false at every call site. Wiring it needs the deck to know what is
  already saved, which is plumbing rather than paint (D81).
- **Replacing the super-like star.** Moot since D84: the star went with the
  feature, which is what let the tile's mark go to its specified full size
  (D82, resolved).

## 7b. Navigation

A dark pill bar, 64 high, in which the **current tab widens into a labelled
ember pill** and the other four are icons at `kCreamSecondary`.

Only the selected tab carries a word. That is the point: the bar spends its
width on the one question the user is asking — "where am I?" — instead of
spreading it across five answers they already have (D80). Three signals say it
independently, so the bar survives being read without colour: the ember fill,
the dark `kOnAccent` ink, and the filled-vs-outline glyph.

The width is animated, not switched, because the pill growing out of the icon
is what ties the new screen to the tap that asked for it. Flutter's `flex` is
an integer, so the tween runs 100 → 230 — finer than a pixel at these widths.

**230 is a ceiling, not a constant.** The pill takes its width as a *share* of
the bar, so a fixed ratio squeezes the four inactive tabs: at 320 pt they came
out 43.8 wide, under Material's 48 and under the iOS HIG's 44 — a real miss on
an iPhone SE and in any split-screen or foldable width. `selectedFlexFor` now
derives the ratio from the bar's own width, growing the pill only as far as the
inactive tabs can afford. The first version of the touch-target test asserted
the *height*, which was never in doubt; it asserts both axes now.

Lives in `features/dashboard/presentation/dashboard_bottom_nav.dart`, split
out of the page for the same reason `LikesTabView` is split out of `LikesTab`:
the tabs draw their own headings, so "only the current tab is labelled" is not
assertable while the tab bodies are on screen, and five idle animations mean a
`pumpAndSettle` never settles.

Every tab keeps its name in the semantics tree whether or not the label is
drawn; four of five show only a glyph, and a glyph is not a name.

**The trap, and it bit once:** `Semantics(excludeSemantics: true)` drops the
child's tap **action** along with its labels. Naming the tabs that way and
stopping there produced five buttons a screen reader could read and announce as
selected but could not activate — the whole nav, unusable with TalkBack, while
looking correct on screen and in the widget tree. The `Semantics` re-declares
`onTap` itself. A test drives all five tabs through the semantics action alone,
so the fix cannot be quietly undone (D83).

## 7bb. Tab headers

`DashboardTabShell` carries three lines, and which slot a line goes in is a
statement about it:

- **eyebrow** — above the title. Names the screen *before* you read it.
- **title** — the screen's name.
- **subtitle** — below the title. Qualifies it *after* you have read it; a
  count, usually.

The subtitle exists because the design puts "14 saved" under "Your bites",
where an eyebrow could only ever put it over. Bites uses title + subtitle and
no eyebrow; You is titled **"You"** with the signed-in name beneath, because
the design titles the screen and puts the name in the identity row where the
portrait is.

The Bites count renders only once the list has loaded — "0 saved" while
fetching would be a wrong answer rather than a missing one.

## 7c. The deck's action bar

Three circles, centred as equals around the one that matters:

| Control | Size | Fill | Caption | Gesture |
|---|---|---|---|---|
| Skip | `kActionButtonSize` 56 | `kSurfaceDark` + hairline | `Skip` | left |
| **`AppNgapButton`** | `kNgapButtonSize` **72** | `kCtaGradient` | — | right |
| Later | `kActionButtonSize` 56 | `kSurfaceDark` + hairline | `Later` | up |

The two ghosts each sit in a column that is a full `kNgapButtonSize` wide —
as wide as the disc in the middle, not as wide as their own 56 — with
`kDeckActionGap` (20) spacers between the three. That is what keeps Ngap
dead-centre whatever the captions measure at a large text size.

The caption sits `kDeckActionCaptionGap` (6) under the disc, in
`kFontSizeMicro` (11) w600 `kCreamSecondary` at height 1.2, one line,
ellipsised. It is wrapped in `ExcludeSemantics` — the button already announces
itself, and a second node reading the same word makes a screen reader say every
move twice. **Ngap carries no caption**: `AppNgapButton` carries the word
instead of a glyph, so a third one under it would be the same word twice.

`AppNgapButton` carries the **word**, not a glyph. The design forbids a bare
heart here: "Ngap" is the product's name for the action, and a button that says
it teaches the word to a new user in a way no icon can. It is the app's only
circular gradient fill and the only control larger than a touch target needs to
be, both for the same reason — on this screen it is the only thing worth doing
(D86).

It was five controls before: rewind on the far left, a super-like star between
the two, and Pass/Like as wide pills. All three of those features are retired
(D84), and the bar is the design's three.

## 7d. The map's furniture

Three pieces, all floating over the map area
([Features/Nearby-Map.md](../Features/Nearby-Map.md)). There are **no tiles** under them
since D126 — the pins sit on `kBackgroundDark`, and the scrim token that
existed to darken the raster was deleted with it.

The filter button up there is the deck's, word for word: `Discovery settings`
as its semantics label, `<n> filter(s) on` as its value, and an ember glyph
whenever something is narrowing the results. One sheet, one name, one colour
for "a filter is on".

## 7e. Preference controls

Four shapes carry every yes/no, either/or and how-much question in the app.
They live in `lib/features/profile/presentation/preference_controls.dart`
because the same four questions are asked in three places — the first-run
"Any rules?" step, the You tab's edit sheets, and Settings — and a preference
that looks like a different control on the screen where you change it does not
read as the same preference.

| Widget | Design | Shape |
|---|---|---|
| `PrefRow` | `.setrow` | `kSurfaceDark`, hairline, `kRadiusPanel`, 16 padding. A header over a full-width control |
| `PrefSwitchRow` | `.setrow.inline` | Title + explanation on the left, a `PrefSwitch` on the right. **The whole row is the target** — a rule you can only change by hitting a 50 px thumb is a rule people leave wrong |
| `PrefSwitch` | `.switch` | `kSwitchWidth` 50 × `kSwitchHeight` 30 track, ember when on, a `kAccentCream` `kSwitchThumbSize` 22 thumb travelling 20 px over `kMotionDuration`. Not a Material `Switch`: that one draws a different outline, thumb and travel, and the difference is visible beside anything else on these screens. The track is 30 px tall; the **touch target is 44** |
| `PrefSegmented` | `.seg` | A `kSurfacePanel` pill with `kSegmentTrackPadding` 4 around `kSegmentHeight` 36 buttons, each `Expanded` (the CSS is `flex:1`). The chosen one is ember on `kOnAccent`. **`value` is nullable**, because "not answered yet" has to look different from the first option |
| `PrefBudgetRow` | `.setrow` + `input[type=range]` | A `RangeSlider` in ember/cream with a display-face read-out in the header and `.range-ends` micro labels under it |

Two rules the controls encode rather than leave to their callers: a segment
with no selection is a legitimate state, and a range's top stop **releases** the
cap rather than setting one (`budget_max` null, read-out "RM 10+").

### The first-run progress bar

`.steps` has **three** states, not two: ember for the current step, `kCreamMuted`
for the ones behind, `kHairline` for the ones ahead — `kStepBarHeight` 3 with
`kStepBarGap` 5. A bar that only fills says "this much is done"; this one says
"you are here, and there are three more", which is the question someone halfway
through a first run is actually asking.

### The You tab's stat tiles

Three equal `kSurfaceDark` tiles in an `IntrinsicHeight` row: a
`kFontSizeStatValue` 28 display number over a `kFontSizeMicro` cream-70 label.
The label **wraps** rather than ellipsing — "eating-out streak" does not fit one
line in a third of a 320 px screen, and an ellipsis there would hide which
number it is. The number is in a `FittedBox`, so a four-digit count shrinks
instead of overflowing.

## 7f. The filter chip row

`AppFilterChip` and the `.chiprow` it lives in — the Bites tab's filters, and
the pattern any later filter row should copy.

| Piece | Value |
|---|---|
| Height (drawn) | `kChipHeight` = 36 |
| Height (tapped) | `kMinTapTarget` = 44 |
| Shape | `kRadiusPill`, 16 px of horizontal padding |
| Unchosen | transparent, `kHairline` outline, `kTextOnPhoto` label at `kFontSizeSmall` w500 |
| Chosen | `kAccentEmber` fill and border, `kOnAccent` label |
| Transition | `kMotionDuration` / `kMotionEase` |

Two rules the shape carries:

- **Drawn at 36, tapped at 44.** The chip keeps the design's size and the
  finger still gets its target — a `SizedBox(height: kMinTapTarget)` with the
  pill centred inside it. Copy this rather than growing the chip.
- **Ember means chosen, nothing else.** A chip that navigates instead of
  filtering ("Wishlist →") passes `selected: false` forever, because it holds
  no state to show. Lighting it would be the palette lying.

The row itself scrolls horizontally and bleeds to both screen edges, so it
reads as continuing past them rather than as five things that happened to fit.

Semantics: `label` + `isButton` + `hasSelectedState`, with the tap action
re-declared beside `excludeSemantics` (D83).

## 7l. Bottom sheets, and the discovery sheet's patterns

`BottomSheetThemeData.dragHandleColor` is `kHairline`, set once in
`swipe_eat_app.dart` — the same white-at-14 % that separates two dark surfaces
everywhere else, so the handle reads as a seam rather than as a control. The
discovery sheet asks for it with `showDragHandle: true`; nothing draws its own.

Two patterns the discovery sheet establishes for any sheet that asks questions
([Features/Profile-Preferences.md](../Features/Profile-Preferences.md) §3):

- **A section label with a right-aligned trailing value.** The label on the
  left, what the section currently answers on the right in `kAccentCream` w700
  — `10 km`, `2 chosen`. The answer is readable without opening the control
  under it.
- **`_SectionCaution`** — an `info_outline_rounded` glyph at 14 px in
  `kAccentEmber` beside `bodySmall` in `kTextOnPhotoSecondary`. It warns about
  a choice rather than reporting an error, which is why it is the accent and
  not a red the palette does not have.

### The one on-photo exception

Controls over a photo or video take `kFillOnPhoto` (black @ 35 %). The sound
pill is the exception: `kSurfaceDark` at **82 %** alpha, `minHeight` 36, its
border and ink going `kAccentEmber` once the sound is on. It sits over a moving
clip that can go white at any frame, where a 35 % wash disappears — and at 36
it is sized as a control rather than as a caption.

## 7g. The Bites tile

`RestaurantGridCard` is a photo over a solid caption strip, not a photo with
text laid over it (D125):

- The **photo** fills the top of the tile; it is `Expanded` into whatever the
  caption leaves, so a large text scale shrinks the picture rather than
  overflowing the tile. No scrim: nothing is read over it.
- The **caption strip** is `kSurfaceDark` under a `kHairline` border, 12 pt
  padding, the name in `appPanelTitleStyle` on one line and
  "Cuisine · Neighbourhood" in `kCreamMuted` `labelSmall` w600 under it.
- The grid's `childAspectRatio` is **0.9**, which lands the photo at roughly
  two thirds of the tile on a phone at the default text size.

Two marks sit on the photo, in different corners:

| Mark | Corner | Says |
|---|---|---|
| The **saved check** — `kCheckCircleSize` 26, `kAccentEmber`, 14 px `check_rounded` in `kTextOnPhoto` | top right | in your bites |
| The **planned pill** — ember, `kFontSizeMicro` w700 on `kOnAccent` | top left | a day is set |

The check is the wishlist row's tick at the same size and glyph, so "saved"
and "done" read as one family. It is a mark, not a control — `IgnorePointer`
under an opaque `GestureDetector`, so the tile stays one tap target. The
wishlist bookmark that used to share the corner is removed (D84, D125).

## 7h. The strike-through

Crossing a wishlist row off draws an ember 2 px rule across the name, left to
right, over `kStrikeDuration` (260 ms).

It is a scaling bar, not `TextDecoration.lineThrough`, and it has its own
duration rather than `kMotionDuration`, for one reason each: a text decoration
is either there or it is not, and this has to **travel** — slower than the
interface transitions, because it is a drawing gesture the eye is meant to
follow, so the crossing-off reads as something the tap did rather than a state
the row was always in. The photo desaturates and fades to 50 % on the same
tap, and the row re-sorts to the bottom.

## 7j. The restaurant screen's three shapes

Added 2026-09-06 with S3 — see
[Features/Restaurant-Detail.md](../Features/Restaurant-Detail.md).

### The hero title block

The bottom-left stack on any full-bleed restaurant hero: tag chips, the name,
one meta line. It differs from the deck card's block in exactly two ways, both
because the detail screen shows **one** restaurant rather than a stack — the
name is `kFontSizeDetailTitle` (36 px, w700) instead of 34/w800, and the chips
take `kFillTitleTag` (`rgba(0,0,0,.3)`) instead of `kFillTag`'s white veil,
because they sit on the deep end of a scrim where a light fill reads as fog.

`AppTitleTagChip` is that chip: 11 px, pill, 26 px **minimum** height — a
minimum and not a fixed height, so the chip grows at a large text scale rather
than clipping its label.

### Fact tiles

`kSurfaceDark`, hairline, `kRadiusPanel`, 12 pt padding, a display-face value
(`appFactValueStyle`, 17/700) over a micro caption (`appFactCaptionStyle`).
Laid out as equal-width `Expanded` cells inside an `IntrinsicHeight` row, so
tiles share a height even when one caption wraps.

Two rules the value carries:

- It **never wraps** — the design's `white-space:nowrap`. At a large text
  scale it shrinks inside a `FittedBox` instead, because a third of a 320 pt
  row is not wide enough for "From RM 19" at 2×.
- A tile with no answer is **removed, not blanked** (D111). The row re-flows
  and the remaining tiles widen.

### Dish rows

A 40 px `kRadiusWishThumb` thumb, the name at body weight 600, the description
in `kTextOnPhotoSecondary`, and the price right-aligned in `appRowTitleStyle` —
the same display 16/700 a wishlist row's title uses, because it is the same
object at the same size. A hairline under every row but the last.

## 7k. The way in

The two screens a signed-out user sees — welcome (S1) and sign-up (01b) —
share one small vocabulary, in `lib/features/auth/presentation/auth_widgets.dart`.

**The glow is stronger here.** `WelcomeGlow` / `kWelcomeGlow` is the same
device as `ScreenGlow`, painted into a wider, taller ellipse and starting at
`kAccentEmber` rather than `kAccentLava` (the design's `.onb .screen` overrides
`--grad` with `140% 60% at 50% -8%`). It exists for exactly one screen, which
is why it is a second widget rather than a flag on the first: the app's glow is
a constant every other screen relies on being identical.

**The card stack** is three `kWelcomeCardWidth` × `kWelcomeCardHeight`
(196 × 244) covers at the prototype's transforms — −12° / +9° / −2°, translated
−38 / +40 / 0, scaled .92 / .96 / 1, at 75 % / 85 % / 100 % opacity. The middle
card carries the bite, so the signature is on screen before the word "Ngap" has
been explained. The whole stack is scaled to fit the 38 % of the screen it is
given (`kAuthHeroFraction`), rather than clipped, so three cards still read as a
deck on a 320 px phone.

A card whose cover could not be loaded is a plain `kSurfaceDark` surface with no
name. Never a gap: a card with nothing in it says "a card goes here", where a
hole in the stack says the app is broken before it has said anything else.

**The sign-in buttons** (`AuthProviderButton`) are the design's `.su .btn`:
`kAuthButtonHeight` (52) rather than the app's usual 46, left-aligned behind a
`kAuthProviderMarkSize` (22) round mark. They are the only buttons on their
screen, they stack, and the eye reads a stack down its left edge. Still only two
fills (D62) — `primary` is the ember gradient, `ghost` the panel and a hairline.
`AuthTextButton` is the design's `.textbtn`: drawn at 13 px, tapped at
`kMinTapTarget`.

**The wordmark** (`AuthBrand`) is display 22/800 with the full stop in ember —
the one orange mark in the app that is neither a control nor the glow, because
it is the product's name rather than decoration.

## 7i. The calendar: day cells, plan rows, the picked bar

Three shapes, one feature — [Features/Plans-Calendar.md](../Features/Plans-Calendar.md).

### The day cell

The prototype's `.day` is a 36 px circle (`kCalendarDaySize`) with a 1.5 px
hairline, in a 7-column grid gapped `5px 2px` (`kCalendarRowGap`,
`kCalendarColumnGap`). Its colour resolves in one order, and only one wins:

| State | Fill | Border | Ink |
|---|---|---|---|
| selected | `kAccentEmber` | ember | `kOnAccent` |
| today | `kAccentCream` | cream | `kOnAccent` |
| planned | `kSurfaceDark` | ember | `kTextOnPhoto` |
| past | transparent | `kHairline` | `kCreamMuted` |
| otherwise | transparent | `kHairline` | `kTextOnPhoto` |

Chosen beats today beats planned — the same order the prototype's classes
resolve in, and the same order orange means in this app: acted on first,
actionable second.

Under the disc sits a 4 px marker (`kCalendarDotSize`): today's ember dot, or
one pip per plan up to three. A planned day that is neither today nor selected
draws its restaurant's cover inside an ember ring (`kCalendarRingWidth` 2,
inset `kCalendarRingInset` 2), falling back to two initials — never an emoji
(D88).

Two things the CSS does not have to say and Flutter does:

- The **cell** is the tap target, not the disc. The cell is 48 pt tall
  (36 + 5 + 4 + 3) and takes its column's width, so the 44 pt minimum is met on
  the axis that has room. A finger in the gutter between two days used to do
  nothing.
- The day number sits in a `FittedBox(scaleDown)`. A circle that cannot grow
  and a doubled text scale otherwise spill two digits over the ring; the whole
  date is on the semantics node either way, so nothing is lost to a screen
  reader.

Every cell announces itself as one sentence — "Fri 4 Sep, today, 2 plans" —
with `excludeSemantics`, so the tap is re-declared on the node (D83). A past
day carries no tap action at all.

The month header (`.cal-head`) puts the month against either a pair of 32 px
arrows (drawn 32, tapped 44) or one trailing chip. **The back arrow is absent,
not disabled, in the month you are standing in**: an arrow that is always there
and only sometimes works is a worse answer than one that is not there.

### The plan row

`.plan` is a `kGlass` card with a hairline (glass rather than `kSurfaceDark`
since 2026-09-10, so the screen glow reads through the rows instead of stopping
at them): a 48 px logo at radius 14 (`kPlanLogoSize`, `kRadiusPlanLogo`)
carrying the cover or two initials in display 16 w800 (`kPlanInitialsFontSize`),
the name in body w600 ellipsised, a `kCreamSecondary` detail line, and an ember
time pill.

The detail line **leads with the people** — `planPeopleLine` from
`friend_captions.dart` — then the neighbourhood, then the distance:
"Just you · Kepong · 8.7 km", "3 friends · 2 confirmed · Kampung Baru". Each
part after the first is dropped rather than faked when it is unknown — no
distance without a real fix, no neighbourhood placeholder — so the row never
carries a dangling separator. Under it sits a `FriendAvatarStack` at
`kAvatarSizeCompact`, showing the roster once it lands; anyone who declined is
not drawn. The count on the line is read off the plan's own members rather than
off the faces, so the line is right the moment the plan is and the faces appear
a beat later without moving anything.

The row answers a tap (open `/plans/:id`, the plan's own page, not the
restaurant) and a long press (cancel). Both are re-declared on the semantics
node beside the one-sentence label, because `excludeSemantics` drops them
(D83). Cancelling confirms in a **bottom sheet**, which keeps the row on screen
behind it, rather than in a dialog.

### The picked bar

`.picked` is the answer read back: a 40 px thumb, "Fri 4 Sep · 20:00" over
"Kak Ros · Just you", and the primary button. The summary is `nowrap` in CSS
and must say so explicitly here, or the bar grows a line taller at a large text
scale.

Below `kPickedBarStackWidth` (340) the bar **stacks** — summary above, button
across the width beneath. "Lock it in" is a pill that cannot shrink, and at a
doubled scale it alone is most of a 320 pt row; ellipsising the answer down to
nothing to keep it beside the button would be the wrong half to sacrifice.

### Two shared-widget notes

`AppFilterChip` fills whatever width it is handed — its `Center` expands under
bounded constraints. Two call sites therefore wrap it:

- The time slots (`.slots`, a `Wrap`) put each chip in an `IntrinsicWidth`, or
  a `Wrap` hands every chip the whole line and stacks the five one per row.
- The calendar header's trailing chip is an `IntrinsicWidth` inside a
  `ConstrainedBox` capped at half the row: natural width and flush right at any
  ordinary size, and it gives ground to the month rather than pushing it off
  the screen at 2×.

The slot chips are drawn at `AppFilterChip`'s 36 px rather than the
prototype's `.slots .chip{height:40px}`, and "Lock it in" is `AppPrimaryButton`
at 46 rather than the prototype's 40. Both are deliberate: D62 allows exactly
two button fills and one chip, and forking a control to gain 4 px is a worse
trade than the 4 px.

## 7m. Faces

The vocabulary the friends phase added — [Features/Friends.md](../Features/Friends.md).
A face is a photo, or two initials on a coloured ground.

| Token | Value | For |
|---|---|---|
| `kAvatarSize` | 32 | A face in a stack — the detail screen's friends row, anywhere people are counted rather than chosen |
| `kAvatarSizeRow` | 44 | A face on a row you can tap. It is `kMinTapTarget` on purpose: the row's height comes from its avatar, so the target *is* the picture |
| `kAvatarSizeCompact` | 20 | A face on a calendar plan card, where three of them and a line of text share one line |
| `kAvatarOverlap` | 10 | How far each face in a stack laps the one before it |
| `kAvatarBorder` / `kAvatarBorderCompact` | 2 / 1.5 | The ring separating one face from the one behind |
| `kAvatarInitialsFontSize` | 12 / 15 / 9 | Initials at each of the three sizes (`…Row`, `…Compact`) |
| `kAvatarStackMax` | 3 | Faces drawn before the caption takes over the counting |
| `kAvatarGrounds` | five pastels | The ground behind initials |
| `kAvatarInk` | `#140A05` | The ink on any of them |
| `kPersonCheckSize` | 26 | The tick at the end of a selectable row — the wishlist's `kCheckCircleSize`, same mark, same job |
| `kSearchBarHeight` | 46 | The invite screen's search field |
| `kInviteCountFontSize` | 22 | The running total beside "Send invites", in the display face |
| `kInviteButtonMaxWidth` | 220 | How wide "Send invites" may get before it reads as a banner |

**Overlap rather than a gap**: faces that touch read as a group, faces that do
not read as a list.

`kAvatarGrounds` are **not accents and the palette rules of §1 do not reach
them**. An accent means something — ember is action, `kFresh` is open now —
and these mean nothing at all; they are wallpaper behind two letters, picked by
hashing the person's id so one person keeps one colour on every screen they
appear on. They are one list rather than five named tokens precisely so nothing
but an avatar can reach for one.

## 8. Testing

`test/core/ui/design_tokens_test.dart` — 49 tests. Beyond the widget cases, the
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
4. **The bite and the pill nav** (2026-09-04, Phase 3). The first Ngap devices
   that are shapes rather than colours.

The Bricolage and Instrument files were **restored from git history** — they had
been deleted by `b627d27` when the app moved to Lexend, so the correct static
instances and their licences already existed. Lexend was removed in turn.

## 10. Known gaps

- **The bite is on the detail hero and the auth blob only** — not the swipe
  card (D81), and no longer on the Bites tile, which carries the ember check
  instead (D125).
- **No light theme**, and the tokens are literal dark values rather than
  semantic pairs, so this stays a one-way door.
- **`kBackgroundDeep` has no user in the app** — only `dev/lunar_gallery.dart`,
  which does not ship.
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
| D79 | The saved-marker is a notch **clipped out of** the surface, not a badge drawn on it. A mark that is part of the silhouette cannot be mistaken for a button; the heart, star and badge it replaces all could. **Superseded on the Bites tile by D125** ([Likes-Visits](../Features/Likes-Visits.md)); stands on the detail hero and the auth blob. | locked 2026-09-04 |
| D80 | Only the current tab is labelled. The bar spends its width on the one question the user is asking, and three independent signals — fill, ink, filled-vs-outline glyph — say which tab is current without relying on colour. | locked 2026-09-04 |
| D96 | The design's chip row replaces the Bites segments. `AppFilterChip` is drawn at 36 and tapped at 44, and only a *selected* chip is ember — a chip that navigates never lights. | locked 2026-09-05 |
| D81 | The bite is not wired to the swipe card. The deck deals only unswiped places, so the flag would be false everywhere — an always-false switch is dead code, not a reskin. | locked 2026-09-04 |
| D82 | ~~The super-like star survives the bite~~ — **resolved 2026-09-04 by D84.** The star went with the feature, which is what let the tile's mark go to its specified full size. | resolved by D84 |
| D83 | Any `Semantics` using `excludeSemantics` re-declares its own `onTap`, and an accessibility claim is asserted by driving the semantics action, never by reading the widget tree. | locked 2026-09-04 |
| D101 | ~~The map's `TileProvider` is constructor-injected~~ — **superseded 2026-09-10 by D126.** The Nearby map draws no tiles at all, so there is no provider to inject; the pins sit on `kBackgroundDark`. | superseded by D126 |
| D122 | The sound pill drives TikTok's player by postMessage, which is why it is the one on-photo control that is not `kFillOnPhoto`: it is a live control over a moving clip, so it takes an opaque ground and goes ember when the sound is on (§7l). | locked 2026-09-10 |
| D125 | The Bites tile's saved mark is an ember check drawn inside the photo, not a notch clipped out of the tile; the wishlist bookmark badge is removed rather than hidden. Supersedes D79 on the grid tile only (§7a, §7g). | locked 2026-09-10 |

| D106 | The preference controls (`.setrow`, `.switch`, `.seg`, the budget range) are one shared vocabulary across the wizard, the You tab and Settings, and each encodes "not answered yet" as a state it can draw. | locked 2026-09-05 |
| D110 | The plan time is five fixed chips, reusing `AppFilterChip` at its own 36 px rather than forking a 40 px variant. See §7i. | locked 2026-09-06 |
