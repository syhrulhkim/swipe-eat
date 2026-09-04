# Stack: Flutter

Use when the project has a `pubspec.yaml`, or the brief says Flutter, Dart, iOS/Android app, or names a mobile screen. This is the only non-web stack here — the studio floor in SKILL.md Step 3 still applies, but three of its rules translate rather than transfer (see Accessibility floor).

Deliverable is Dart in the app, not a mockup. If the brief wants something reviewable before code, build the self-contained HTML prototype (`html-css.md`) first and treat this file as the port.

## Structure

- Tokens in **one file**: `lib/core/ui/design_tokens.dart`, as top-level `const` — colors, radii, sizes, font families, then text-style helpers. Nothing else in the app writes a raw `Color(0x…)` or a magic radius.
- Spacing is a `4px`-grid class (`AppSpacing.xs/sm/md/lg`), not scattered `EdgeInsets.all(13)`.
- Screens live under `lib/features/<name>/` in four folders, and the dependency arrow points one way:

```
presentation/  →  state/  →  data/  →  models/
                                   ↘  domain/   (pure, no I/O)
```

`presentation/` holds widgets only — no network calls, no business rules. Shared UI goes in `lib/core/ui/`.

## Tokens

- **Name by role, never by colour**: `kAccentEmber`, `kSurfacePanel`, `kTextOnPhotoMuted` — not `kOrange`, `kDarkGrey`. A rebrand is then one file.
- Keep a token when its value goes to a no-op, with a comment saying what it used to do (`const double kRadiusCard = 0; // was the large full-bleed cards`). Call sites stay readable and reversing the decision is a one-line change.
- Text styles are **helpers, not raw `TextStyle`s**, each named for its job: `appTitleStyle`, `appPanelHeadingStyle`, `appSectionTitleStyle`. They read the Material text theme, which is never null under a `MaterialApp` — use `!`, not a dead fallback.
- Colour that arrives from data (a brand hex on a row) is parsed through a single helper with a named fallback token, so an unparseable value renders as a neutral surface rather than something visibly wrong.

## Fonts

**Bundle them; never fetch at runtime.** An app that renders cached content offline must not fall back to a platform font on first launch.

Declare each weight in `pubspec.yaml` as a **static instance** cut from upstream's variable font (`fonttools varLib.instancer`). Flutter picks a face by the declared `weight` and cannot instance a variable axis from a `fontWeight`, so shipping the variable TTF silently breaks every weight above 400. Keep the licence next to the files.

## Components

- **A small closed vocabulary of buttons** — typically one primary and one secondary, sharing a private body widget. Keep the shared body private: the public wrappers *are* the vocabulary, and a third public fill means a third meaning nobody defined.
- One height constant for bar buttons so a row lines up without each call site guessing at padding.
- Constrain content width (`cardMaxWidth`, `dashboardMaxWidth`) so layouts don't stretch on a tablet.
- Prefer composition over flags: `EmptyStateView`, `TabShell`, `StatStrip` as real widgets rather than one widget with six booleans.

## State and motion

- `ChangeNotifier` + `AnimatedBuilder` unless the project already uses something else. Controllers own `loading` / `error` / staleness; widgets read them. No DI container for a handful of controllers.
- Anything touching a platform channel (location, camera, webview) is **constructor-injected with a default** — `flutter test` has no implementation for those, so this is the only way the path is reachable in a widget test.
- Define one duration and one curve as tokens and use them for transitions. A card-exit or hero gesture may keep its own longer timing; everything else shares the pair.
- Respect the OS reduce-motion setting via `MediaQuery.of(context).disableAnimations` for non-essential motion.

## Accessibility floor

The web floor translates:

| Web rule | Flutter equivalent |
|---|---|
| No horizontal scroll at 360px | No overflow at the narrowest supported phone — assert it in a widget test |
| Visible keyboard focus | `Semantics` labels on every interactive element; icon-only buttons get a label or they are unreadable to a screen reader |
| `prefers-reduced-motion` | `MediaQuery.disableAnimations` |
| Text contrast AA over images | Same — hardest case is muted text over an arbitrary video frame; check it there |

Also: tap targets ≥ 44pt, and layouts must survive a large `textScaler` — long titles at a huge text scale are where a design breaks first.

## Verify before calling it done

```bash
flutter analyze     # must report no issues
flutter test        # must pass
```

Add a widget test asserting **no overflow** across a small phone, a narrow phone and a tablet, plus one long title at a large text scale. That pattern catches what golden tests would, without the maintenance.

Widget tests have no real network: stub the image HTTP stack globally (a fake `HttpClient` answering with a 1×1 transparent PNG) or any widget carrying a network image throws.
