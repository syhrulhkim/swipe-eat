Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-06
Cross-references: [Group-Dining.md](Group-Dining.md), [Likes-Visits.md](Likes-Visits.md), [Wishlist.md](Wishlist.md), [Profile-Preferences.md](Profile-Preferences.md), [Backend-Schema.md](Backend-Schema.md), [../Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md), [../Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md)

# Plans and the Calendar

Biting a place says you want to eat there. A plan says **when**. This is the
feature that turns a like into a night out, and it is what tab 3 holds now that
the Group Dining placeholder is gone.

Two screens:

- **S4 · Pick a date** (`/plans/new`) — a month, five times, one switch, and a
  summary bar that reads the answer back before you commit it.
- **S6 · Calendar** (tab index 3) — the month you are in, the days that carry
  plans, and the plans themselves listed under day headings.

Files: `lib/features/plans/models/{plan.dart,plan_slot.dart}`,
`domain/plan_labels.dart`, `data/plans_repository.dart`,
`state/plans_controller.dart`,
`presentation/{plan_calendar.dart,plan_date_page.dart,calendar_tab.dart}`.
Screens S4 and S6 in `docs/Redesign/assets/ngap-app-screens.html`.

Migration: `supabase/migrations/20260906090000_plans_and_plan_members.sql`.

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

**A past plan is a kept plan unless it was cancelled first** (D108). There is
no "did you go?" prompt anywhere. The calendar records intent, and intent that
survived to the day counts — asking again a day later gets a worse answer than
not asking. The flip is server-side, in `mark_plan_kept()`, and the client
calls it on every load before it lists (`PlansController.refresh`). A failed
flip is not a failed load: the calendar is still readable and the next launch
fixes the status.

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
vote when "Bring friends" is on. Written by the Friends phase; the table exists
now so the invite flow lands against a schema rather than beside one.

### RLS

Every table has RLS on, every policy is `to authenticated` and keyed
`(select auth.uid())`.

- `plans`: owner has full access; a member can select the plan.
- `plan_members`: the plan's owner inserts and deletes rows; a member selects
  and updates their own row.
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
"Fri 4 Sep · 20:00" over "Kak Ros · Just you" — and commits it.

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

After a successful save the screen lands on the Calendar tab. When "Bring
friends" was on it also says **"Invites arrive with Friends"** — `/plans/:id/invite`
belongs to the Friends phase, the plan is already saved, and saying so plainly
beats pushing a route that would 404.

## 6. The Calendar tab (S6)

Replaces `GroupTab` at nav index 3. The tab lives under `features/plans` rather
than under `features/dashboard` because it is the plans feature's screen; the
dashboard only decides where to hang it.

- **Topbar**: "Calendar", a search button, and a "New plan" button that asks
  the dashboard for tab 0 (`DashboardTabRequest`). Search is a real inline
  filter over plan names, not a placeholder.
- **Month card**: the grid, with a "This month" chip — the label only, no
  caret glyph — that opens a bottom sheet of the next six months. A planned day wears the ring and its cover;
  more than one plan on a day adds pips underneath.
- **Sections**: "Today · 2 plans", "Fri 4 · 1 plan", … each row a `.plan` card
  — 48 px logo (cover, or two initials from the name), name, and a detail line
  reading "Lunch · Kepong · 6 km". The meal comes from the deck's own
  `mealLabel`, so the two surfaces cannot disagree about when dinner starts.
  The distance comes from `distanceLabelFrom` and is **left off** when no real
  fix has landed — a made-up distance on every row is worse than no distance.
- Tap a row to open the restaurant; long-press to cancel.
- Empty: "No plans yet / Bite something, then pick a day." with **Start
  swiping**. The month grid stays — an empty calendar is still a calendar.

## 7. Data-empty today

- **Members.** `plan_members` has no write path until the Friends phase. Every
  plan is a party of one, so the summary bar says "Just you" rather than
  "3 friends" and the avatar stack on a plan row is empty.
- **Votes.** `plan_time_votes` likewise. The "Bring friends" switch is stored
  on the plan and does nothing else yet.
- **Other people's pips.** The design draws cream pips for plans that are not
  yours. Nothing selects another user's plans, so every pip is ember today.

## 8. Out of scope

- Reminders or notifications. A calendar you have to open is still a calendar.
- Syncing to the phone's own calendar.
- A plan for a place that is not in the catalogue — that is what the wishlist
  is for.
- Editing the date. Cancel and pick again; a plan is cheap.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D107 | A plan is one owner, one restaurant, one date. The triple is a unique index and the ON CONFLICT target of `create_plan`, so locking the same place in twice on one day moves the time instead of creating a second row. | locked 2026-09-06 |
| D108 | A past plan is a kept plan unless it was cancelled first. `mark_plan_kept()` flips it server-side on load; there is no "did you go?" prompt, because the calendar records intent and intent that survived to the day counts. | locked 2026-09-06 |
| D109 | Membership is answered by a `security definer` helper, `public.is_plan_member(bigint)`, rather than by policies that reference each other's tables and recurse. `EXECUTE` stays granted to `authenticated` because a policy expression runs with the querying role's privileges; the advisor warning that follows is accepted and explained in the migration. | locked 2026-09-06 |
| D110 | A plan's time is one of five fixed chips — 12:30, 18:30, 20:00, 21:30, Late — not a time picker. "Late" is a label with no hour, which is why `plan_time` is nullable, and it sorts last within a day. | locked 2026-09-06 |
