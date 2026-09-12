Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Friends.md](Friends.md), [Group-Dining.md](Group-Dining.md), [Likes-Visits.md](Likes-Visits.md), [Wishlist.md](Wishlist.md), [Profile-Preferences.md](Profile-Preferences.md), [Backend-Schema.md](Backend-Schema.md), [../Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md), [../Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md)

# Plans and the Calendar

Biting a place says you want to eat there. A plan says **when**. This is the
feature that turns a like into a night out, and it is what tab 3 holds now that
the Group Dining placeholder is gone.

Three screens:

- **S4 · Pick a date** (`/plans/new`) — a month, five times, one switch, and a
  summary bar that reads the answer back before you commit it.
- **S6 · Calendar** (tab index 3) — the month you are in, the days that carry
  plans, and the plans themselves listed under day headings.
- **The plan** (`/plans/:id`) — the design draws no screen for this; it draws
  *"they'll get a vote on the time"* on a switch and nowhere to cast one
  (D134). The five chips carry their tallies, the roster says who answered,
  and the owner gets the button that settles it.

Files: `lib/features/plans/models/{plan.dart,plan_slot.dart}`,
`domain/plan_labels.dart`, `data/plans_repository.dart`,
`state/plans_controller.dart`,
`presentation/{plan_calendar.dart,plan_date_page.dart,plan_page.dart,calendar_tab.dart}`,
and — because a plan is a thing about friends — `friends/domain/vote_tally.dart`,
`friends/domain/friend_captions.dart` (`planPeopleLine`, `planHeadcount`),
`friends/presentation/friend_avatar.dart` and `friends/state/friends_controller.dart`,
all of which `calendar_tab.dart` imports. The dev harness is
`lib/dev/calendar_dev_data.dart`.
Screens S4 and S6 in `docs/Redesign/assets/ngap-app-screens.html`.

Migrations: `supabase/migrations/20260906090000_plans_and_plan_members.sql`
and `20260906160100_plan_people_invites_and_votes.sql`.

## 1. What a plan is

**One owner, one restaurant, one date** (D107). That triple is a unique index,
and it is the ON CONFLICT target of `create_plan`, so locking the same place in
on the same day twice moves the time rather than growing a second row. Two
plans on one day at two different places are fine — the calendar lists both.

A plan carries a time, and the time is one of five fixed chips (D110):

| Chip | `plan_time` | `time_label` |
|---|---|---|
| 12:30 | `12:30:00` | null |
| 18:30 | `18:30:00` | null |
| 20:00 | `20:00:00` | null |
| 21:30 | `21:30:00` | null |
| Late | null | `'late'` |

"Late" is a label rather than an hour because *whenever we're done* has no
hour — which is why `plan_time` is nullable. It sorts last within a day, which
is the whole point of the word.

There is no time picker. A plan's time is a thing to agree on with other
people, and four options are agreed on faster than 1 440.

## 2. Planned, kept, cancelled

`plans.status` is `planned`, `kept` or `cancelled`.

**A past plan is a kept plan unless it was cancelled first** (D108). The
calendar records intent, and intent that survived to the day counts. The flip
is server-side, in `mark_plan_kept()`, and the client calls it on every load
before it lists (`PlansController.refresh`). A failed flip is not a failed
load: the calendar is still readable and the next launch fixes the status. The
flip goes first because the list and the stats both read its result; those two
then go out **together** (`(list, stats).wait`, D151) — the refresh is two
round trips, not three.

**Since D147 the assumption gets checked.** It stays an assumption — the flip
happens on load, unprompted — but the next launch after a plan's day asks *did
you go?* through the visit prompt, and "I didn't go" moves that plan to
`cancelled`. One question, about the most recent unrated plan within 14 days,
asked once per app run; see [Likes-Visits.md](Likes-Visits.md) §4. So
`plan_stats`'s "plans kept" is now a number a user can correct rather than one
the app asserts on their behalf.

Cancelling is the only way out. It is confirmed in a **bottom sheet, not a
dialog** — cancelling is a decision about a row on this screen, and a sheet
keeps that row visible behind it.

## 3. Schema

Three tables, all additive.

### `plans`

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` identity | |
| `owner_id` | `uuid` → `profiles(id)` | cascade |
| `restaurant_id` | `bigint` → `restaurants(id)` | cascade |
| `plan_date` | `date` | local date, never a timestamp |
| `plan_time` | `time` | null for "Late" |
| `time_label` | `text` | `check in ('late')` |
| `with_friends` | `boolean` | the "Bring friends" switch |
| `status` | `text` | `check in ('planned','kept','cancelled')` |
| `created_at` / `updated_at` | `timestamptz` | `updated_at` on the shared `touch_updated_at` trigger |

Indexes: `plans_owner_restaurant_date_key` (unique, D107),
`plans_owner_date_idx`, `plans_restaurant_idx`.

`plan_date` is a `date`, not a timestamp, and the client formats it from the
phone's **local** parts (`formatPlanDate`). A phone east of UTC must not post
yesterday.

### `plan_members`

`(plan_id, user_id)` primary key, `status` in `('invited','going','declined')`,
`invited_at`. Indexed on `user_id`.

### `plan_time_votes`

`(plan_id, user_id)` primary key, plus `plan_time` / `time_label` — a member's
vote when "Bring friends" is on. **Live**: `/plans/:id` upserts a member's own
row through `set_plan_vote` and reads the tally back through `get_plan_votes`.
Time voting needed no schema beyond this (D133).

### RLS

Every table has RLS on, every policy is `to authenticated` and keyed
`(select auth.uid())`.

- `plans`: owner has full access; a member can select the plan.
- `plan_members`: the plan's owner inserts and deletes rows; a member selects
  and updates their own row (`own membership select` / `own membership
  update`), **and a member may see the other members** — the `plan members see
  members` policy added by
  `20260906160100_plan_people_invites_and_votes.sql`, scoped by the same
  `is_plan_member` helper so it adds no recursion. Without it a guest opening
  the calendar saw an avatar stack of exactly one face — their own — on a
  dinner with five people at it (D132). The two overlapping `select` policies
  (and the two `update`s) are what the performance advisor flags as
  `multiple_permissive_policies` — the same flag it raises on `plans`'
  `select`. Flagged, not yet addressed; nothing has been decided about
  merging them.
- `plan_time_votes`: members select the plan's votes; each writes only their
  own.

"A member can select the plan" and "a member's row is visible to the plan"
would reference each other and recurse, so membership is answered by a
`security definer` helper instead (D109):

```sql
public.is_plan_member(p_plan_id bigint) returns boolean
  language sql stable security definer set search_path = ''
```

It checks `auth.uid()` inside itself, so it can only ever answer about the
caller. `EXECUTE` is revoked from `public` and `anon`; it **must** stay granted
to `authenticated`, because a policy expression runs with the querying role's
privileges — revoking it makes `select ... from public.plans` fail outright.
The security advisor flags this as
`authenticated_security_definer_function_executable`; the warning is accepted
and the reasoning is written into the migration, next to the same accepted
warning on `get_ngap_count`.

### RPCs

| Function | Returns | Notes |
|---|---|---|
| `create_plan(p_restaurant_id, p_plan_date, p_plan_time, p_time_label, p_with_friends)` | `plans` | Upserts on `(owner_id, restaurant_id, plan_date)`; a cancelled plan comes back as `planned`. |
| `mark_plan_kept(p_today date default current_date)` | `integer` | Flips the caller's past `planned` rows to `kept`. Returns how many. |
| `plan_stats(p_today date default current_date)` | `table(plans_kept int, streak_weeks int)` | The You tab's two figures. |

`p_today` is passed by the client rather than defaulted, so "today" is the
phone's day and not the database server's.

`plan_stats` counts the streak as consecutive ISO weeks, most recent first,
anchored on the most recent past week that has a plan — which may be this week
or the one before it, so the run does not reset at midnight on Sunday. A week
with no plan ends the run, and a run whose last week is older than that counts
zero.

## 4. Client shape

`PlansController.instance` is a `ChangeNotifier` singleton, because four
surfaces ask it the same question and none of them can see the others: the
Calendar tab, the Bites chips, the Bites tiles and the wishlist rows. A
per-screen controller would mean four loads and four chances to disagree.

The clock arrives through the constructor. "Today", "Tonight" and "Fri 4" are
all statements about *now*, and a widget that read `DateTime.now` itself would
be a widget no test could pin down.

It follows auth changes the same way `LikesController` does — it caches one
person's evenings behind an app-lifetime singleton, so a second sign-in on the
same device must drop the cache.

What it publishes:

| Getter | Used by |
|---|---|
| `plannedRestaurantIds` | the Bites chips, via `LikesController.setPlannedRestaurantIds` |
| `plannedLabelFor(id)` / `plannedLabels` | tile and wishlist-row badges |
| `plansOn(date)`, `plannedDaysIn(month)` | the calendar grid |
| `upcoming` | the Calendar tab's sections |
| `stats` | the You tab's "plans kept" and "week streak" |

**Upcoming only.** A dinner that has already happened is a visit, not a plan; a
tile still saying "Planned" a week later would be lying.

The badge wording, from `plan_labels.dart`:

| When | Label |
|---|---|
| today, before 18:00 | `Today` |
| today, 18:00 or later, or "Late" | `Tonight` |
| this month | `Fri 4` |
| a later month | `Sat 10 Oct` |

The *soonest* plan wins when a place has more than one, because the badge
answers "when am I next going", not "how many times have I booked this".

## 5. Pick a date (S4)

Pushed from a restaurant's "Set a date" with the restaurant attached, so the
screen draws its title and its thumbnail with no fetch:

```dart
context.push('/plans/new', extra: <String, dynamic>{
  'restaurantId': int, 'title': String,
  'coverUrl': String?, 'neighbourhood': String?, 'tag': String?,
});
```

`PlanDraft.fromPayload` parses it the same defensive way `/restaurant/:id`
parses its own. A link, a restored route or a caller with less than the tap had
gets a screen ("Pick a place first, then a day.") rather than a crash.

What it asks, top to bottom: **"When are we going?"** · the month grid · **Time**
· **Bring friends**. Then the `.picked` bar reads the whole answer back —
`pickedSummary`, "Fri 4 Sep · 20:00", over
"`<short name>` · `With friends`" or "`<short name>` · `Just you`" depending on
the switch — and commits it.

- Past days are drawn muted and are not tappable, and their semantics node
  carries no tap action.
- Today is a cream disc with an ember dot under it, and is still choosable.
- A day that already has a plan wears an ember ring with that plan's cover
  inside it.
- **"Lock it in" stays disabled until a day is chosen.** A day is the one thing
  the screen cannot supply a sensible default for, and the design has no count
  to put in the label, so the button simply waits.
- There is **no arrow back** past the month you are standing in. It is absent
  rather than dead: an arrow that is always there and only sometimes works is a
  worse answer than one that is not there.

After a successful save the screen lands on the Calendar tab — and when "Bring
friends" was left on it then pushes **`/plans/:id/invite`** on top of it. The
calendar first, always: the plan is saved by then, so it is where the screen
belongs whatever happens next, and it gives the invite screen somewhere to pop
back to. Skip and Send both land on the plan that was just made. See
[Friends.md](Friends.md).

## 6. The Calendar tab (S6)

Replaces `GroupTab` at nav index 3. The tab lives under `features/plans` rather
than under `features/dashboard` because it is the plans feature's screen; the
dashboard only decides where to hang it.

- **Topbar**: "Calendar", a search button, and a "New plan" button that asks
  the dashboard for tab 0 (`DashboardTabRequest`). Search is a real inline
  filter over plan names, not a placeholder.
- **Month grid**: `PlanCalendarHeader` over `PlanCalendar`, drawn straight on
  the page at the screen padding — *exactly* as S4's date picker draws them
  (D123). It used to sit inside a `SimpleCard`, and that card's border and
  padding narrowed the columns enough that the same widget read as a
  different calendar on the two screens the user moves between. The header
  carries the picker's month arrows — `Previous month` and `Next month`, each
  a `_MonthArrow` whose `Semantics` is a `container: true` so a screen reader
  hears "September 2026 Next month" as one node — and the "This month ▾" chip
  with its six-month bottom sheet is gone. `Previous month` is **absent**
  rather than dead on the current month, since the tab lists from today
  forward. A planned day wears the ring and its cover.
- **The pips under a day** count people, not plans alone: one **ember** pip
  per plan of the user's own (`PlanDayMark.planCount`) then one **cream**
  (`kCreamMuted`) pip per **unique friend still coming** that day
  (`friendCount` — the set of `member.userId` across the day's plans, with
  `status == 'declined'` left out, so somebody on two of Saturday's dinners is
  one face's worth of pip, not two), the two capped at **three between them**
  — past three the pips stop being countable and the section list below is the
  honest answer. Today's ember dot is drawn only when the day has **no** pips,
  so the dot never has to compete with them for the same slot.
- **Declined is one rule, everywhere.** A guest who said no appears in neither
  the day's cream pips nor the row's avatar stack, and `planHeadcount` skips
  them too: it counts a guest for every status that is *not* `declined`, and a
  confirmed for every `going`. So a plan with three invitations, one accepted
  and one declined, is one cream pip, one face, and "2 friends · 1 confirmed".
  Counting a refusal would make a plan look fuller the more it emptied.
- **Sections**: "Today · 2 plans", "Fri 4 · 1 plan", … each row a `.plan` card
  — 48 px logo (cover, or two initials from the name), the restaurant's name,
  the people line under it, and the time pill on the right. The design's three
  plan cards disagree about that second line — one of them draws faces beside
  "Lunch · Kepong · 6 km" — and the app picks one rule for all three: who is
  coming leads, always. `planMealLabel` still exists and still delegates to the
  deck's `mealLabel`, so nothing here can disagree with the deck about when
  dinner starts.
- **The row itself** is a `Material` on `kGlass` with a `kHairline` side, at
  `kRadiusPanel`. On the subtitle line, ahead of the text, sits a
  `FriendAvatarStack` at `kAvatarSizeCompact` — the plan's roster from
  `FriendsController.peopleFor(plan.id)`, with anyone who declined left out,
  because a face on a dinner they turned down is a lie about who is going.
- **The subtitle leads with who is coming** — `planPeopleLine` over
  `planHeadcount(plan.members.map(status))` — then the neighbourhood, then the
  distance, joined with ` · ` and each part dropped rather than guessed when
  it is unknown: `Just you · Kepong · 8.7 km`, `3 friends · 2 confirmed ·
  Kampung Baru`. A guest who declined is not counted; "confirmed" is dropped
  entirely while nobody has answered, because "3 friends · 0 confirmed" reads
  as a failure and "3 friends" reads as an unanswered invitation, which is
  what it is. The distance comes from `distanceLabelFrom` with its " away"
  trimmed, and is left off when no real fix has landed.
- Tap a row to open the plan (`/plans/:id`); long-press to cancel. The row
  used to open the restaurant, which was the only thing a plan had to show
  before it had guests — the restaurant is now one tap further in, from the
  plan's own header.
- Empty: "No plans yet / Bite something, then pick a day." with **Start
  swiping**. The month grid stays — an empty calendar is still a calendar.

## 6a. The plan (`/plans/:id`)

Reached by tapping a plan on the Calendar. Everything on it is read through the
controllers the rest of the app already shares — `PlansController.planById` for
the plan, `FriendsController` for the roster and the tally — so opening it
costs one `get_plan_votes` and one `get_plan_people`.

- **The header** is the place, its cuisine and neighbourhood, and a chevron
  through to `/restaurant/:id`.
- **The chips** are `PlanSlot.all`, the same five the plan was made with, each
  carrying its own count once there is one — `20:00 · 2`, never `20:00 · 0`, on
  the grounds that a row of five zeroes reads as a screen full of failures. A
  screen reader hears `"20:00, 2 votes"` instead, because `·` is read as a date
  by some of them and the plural has to be right either way.
- **Tapping a chip** casts or moves your own vote through `set_plan_vote`, then
  re-reads the tally. Re-read rather than patched: the server *replaces* your
  previous row, and a client that appended would show you voting twice the
  first time you changed your mind.
- **The lines under the chips** say which slot leads and how many people have
  not answered. A tie has no leader — the line says "most votes" and a tie has
  no most, and breaking it by position would put a thumb on 12:30 for no reason
  anybody could see. The owner is not a `plan_members` row (D107), so they are
  counted into "still to vote" by hand.
- **Settling it** is the owner copying the winning slot onto the plan with
  `PlansRepository.setTime` — the vote speaks the same vocabulary as the thing
  it votes on (D110), so locking is a copy rather than a translation. The
  button is absent when there is nothing to settle: no votes, a tie, or a plan
  already at the winning time.
- **A guest** gets **Going** / **Can't** instead, through `answer_plan_invite`.
  The screen tells owner from guest by looking for its own id in the plan's
  members: RLS only ever hands it a plan you own or belong to, so "not a
  member" and "owner" are the same answer.

## 7. The dev harness

`--dart-define=USE_DEV_PLANS=true` swaps `DevPlansRepository`
(`lib/dev/calendar_dev_data.dart`) in for the real one at startup in
`main.dart`, with `followAuthChanges: false`, and points the tab's position
resolver at `devUserPosition` (3.1390, 101.6869 — Kuala Lumpur) so the
distances come out the way the prototype's do. It answers `list()` with three
September-2026 plans:

| Plan | Date · time | Where | Members |
|---|---|---|---|
| Chili Pan Mee 88 | 2 Sep · 12:30 | Kepong | two invited |
| Bakar & Bara Satay | 2 Sep · 20:30 | Kajang | none — "Just you" |
| Warung Kak Ros | 4 Sep · 20:00 | Kampung Baru | two going, one invited |

`stats()` answers `PlanStats(plansKept: 27, streakWeeks: 6)`, and every write —
`create`, `cancel`, `setTime`, `markKept` — is a no-op that returns a plausible
value. The restaurants and the friends are fictional and the covers are the
prototype's own Unsplash stills. **Nothing reaches the database**, which is the
point: it is a way to look at S6 with a full month on it, not a seed.

## 7a. Data-empty today

- Nothing outstanding. Cream pips for other people's plans were the last gap
  here, and the Friends phase closed it: `get_plan_people` puts a roster on
  each plan, so `friendCount` is real.

## 8. Out of scope

- Reminders or notifications. A calendar you have to open is still a calendar.
- Syncing to the phone's own calendar.
- A plan for a place that is not in the catalogue — that is what the wishlist
  is for.
- Editing the date. Cancel and pick again; a plan is cheap.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D123 | The Calendar tab draws its month grid the way the date picker does: `PlanCalendarHeader` + `PlanCalendar` on the page, at the screen padding, with the picker's month arrows. The `SimpleCard` wrapper and the "This month ▾" chip's six-month bottom sheet are removed. One grid used on two screens has to *look* like one grid — the card's border and padding narrowed the columns, and the day discs drew as ellipses on a 320 pt phone while the picker's drew as circles. Arrows also beat a sheet for a tab that only ever looks a few months ahead. | locked 2026-09-10 |
| D107 | A plan is one owner, one restaurant, one date. The triple is a unique index and the ON CONFLICT target of `create_plan`, so locking the same place in twice on one day moves the time instead of creating a second row. | locked 2026-09-06 |
| D108 | A past plan is a kept plan unless it was cancelled first. `mark_plan_kept()` flips it server-side on load; there is no "did you go?" prompt, because the calendar records intent and intent that survived to the day counts. | locked 2026-09-06 |
| D109 | Membership is answered by a `security definer` helper, `public.is_plan_member(bigint)`, rather than by policies that reference each other's tables and recurse. `EXECUTE` stays granted to `authenticated` because a policy expression runs with the querying role's privileges; the advisor warning that follows is accepted and explained in the migration. | locked 2026-09-06 |
| D134 | Voting gets a screen the design does not draw. "They'll get a vote on the time" is written on S4's switch and no S-numbered screen ever collects one, so `/plans/:id` is invented rather than derived — the smallest surface that makes the switch's promise true. It takes the Calendar card's tap and hands the restaurant back from its own header, so the plan does not need a second affordance nobody would find. | locked 2026-09-09 |
| D132 | A plan member may see the other members, through a policy scoped by `is_plan_member` — the same definer helper the rest of the plan policies lean on, so it adds no recursion. | locked 2026-09-06 |
| D133 | Time voting needs no new schema. A member upserts their own `plan_time_votes` row under the policies Phase 7 already wrote, the tally is a group-by the client does over rows it may read, and locking a time is the owner updating `plans.plan_time` through `PlansRepository.setTime`. The only thing missing was a read that could put a name next to a vote, which is what `get_plan_votes` is. | locked 2026-09-06 |
| D147 | The visit prompt asks about a past plan, and "I didn't go" corrects D108's assumed `kept` to `cancelled`. | locked 2026-09-11 |
| D110 | A plan's time is one of five fixed chips — 12:30, 18:30, 20:00, 21:30, Late — not a time picker. "Late" is a label with no hour, which is why `plan_time` is nullable, and it sorts last within a day. | locked 2026-09-06 |
