Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-11
Cross-references: [Friends.md](Friends.md), [Likes-Visits.md](Likes-Visits.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md), [../Frontend/DESIGN-SYSTEM.md](../Frontend/DESIGN-SYSTEM.md)

# Wishlist

A checklist of places to try. Tap a line once you have eaten there and it
crosses itself off, greys its photo and sinks to the bottom. No confetti, no
dialog — the tap *is* the interaction.

Reached from the Bites tab's **"Wishlist →"** chip, at `/wishlist`. It is a
pushed route rather than a sixth tab: it is a place you go to from your bites,
not a place you live in.

Files: `lib/features/wishlist/models/wishlist_item.dart`,
`data/wishlist_repository.dart`, `state/wishlist_controller.dart`,
`presentation/wishlist_page.dart`, `presentation/wishlist_row.dart`.
Screen S8 in `docs/Redesign/assets/ngap-app-screens.html`.

## 1. Why it is a table and not a flag

The up-swipe used to write `swipes.super_like`. Two things were wrong with
that, and both are why `wishlist_items` exists (D94):

- **`record_swipe` overwrites `super_like` on every swipe.** So liking a place
  you had already saved silently unsaved it. A wishlist has to be a list of
  things you *added*, not a property of your most recent swipe.
- **A wishlist row may have no restaurant.** "Add a place…" takes a typed name
  for somewhere that is not in the catalogue at all. A boolean on `swipes`
  cannot hold that, because there is no swipe.

`swipes.super_like` and `get_super_liked_ids()` are still there, untouched, for
data safety. Nothing in the client reads them.

## 2. Schema

Migration `supabase/migrations/20260905110000_wishlist_items.sql`.

```
public.wishlist_items
  id             bigint identity pk
  user_id        uuid not null → profiles(id) on delete cascade
  restaurant_id  bigint        → restaurants(id) on delete cascade
  title          text not null
  source         text not null  check in ('swiped','friend','manual')
  from_user_id   uuid          → profiles(id) on delete set null
  eaten_at       timestamptz
  created_at     timestamptz not null default now()

  check (restaurant_id is not null or source = 'manual')
  unique (user_id, restaurant_id) where restaurant_id is not null
  index  (user_id, eaten_at)
  index  (restaurant_id), index (from_user_id)
```

Notes on the shape:

- **`title` is stored, not only joined.** A manual row has no restaurant to
  join to; and for a row that does, the stored title is what the user saw when
  they saved it, so a renamed restaurant does not rewrite somebody's list.
- **The unique index is partial**, so a user can keep any number of manual
  entries without them colliding on a null `restaurant_id`. The cost is that
  PostgREST cannot name it as an upsert conflict target — Postgres wants the
  index predicate and PostgREST sends none — so `addRestaurant` inserts and
  swallows `23505`. A duplicate Later is success, not an error.
- **Both foreign keys carry their own index**, or a delete on the referenced
  row takes a sequential scan.

### RLS

Enabled, own rows only, one policy per verb (`select`, `insert`, `update`,
`delete`), each `user_id = (select auth.uid())`. The subselect form is
deliberate: the planner evaluates it once per statement rather than per row.

### Backfill

Every `swipes` row with `super_like = true` became a `source = 'swiped'` row,
carrying the swipe's own `updated_at` across as `created_at` so the list is in
the order things were actually saved. **3 rows across 1 user** on the live
project, 2026-09-05. The insert is `on conflict … do nothing`, so re-running it
is a no-op.

## 3. Later writes the wishlist

A Later is **a like plus a row** (D95). The swipe itself is unchanged — still
`record_swipe(p_liked: true)`, with no `p_super_like` on the wire at all.

```
up-swipe / "Later"
  → LikesController.like(id, later: true)
      → SwipeRepository.record(liked: true)        the like
      → WishlistRepository.addRestaurant(id)       the row  (source 'swiped')
```

The wishlist follows the like **on the way out only**:

| Action | Wishlist |
|---|---|
| Later | adds a row |
| Plain like on a place already saved | leaves the row alone |
| Unlike | deletes the row |

The middle line is the bug the old flag had. The last is new work the client
now has to do itself, because the pass no longer clears anything server-side.

`RestaurantRepository.laterIds()` keeps its name and its callers, and now reads
`wishlist_items` where `eaten_at is null` — an eaten place is not a place you
are still going to. It feeds `LikesController.isSavedForLater` /
`laterCount`. Nothing in the Bites tab reads them any more — the tile's
bookmark badge is gone (D125) — but the like/unlike flows still keep the set
current. The Bites tab does not refresh on the way back from here either
([Likes-Visits.md](Likes-Visits.md)).

## 4. Client shape

```
WishlistPage  →  WishlistController  →  WishlistRepository  →  wishlist_items
                        ↓
                  WishlistItem  ·  sortWishlist()
```

- **`WishlistItem`** carries the row plus the restaurant's cover photo, tag,
  neighbourhood and hours, through a nullable
  `restaurants(… restaurant_images(url, position))` join. Null is expected:
  a manual entry has no restaurant, and the catalogue policy can hide one.
  `subtitle` joins whichever of cuisine / neighbourhood / "open 24 h" the row
  knows, so a missing field never leaves a dangling separator.
- **`sortWishlist`** is the one definition of the list's order — to go first,
  then eaten, newest first inside each half. Pure, and used in *both* places:
  the repository after a fetch, and the controller after a toggle. That is why
  a crossed-off row sinks on the tap rather than on the next round trip.
- **`WishlistController`** is optimistic throughout: every toggle, add, remove
  and clear paints first and writes second, and puts the old state back with a
  message if the write is refused. A checklist that waits for a server before
  ticking feels broken. It is **one shared instance** since D151
  (`WishlistController.instance`): the page and the restaurant screen used to
  each build their own, so every detail open refetched the whole list to answer
  one bookmark. The list loads once per run now and is emptied on sign-out
  through `LikesController.reset`, the one place auth is already watched.
- **`WishlistPage`** owns its scaffold (`kBackgroundDark` + `ScreenGlow` +
  `SafeArea`), not `DashboardTabShell` — it is pushed, so it has a back button
  where a tab has a title. It also holds a `FriendsController` (injected, else
  the singleton) for the sender names.

### Sharing

The topbar's second button hands the **to-go** places to the OS share sheet as
plain text (`share_plus`). Eaten places are left out: it is a list of where to
eat, not a diary. The share call is constructor-injected with a default, like
everything else touching a platform channel, so the path is reachable in a
widget test.

## 5. What the screen shows

Per `.wl*` in the prototype:

- **Header** — "Places to / try" over two lines, with `6 to go` / `3 eaten`
  beside it (display face at 18 for the number, small for the label). The
  counts are read as one phrase by a screen reader.
- **Add bar** — a 50 px pill with the field and a 36 px ember round button
  living inside it, so the two read as one control. Drawn at 36, tapped at 44.
- **Rows** — 26 px check circle, 40 px thumb at radius 12, name in the display
  face at 16, "Cuisine · Neighbourhood" under it, and a fixed 58 px column on
  the right saying where the row came from.
- **Hint** — `Tap a place once you've eaten there`, between the add bar and
  the list rather than as row 0, so it stays put while the list scrolls. It is
  drawn only when the list has loaded and is not empty, and it drops itself
  when `MediaQuery.sizeOf(context).height < 600`: on a short phone at a huge
  text scale the fixed chrome leaves no room for the list, and the hint is the
  cheapest thing to lose.
- **Footer** — "Eaten ones sink to the bottom", and an ember **Clear eaten**
  that is dead while nothing is eaten.

The right-hand label reads, in precedence order: **Eaten** with the date
("24 Aug") → **Planned** with a day → **From <name>** → **Swiped** → **Added**.
Chronology wins: a place you have been to is done, whatever date was on it.

### Crossing off

One tap on the row toggles it. The tick fades in, the ember rule sweeps across
the name left-to-right in 260 ms (`kStrikeDuration` — its own token, slower
than `kMotionDuration`, because it is a gesture the eye should follow), the
photo desaturates to 50 %, and the row re-sorts to the bottom.

The whole row is the control. There is no separate checkbox to hit and no menu
behind a long press — a second target would only give the user a way to miss.
`Semantics(button: true, toggled: …, excludeSemantics: true, onTap: …)`, with
the tap action re-declared because excluding drops it (D83).

## 6. Data-empty today

- ~~**`plannedLabel`**~~ — **live since 2026-09-06.** `WishlistPage` reads it
  from `PlansController.plannedLabelFor`, so a wishlist row with a day on it
  says "Fri 4". See [Plans-Calendar.md](Plans-Calendar.md).
- ~~**`from_user_id` names**~~ — **live since the friends phase.** The page
  resolves each sender through `FriendsController.nameFor(item.fromUserId)`
  and hands the result down as `WishlistItem.fromUserName`, so the row reads
  "From Aiman". The friends cache is the *only* place a name could come from,
  so a sender who is not (or is no longer) a friend resolves to null and the
  row falls back to "From a friend". The page listens to
  `Listenable.merge([_controller, _friends])` and calls
  `FriendsController.ensureLoaded()` on init. See [Friends.md](Friends.md).
- **`source = 'friend'`** has no write path. The column and the rendering exist
  ahead of the sharing feature.

## 7. Out of scope

- Reordering the list by hand.
- Notes, prices or a rating on a wishlist row.
- A shared wishlist two people can both write to. Sharing is one-way plain
  text today.

## 8. Decision log

| ID | Decision | Status |
|---|---|---|
| D94 | `wishlist_items` replaces `swipes.super_like` as the store behind Later. The column and `get_super_liked_ids` stay for data safety; the client stops reading them. A wishlist is a list you added to, and it must be able to hold a place that is not in the catalogue. | locked 2026-09-05 |
| D95 | A Later is a like. The swipe is unchanged (`p_liked: true`, no `p_super_like`) and the wishlist row is written on top. The wishlist follows the like on removal only — unliking clears the row, re-liking never does. | locked 2026-09-05 |
