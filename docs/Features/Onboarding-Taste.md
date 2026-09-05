Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [Auth.md](Auth.md), [Swipe-Deck.md](Swipe-Deck.md), [Profile-Preferences.md](Profile-Preferences.md), [Backend-Schema.md](Backend-Schema.md)

# Onboarding & the Taste Signal

> **Changed 2026-09-04.** The wizard is **five steps**, not four: a gesture
> primer ("Three moves") closes it, and the final button reads **"Show me
> dinner"** (D90). It teaches Ngap! / Skip / Later — the words the deck's three
> controls use — before the user meets a card that expects them. Taste chips no
> longer carry emoji (D88).
>
> **Changed 2026-09-05.** **Six steps.** "Any rules?" (design 01e) now sits
> between Taste and Habits, and the topbar is the design's: a 44 px round back
> button, a three-state `.steps` bar, and a **Skip** on this one step. Continue
> is a single block button in the foot. **Friends (01f) is the only design step
> still missing** — it is the one that needs a social graph rather than a
> column.

The six-step wizard every account walks **exactly once**. It exists to solve
one problem: a deck ranked on nothing is a random deck, and the first session
is the one that decides whether there is a second.

Files: `lib/features/onboarding/presentation/onboarding_page.dart`,
`onboarding_steps.dart`, `models/onboarding_draft.dart`, `models/taste_option.dart`,
`data/onboarding_repository.dart`.

## 1. The gate

`profiles.onboarded_at` is null for a fresh account. `AuthController` exposes
that, and `app_router.dart` redirects to `/onboarding` until it is stamped.

**Nothing is written until "Finish".** The draft (`OnboardingDraft`) lives in
memory, so quitting mid-wizard leaves `onboarded_at` null and the router simply
shows the wizard again next launch — rather than stranding a half-configured
account that is neither new nor ready.

The seeded demo account (`demo@swipeeat.test`) has a deliberately null
`onboarded_at`, so signing in as demo walks the wizard once and exercises this
path.

## 2. The six steps

| # | Step | Collects | Required? |
|---|---|---|---|
| 1 | You | `name` | Yes |
| 2 | Taste | `cuisineIds`, `dietaryIds` | Yes |
| 3 | **Any rules?** | `halal_only`, `vegetarian`, `spice_level`, `budget_min` / `budget_max` | No — and **skippable**, which is not the same thing |
| 4 | Habits | `morning_mode`, `spice_bias`, `nearby_focus`, `radius_km` | No — every tile has a valid default |
| 5 | Location | A fix, or an explicit refusal | No — refusal is a valid answer |
| 6 | Three moves | Nothing — it teaches the gestures | No |

`_stepCount = 6`. The final button reads **"Show me dinner"** (D90).

`_canAdvance` gates only steps 1 and 2; everything after is always satisfiable
because the rules, the tiles and the location itself all have valid defaults.
Back navigation never lands the user on a step the Continue button had refused.

### The topbar

Back is a 44 px `kGlass` round icon button, replaced by a 44 px spacer on step
1 so the progress bar never shifts. The bar is the design's `.steps`: 3 px
segments with 5 px gaps, **ember** for the current step, muted cream for the
ones behind, hairline for the ones ahead. The right slot holds the `.textbtn`
Skip on step 3 and a spacer everywhere else.

### Step 3 — "Any rules?", and why Skip clears rather than passes

This is the only step whose answers **hide** restaurants instead of reordering
them, which is why it carries a reason under the heading ("So we never show you
somewhere you can't eat.") and a Skip beside the bar.

The budget range opens on RM 10–40, as the prototype shows it. That creates a
trap: skipping a step that is already showing a range would silently cap a
stranger's deck at RM 40. So **Skip clears every rule first** — the switches go
off, the spice level goes null, and the budget goes to "no answer"
(`p_clear_budget: true`) — and only then advances. Continue commits what is on
screen. Spice starts with **nothing** selected, because "unanswered" and "Mild"
are different things.

The upper thumb parked at RM 100 means *no ceiling*, not RM 100: the read-out
says "RM 10+" and `budget_max` is written null. Hiding the handful of places
that cost more from someone who just said money is not the issue would be the
opposite of what they answered.

### Step 2 — the cold-start taste signal

The point of the whole wizard. Cuisine and dietary chips write to
`profile_cuisines` and `profile_dietary_tags`, and `deck_scored` weights the
deck by them from the very first card.

Cuisines carry `is_breakfast` and `spice_level`, which is what lets step 3's
switches mean something: `morning_mode` and `spice_bias` are applied *through*
the cuisine taxonomy rather than against a column on `restaurants`.

Dietary tags are a **filter**, not a weight — 6 of them, and "halal" is not a
preference to be outweighed by proximity.

### Step 4 — "Not now" is an answer, not an escape

Declining location records `location_source = 'denied'` and **finishes the
wizard**. Two reasons:

- The ranking stops waiting for a fix it will never get and falls back to the
  stored/absent-location path.
- The user is not left on a step with nothing left to do — a dead end that
  reads as a bug.

An accepted fix is stored on the profile (`last_latitude`, `last_longitude`,
`last_place_name`, `located_at`, `location_source`), which is what lets a user
who later revokes permission still get a sensible deck.

The location resolver is injected so widget tests can drive the step without
the geolocator platform channel, which has no implementation under
`flutter test`.

## 3. The write

One call: `complete_onboarding(p_name, p_cuisine_ids, p_dietary_ids,
p_morning_mode, p_spice_bias, p_nearby_focus, p_radius_km, p_latitude,
p_longitude, p_place_name, p_location_source, p_halal_only, p_vegetarian,
p_spice_level, p_budget_min, p_budget_max, p_clear_budget) → profiles`.

Seventeen parameters in one transaction, returning the whole profile row — so a
partial wizard can never half-commit, and the client refreshes its cached
profile from the write's own response instead of a follow-up read (D11).

Everything the wizard sets is editable afterwards from Profile, except that
`onboarded_at` is never unset. See
[Profile-Preferences.md](Profile-Preferences.md).

## 4. Known gaps

- **`filter_min_rating` is not offered**, correctly — with 2 rated rows it
  would be a filter that empties the deck. The column exists for when ratings
  do.
- No way to re-run the wizard deliberately. Everything inside it is editable
  from Profile, so this is a convenience rather than a gap.
- Step 2 has no "surprise me" / skip-taste path; a user with no strong
  preference has to pick something.

## 5. Out of scope

- **A second onboarding pass** for returning users after a long absence.
- **Progressive onboarding** — asking for taste after a few swipes instead of
  before. Worth testing, but the deck needs a signal on card one.

## 6. Decision log

| ID | Decision | Status |
|---|---|---|
| D29 | Nothing is written until Finish; a quit mid-wizard re-shows the wizard rather than half-configuring an account. | locked 2026-08-23 |
| D30 | Declining location records `denied` and completes the wizard — a refusal is an answer, not an escape. | locked 2026-08-23 |
| D31 | Dietary tags filter; cuisines weight. "Halal" must not be outweighed by proximity. | locked 2026-08-23 |
| D32 | `morning_mode` and `spice_bias` apply through the cuisine taxonomy (`is_breakfast`, `spice_level`), not through columns on `restaurants`. | locked 2026-08-23 |
| D11 | `complete_onboarding` returns the whole `profiles` row. | locked 2026-08-23 |
| D104 | Step 3 asks four spice steps; `spice_level` stores them and `spice_bias` is derived, so the deck's existing term is untouched. | locked 2026-09-05 |
| D105 | Step 3's answers are hard deck filters, which is why the step explains itself and why Skip clears rather than passes the defaults through. | locked 2026-09-05 |
