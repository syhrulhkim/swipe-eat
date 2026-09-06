Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
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

**Where it is:** every tile in the **Liked** segment of Bites, at the
prototype's full 30 px.

**Not the whole Bites grid.** Bites has three segments and they share one grid
builder. Visited is keyed on `visited_at` and Reviewed on the existence of a
review — *neither predicate mentions `liked`*. A place swiped left and later
marked visited belongs in Visited and is not saved, so it must not carry the
bite. The flag is per-segment, not per-grid.

The tile bite was briefly two thirds size, to clear the super-like star. The
star is retired (D84), so the corner is free and the scale factor is gone. A
test asserts the clearance the full notch has over the two remaining row
buttons, and a second asserts that a *third* badge would collide — which is
why the star could not simply have stayed.

**Where it is not, yet:**

- **The swipe card.** The deck only ever deals unswiped places, so the flag
  would be false at every call site. Wiring it needs the deck to know what is
  already saved, which is plumbing rather than paint (D81).
- **Replacing the super-like star.** The design says the notch replaces it; the
  star means "must try" and the notch means "saved", which are different facts.
  Retiring super like is a decision the redesign has not taken (D82). Until it
  does, a bitten tile moves its badge row to the *left* corner so the notch
  does not clip a button.

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

| Control | Size | Fill | Gesture |
|---|---|---|---|
| Skip | 56 | `kSurfaceDark` + hairline | left |
| **`AppNgapButton`** | **72** | `kCtaGradient` | right |
| Later | 56 | `kSurfaceDark` + hairline | up |

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

Three pieces, all floating over the tiles
([Features/Nearby-Map.md](../Features/Nearby-Map.md)).

**The me-dot** — an 18 px ember circle (`kNearbyMeDotSize`) with a 4 px
`kBackgroundDark` border (`kNearbyMeDotBorder`) and a 12 px halo
(`kNearbyMeHaloSpread`) of `kNearbyMeHalo`, which is lava at 22%. The border is
the map's own background colour, so the dot punches a hole in the tiles rather
than sitting on them.

**The pins**

| Pin | Blob | Border |
|---|---|---|
| Ordinary | 76 (`kNearbyPinSize`) | 2 px `kHairline` |
| The two closest | 96 (`kNearbyPinBigSize`) | 2 px `kAccentEmber` |

Ember on the two closest is not decoration — they are the two the user is most
likely to act on, and orange marks what is actionable (D78's rule, not its
exception). The blob carries a `BiteNotch` at `kNearbyPinBiteRadius` (18) when
the place is saved, so the map speaks the same silhouette as the Bites grid
(D79), and an ember distance badge (10 px w700 on `kOnAccent`) at the top right.

**The scrim** — `kNearbyMapScrim` between the tiles and the markers. OSM's
raster tiles are a daylight map, and cream text over them is unreadable without
it. It is a flat overlay rather than a colour matrix on the tile layer, because
a matrix cannot be verified by a widget test.

**The radius stepper**, bottom right — a 44 px minus (`kUtilityButtonSize`,
`kSurfaceDark` + hairline), the value block, a 44 px ember plus. The value is
micro "Away from you" over a `kNearbyRadiusValueFontSize` (30) w800 number with
a `kNearbyRadiusUnitFontSize` (14) w600 unit, so the number is legible at a
glance and the unit does not compete with it. Only the plus is ember: widening
is the move that finds more food.

**The results bar** — `kSurfaceDark`, hairline, `kRadiusPanel` (18) on the top
corners only, flush with the nav, so it reads as the map resting on the nav
rather than a card floating over both. Figures are micro labels over
`kNearbyResultFigureFontSize` (18) w700 values; the action is a
`kNearbyResultButtonHeight` (46) **flat** ember pill, not `kCtaGradient` — the
gradient is the deck's Ngap button alone (D75), and a second gradient on the
same journey would make neither primary. Under width pressure the gap between
the figures collapses and the figures ellipsize before the button gives up a
pixel: the action must never be the thing that gets cut.

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

## 7g. Two marks on a tile

`RestaurantGridCard` can carry three signals at once, and they do not share
corners:

| Mark | Corner | Says |
|---|---|---|
| The **bite** (§7a) | top right, clipped | saved |
| The **wish badge** — `kWishBadgeSize` 28, `kFillWishBadge`, hairline, 14 px bookmark | top right, drawn | still on the wishlist |
| The **planned pill** — ember, `kFontSizeMicro` w700 on `kOnAccent` | top left | a day is set |

The first two collide by design: the notch is a 30 px circle centred 6 px
inside the corner, and a 28 px badge inset 8 px falls almost wholly within it.
The prototype's own mask erases its `.wish` for exactly this reason. The badge
is therefore painted **outside** the clip — an outer `Stack` around the
`BiteNotch` — so it reads as the bookmark sitting in the bite rather than
disappearing into it. `restaurant_grid_card_test.dart` asserts the overlap, so
the day the geometry changes the test stops being vacuous rather than silently
passing.

The tile's second line is **"Cuisine · Neighbourhood"**, and drops the
neighbourhood rather than leaving a dangling separator when the row has none.

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

## 8. Testing

`test/core/ui/design_tokens_test.dart` — 42 tests. Beyond the widget cases, the
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

- **`kFresh` has no call site.** It needs opening hours; the schema has none.
- **The Explore, Group and Profile tab bodies are untouched.** Phase 3 changed
  the frame around them, not their contents.
- **The bite is on Bites tiles only** — not the swipe card (D81), and not yet
  in place of the super-like star (D82).
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
| D79 | The saved-marker is a notch **clipped out of** the surface, not a badge drawn on it. A mark that is part of the silhouette cannot be mistaken for a button; the heart, star and badge it replaces all could. | locked 2026-09-04 |
| D80 | Only the current tab is labelled. The bar spends its width on the one question the user is asking, and three independent signals — fill, ink, filled-vs-outline glyph — say which tab is current without relying on colour. | locked 2026-09-04 |
| D96 | The design's chip row replaces the Bites segments. `AppFilterChip` is drawn at 36 and tapped at 44, and only a *selected* chip is ember — a chip that navigates never lights. | locked 2026-09-05 |
| D81 | The bite is not wired to the swipe card. The deck deals only unswiped places, so the flag would be false everywhere — an always-false switch is dead code, not a reskin. | locked 2026-09-04 |
| D82 | The super-like star survives the bite. "Must try" and "saved" are different facts; retiring super like is [Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md) §4.5's call. A bitten tile moves its badges to the left corner instead. | open, pending §4.5 |
| D83 | Any `Semantics` using `excludeSemantics` re-declares its own `onTap`, and an accessibility claim is asserted by driving the semantics action, never by reading the widget tree. | locked 2026-09-04 |
| D101 | The map's `TileProvider` is constructor-injected; the OSM default is development only, and a fake keeps the widget tests off the network. | locked 2026-09-05 |

| D106 | The preference controls (`.setrow`, `.switch`, `.seg`, the budget range) are one shared vocabulary across the wizard, the You tab and Settings, and each encodes "not answered yet" as a state it can draw. | locked 2026-09-05 |
