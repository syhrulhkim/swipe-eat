Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [README.md](README.md), [NGAP-DESIGN-SYSTEM.md](NGAP-DESIGN-SYSTEM.md), [GAP-ANALYSIS.md](GAP-ANALYSIS.md)

# Screens (target)

All 16 screens in [assets/ngap-app-screens.html](assets/ngap-app-screens.html),
in prototype order. Screen ids are the prototype's own `data-screen` values.

**Legend** — 🆕 nothing like it exists today · ♻️ exists but changes ·
✅ exists and roughly survives

| # | id | Screen | |
|---|---|---|---|
| 01a | `onboarding` | Welcome | ♻️ |
| 01b | `signup` | Sign up | ♻️ |
| 01c | `location` | Location | ♻️ |
| 01d | `taste` | Taste | ♻️ |
| 01e | `diet` | Diet & budget | 🆕 |
| 01f | `friends` | Friends | 🆕 |
| 01g | `howto` | How to swipe | 🆕 |
| 02 | `swipe` | Swipe · home | ♻️ |
| 03 | `detail` | Restaurant | ♻️ |
| 04 | `date` | Pick a date | 🆕 |
| 05 | `invite` | Invite friends | 🆕 |
| 06 | `calendar` | Calendar · your plans | 🆕 |
| 07 | `likes` | Your bites | ♻️ |
| 08 | `wishlist` | Wishlist | 🆕 |
| 09 | `nearby` | Nearby (map) | 🆕 |
| 10 | `profile` | You | ♻️ |

---

## First run — seven screens, six steps

A thin progress bar of six dots: **ember = current, cream = done**. The Welcome
screen sits before the bar.

### 01a · Welcome ♻️

- Wordmark **"Ngap."**
- A three-card deck preview, the middle card carrying **the bite** notch, the
  third showing a `0:12` duration tag.
- Hero: *"Where to eat? **Swipe it.**"*
- Body: *"Fifteen seconds of video per restaurant. Bite the ones you want, pick
  a day, bring whoever's hungry."*
- Primary **Start swiping** → `signup`; ghost **I already have an account** →
  straight to `swipe`.
- Fineprint: *"Uses your location to find places nearby"*.

### 01b · Sign up ♻️ — **auth changes**

- Top bar: wordmark + a **Later** text button that skips the whole flow.
- Hero video with caption *"Save your bites across phones / Your likes, plans
  and wishlist follow you."*
- Three buttons, in this order:
  1. **Continue with phone number** (primary) — 🆕 no phone auth today
  2. Continue with Apple (ghost)
  3. Continue with Google (ghost)
- Legal line: *"By continuing you agree to the Terms and Privacy Policy. We
  never post without asking."*

**Email/password is gone from the design.** Phone is the primary path and does
not exist in the app today.

### 01c · Location — step 1/6 ♻️

- *"Where are you eating?"*
- Lede: *"Ngap only shows places you can actually get to tonight. We use your
  location while the app is open, nothing more."*
- A visual: concentric rings, a "me" dot, four **photo pips** for nearby
  places, and a label **"38 places open within 3 km"** — needs opening hours.
- **Allow location** (primary) / **Type an area instead** (ghost) — the second
  is 🆕; today refusal is a plain "Not now".

### 01d · Taste — step 2/6 ♻️ — **photo tiles, not emoji**

- *"What do you crave?"* / *"Bite at least two. Your first swipes come from
  these."*
- A scrolling grid of **12 photo tiles**, each a label plus a small
  descriptor, with a check overlay when pressed:

  | Tile | Descriptor |
  |---|---|
  | Nasi lemak | the morning kind |
  | Mamak | roti & teh tarik |
  | Satay | over charcoal |
  | Pan mee | dry, with chili |
  | Banana leaf | Brickfields style |
  | Kopitiam | toast & kopi |
  | Char kuey teow | wok hei |
  | Desserts | cendol & more |
  | Seafood | sambal, grilled |
  | Nasi kandar | flooded |
  | Hawker nights | pasar malam |
  | Bak kut teh | Klang-style |

- A secondary **"Also into"** text-chip row: Japanese, Thai, Korean, Western,
  Cafés, Middle Eastern, Vegetarian.
- A sticky footer showing the count and the picked names, then **Continue**.
- **Minimum 2**, and the CTA must be disabled below it with the shortfall in
  the label ("Pick 1 more").
- A **Skip** text button in the top bar — despite the minimum.

The two-tier structure (photo tiles for the hero cravings, text chips for the
rest) is the design's answer to "no emoji": a category without a photo is a
chip, never an emoji.

### 01e · Diet & budget — step 3/6 🆕

- *"Any rules?"* / *"So we never show you somewhere you can't eat."*
- **Halal only** switch — *"Hides places without halal certification"*
- **Vegetarian options** switch — *"Must have a real veg section"*
- **Spice** — a 4-way segmented control: Mild · Medium · **Pedas** · Bring it
- **Budget per person** — a range slider, RM 5 → RM 100+, step 5, with a live
  output (`RM 10–40`)
- **Continue**, plus a **Skip**.

Everything on this screen is new. Today's spice is a 3-value `spice_bias`; there
is no budget and no halal flag.

### 01f · Friends — step 4/6 🆕

- *"Eat with people"* / *"Six of your contacts are already on Ngap. Add them and
  you can plan a dinner in two taps. Optional, always."*
- A list of six people: portrait avatar (initials until loaded), name, and a
  context line — *"142 bites · Bangsar"*, *"Ngap'd 3 of your picks"*,
  *"Kampung Baru"*, *"Vegetarian"*.
- CTA counts the selection: **Add 3 friends**.
- Footnote: *"We don't upload your contacts. Matching happens on your phone."*
- **Skip**.

On-device contact matching is a privacy promise the implementation has to keep
literally.

### 01g · How to swipe — step 5/6 🆕

- *"Three moves"* / *"Every card is a 15-second video from the restaurant.
  Watch, then flick."*
- A diagram of the three gestures around a mini card:

  | Gesture | Label | Sub |
  |---|---|---|
  | → right | **Ngap!** | I want this |
  | ← left | **Skip** | not tonight |
  | ↑ up | **Later** | save without deciding |

- CTA **Show me dinner** → `swipe`.
- Footnote: *"Bitten places land in Your bites. Set a date from there."*

**Up is no longer a super like.** It is "save for later" and it feeds the
wishlist. There is no super like anywhere in the new design.

The progress bar shows 5 of 6 here; the sixth step is not a separate screen in
the prototype.

---

## 02 · Swipe · home ♻️

- Top bar: a location block — **"Bangsar, KL"** with sub-line
  *"within 3 km · dinner"* — and a filters icon button.
- The card deck. Cards carry the video, the name, a duration tag, and **the
  bite** notch once saved. Stamps read **"Ngap!"** and **"Skip"**.
- A three-button action bar, in this order:

  | Button | Gesture | Style |
  |---|---|---|
  | ✕ Skip | left | icon, ghost |
  | **Ngap!** | right | wide ember pill, **labelled with the word** |
  | ⏱ Later | up | icon, ghost |

- Bottom nav.

Gesture thresholds in the prototype are unchanged from today: `dx > 110`,
`dx < -110`, `dy < -140`.

Note the action bar is **three** buttons where today's is two (Pass/Like) plus
a rewind affordance. **There is no rewind in the new design** — nor a daily
limit, nor a streak on this screen.

## 03 · Restaurant detail ♻️

Video hero, full-bleed, with a `0:14 · tap to unmute` tag — so **video starts
muted**, unlike today's autoplay-unmute.

- Top bar over the hero: Back, **Add to wishlist** (a bookmark glyph), Share.
- Title block over a scrim: chips **Nasi lemak** / **Halal**, then
  *"Warung Kak Ros"*, then *"Kampung Baru · 1.2 km · open till 2 am"*.
- **Facts strip**, three columns:

  | | |
  |---|---|
  | **RM 8–15** | per person |
  | **4.7** | 1,204 **ngaps** |
  | **~10 min** | wait, evenings |

- **"What people bite"** — a dish list, each with thumbnail, name, description
  and price:
  - Nasi lemak ayam berempah · *Coconut rice, spiced fried chicken, sambal* · **RM 12**
  - Sambal sotong · *Squid in sweet-hot sambal* · **RM 15**
  - Teh tarik · *Pulled, frothy, very sweet* · **RM 3**
- A friends row — an avatar stack of friends who also ngap'd it.
- Sticky CTA: a ghost **directions** icon button + primary **Set a date**.

Four of those are new data: price range, ngap count, wait time, and dishes.
Reviews — today's carousel — **do not appear on this screen at all**; dishes
replace them.

## 04 · Pick a date 🆕

- *"When are we going?"*, restaurant name in the top bar.
- A month calendar with prev/next arrows, one day selectable.
- **Time** — chips: 12:30 · 18:30 · **20:00** · 21:30 · **Late**.
- A glass row: **Bring friends** switch — *"Optional — they'll get a vote on
  the time"*.
- A pinned summary at the bottom: thumbnail, **"Fri 4 Sep · 20:00"**,
  *"Kak Ros · 3 friends"*, and a light **Lock it in** button.

"They'll get a vote on the time" implies guests can propose or approve times —
a real feature, not just an invite.

## 05 · Invite friends 🆕

- *"Who's hungry?"*, with the plan's date/time in the top bar and a **Skip**.
- A friend search field.
- Section **"Ate with recently"**, then the person list with genuinely useful
  context lines:
  - *"Ngap'd Kak Ros too"*
  - *"Free Friday evening"*
  - *"Lives 400 m from there"*
  - *"Vegetarian — warn her about the sambal"*
  - *"Last ate together in July"*
- Footer: **3 selected** + primary **Send invites**.

Those context lines each need a different join — likes overlap, availability,
friend home location, friend dietary tags, shared plan history. They are the
most data-hungry strings in the whole design.

## 06 · Calendar · your plans 🆕

- Title **Calendar**, with search and **New plan** (+) icon buttons.
- A glass card holding a month grid with a **"This month ▾"** filter. Days with
  plans are marked; the design calls for **photography on the calendar day**.
- Grouped plan lists — **"Today · 2 plans"**, **"Fri 4 · 1 plan"** — each plan
  a glass card:
  - A photo **logo** with initials fallback (`88`, `BB`, `KR`)
  - Name, then a sub-line that is either a friend avatar stack or
    *"Just you · Kajang · 22 km"*
  - The time, right-aligned (`20:30`)
- Bottom nav, this tab current.

This tab replaces Group entirely. Group dining is not a separate surface in the
new design — it is woven through plans and invites.

## 07 · Your bites ♻️

- Title **"Your bites"** + **"14 saved"**.
- Filter chips: **All** · Not planned yet · Planned · **Wishlist →** · Halal.
  The wishlist chip is navigation, not a filter.
- A two-column photo tile grid. Tiles carry:
  - **the bite** notch (all of them — everything here is saved)
  - a **planned** badge showing the date (`Fri 4`, `Today`)
  - a small **wish** bookmark glyph when it is also wishlisted
  - name + *"cuisine · neighbourhood"*

Today's three segments (Liked / Visited / Reviewed) become **planned-state
filters**. Visited and Reviewed have no equivalent here; the wishlist's "eaten"
state is the nearest thing to Visited.

## 08 · Wishlist 🆕

Reached from Bites; keeps the Bites tab current.

- *"Places to try"*, with counts: **6 to go**, **3 eaten**.
- A free-text **"Add a place…"** field with an add button — so a wishlist entry
  need not be a catalogue restaurant.
- A checklist. Each row: checkbox, thumbnail, name, *"cuisine · area"*
  (sometimes *"· open 24 h"*).
- Separator hint: *"Tap a place once you've eaten there"*.
- Footer: *"Eaten ones sink to the bottom"* + **Clear eaten**.

Behaviour the brand reference pins down precisely:

> Wishlist is a plain checklist under Bites: tap to cross off (ember
> strike-through, photo desaturates, eaten rows sink to the bottom). **No
> confetti, no modal.**

## 09 · Nearby (map) 🆕

Replaces the cuisine grid entirely.

- A full-screen map (street grid stands in for real tiles).
- Back and a **filters** button with an active-count dot (`2`).
- A "me" marker.
- **Photo blobs** for each place — a circular video/photo thumb with a distance
  label, the name and cuisine beneath, and a state line:
  - **Open** (in `--fresh`)
  - **Open · 24 h**
  - *"Closes …"* in muted cream
  - Two blobs are `big` (nearer/more relevant); one carries **the bite**.
- A **radius stepper** — −/+ around *"Away from you"* **3.4 km**.
- A results bar: **From RM 8** · **Open now 6** · **Swipe all 6** (light
  button, hands the filtered set back to the deck).

"Swipe all 6" is a genuinely new interaction: the map is a filter that seeds the
deck.

## 10 · You ♻️

- Title **"You"** + a notifications button with a badge.
- Identity row: portrait avatar, **"Hana Abdullah"**, *"Bangsar · eating out
  since Mar 2026"*.
- Three glass stat cards: **142 bites** · **27 plans kept** ·
  **6 wk eating-out streak**.
- **"Your taste"** — a settings list, each row a value plus a chevron:

  | Row | Value |
  |---|---|
  | Halal only | On |
  | Spice | a 5-pip meter, 4 lit |
  | Budget per person | RM 10–40 |
  | Default radius | 3 km |
  | **Videos autoplay** | **Wi-Fi only** |

- Two ghost buttons: **Friends · 38** and **Settings**.

New here: plans-kept and streak-in-weeks stats, the 5-pip spice meter (today's
`spice_bias` has 3 values, the diet screen has 4 segments — **three different
scales for one field**), a friend count, and an autoplay preference. Passport
does not appear anywhere in the new design.

## Cross-screen patterns

| Pattern | Where |
|---|---|
| Radial ember glow at the top | Every screen |
| Status bar, Dynamic Island notch, home bar | Every screen (prototype chrome) |
| Photo + initials fallback | Friends, plan logos |
| Photo, never emoji | Taste tiles, map blobs, calendar days, plan logos |
| Opening-hours state | Location, detail, wishlist, map, results bar |
| RM price | Diet, detail facts, dishes, map results, profile |
| **The bite** notch | Welcome preview, swipe card, Bites tiles, map blob |
| Halal badge / filter | Diet, detail chips, Bites filters, profile |
| "Skip" on every onboarding step | 01d, 01e, 01f (and "Later" on 01b) |

## Screens with no target design

Built surfaces the new design says nothing about. Each needs a decision:

- **Settings** — reachable from You, but never drawn. It holds sign-out,
  account deletion and the legal links, all store-mandated.
- **Cuisine list page** (`/explore/cuisine/:id`) — no equivalent once Explore
  becomes a map.
- **Visit prompt sheet** — the "did you go?" loop. The wishlist's eaten state
  is adjacent but not the same thing.
- **Passport** — absent from the new design.
- **Rewind, daily limit, streak-on-deck, super like** — all absent.
- **Review carousel** — replaced by dishes on the detail screen.
