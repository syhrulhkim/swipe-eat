Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-10
Cross-references: [Plans-Calendar.md](Plans-Calendar.md), [Onboarding-Taste.md](Onboarding-Taste.md), [Wishlist.md](Wishlist.md), [Restaurant-Detail.md](Restaurant-Detail.md), [Profile-Preferences.md](Profile-Preferences.md), [Backend-Schema.md](Backend-Schema.md), [../General/DECISIONS.md](../General/DECISIONS.md), [../Redesign/GAP-ANALYSIS.md](../Redesign/GAP-ANALYSIS.md)

# Friends

Ngap is a plan-a-dinner app, and a dinner needs somebody to eat it with. This
is the graph underneath that: who you know, how you came to know them, and the
six places in the app that ask.

The feature has two screens of its own and five that borrow them:

- **01f · Friends** — a step in onboarding, and the **only** place contact
  matching happens.
- **`/friends`** — the three lists behind the You tab's "Friends · 38": people
  waiting on your answer, people you are waiting on, and the friends
  themselves. The design draws the button and stops; this screen is that
  button's implication in the design's own vocabulary.
- **S5 · Invite friends** (`/plans/:id/invite`) — sends people to a plan.
- **The plan** (`/plans/:id`) — the roster and who voted for what. Owned by
  [Plans-Calendar.md](Plans-Calendar.md) §6a.
- **The Calendar card** — an avatar stack of the guests on a plan.
- **The restaurant screen's friends row**, and **the wishlist's "From Aiman"**.

Files: `lib/features/friends/models/friend.dart`,
`domain/{phone_hash.dart,friend_captions.dart,invite_ordering.dart,vote_tally.dart}`,
`data/{friends_repository.dart,contacts_reader.dart}`,
`state/friends_controller.dart`,
`presentation/{friends_page.dart,invite_page.dart,person_row.dart,friend_avatar.dart}`.
Screens 01f and 05 in `docs/Redesign/assets/ngap-app-screens.html`.

Migrations: `supabase/migrations/20260906160000_friendships_and_contact_matching.sql`,
`20260906160100_plan_people_invites_and_votes.sql`,
`20260906160200_friendships_block_holds.sql` (with its correction,
`20260906160300_friendships_block_holds_remove_branch.sql`).

## 1. Three columns, and no fourth

`profiles` is owner-only under RLS and stays that way. A friend's name is not
readable by a policy, a join, or a `select` — it comes back only from a
`security definer` function that hands over **id, name, avatar url** and
nothing else (D129).

That is why `FriendsRepository` has no method that could return a phone number
or an email even by accident: there is no return type in the whole feature that
carries one. `FriendProfile` is those three columns and it is the only shape
any screen ever sees of another person.

The alternative — a select policy that lets any authenticated user read any
profile row — would hand out every column on the table to solve a problem that
three columns solve.

## 2. Contact matching

The design's footnote says *"We don't upload your contacts. Matching happens on
your phone."* That cannot be true of any scheme that finds friends among
strangers: the phone has no way to know who else has an account without asking
somebody. The shipped copy says what is actually true instead (D127) — the
numbers leave scrambled, the names never leave at all, and nothing is kept.

What happens on a tap of **Find friends from contacts**:

1. `readContactPhoneNumbers()` asks the OS for `ContactProperty.phone` **and
   nothing else**, so the address book's names are never in the process's
   memory. iOS 18's "only these contacts" counts as granted — the user chose
   who to share, which is more consent than the all-or-nothing prompt asks for.
2. `normalizeE164` puts each number in E.164 (`012-345 6789` → `+60123456789`),
   because that is the only form both sides can agree on. Malaysia is the
   assumed country for a bare local number; anything already carrying a country
   code is left alone, so a Singaporean cousin is not rewritten. Anything under
   seven digits is not a phone number and is dropped.
3. `hashE164` SHA-256s it and sends hex. `FriendsRepository.matchContacts`
   takes **raw numbers** and hashes on the way past, so no caller can forget
   to — the only argument the method accepts is the thing that must not be
   sent, which makes the mistake unwriteable.
4. `match_contacts` peppers the hex with a vault secret and hashes again before
   comparing. It writes nothing, logs nothing, and keeps nothing: the array
   lives for the length of one statement (D128).

**Contacts are matched once, at sign-up.** `Find friends from contacts` is a
button on the onboarding step and nowhere else: `/friends` has no
contact-import entry, and nothing re-scans the address book later. That is why
the friends page's empty copy says "Requests you send and requests you get both
land here" rather than promising something when a contact joins — the two ways
a name lands there are the only two there are. A re-scan from `/friends` is a
reasonable thing to want and is not built.

**What the pepper is for.** Not hiding the number from the server, which could
grind a peppered hash of every Malaysian mobile in an afternoon. It is so that
`phone_hashes` **at rest** is useless to somebody who walks off with a database
dump but not the vault key. That is the threat the design addresses; claiming
more would be the same mistake as the footnote.

The hash lives in its own table keyed to `auth.users`, not on `profiles`
(D128): `handle_new_user` and `sync_phone_hash` are both `after insert`
triggers on the same event, triggers fire in name order, and a `profiles`
column could be written before the row it belongs to exists. A side table has
no such ordering problem and keeps a secret-ish column off the table every
screen selects from.

`match_contacts` is capped at 500 per call, never returns the hash it matched
on, and excludes blocked pairs — so blocking somebody also hides you from their
address book.

## 3. Schema

### `friendships`

One row per pair, in one direction (D130):

| Column | Note |
|---|---|
| `user_lo`, `user_hi` | The pair, ordered — `check (user_lo < user_hi)`, primary key |
| `requester_id` | Who asked. Constrained to be one of the two |
| `status` | `pending`, `accepted` or `blocked` |
| `created_at`, `updated_at` | |

Ordered because "am I friends with X" should be one primary-key lookup, and
because two rows per pair is two rows to fall out of step with each other.
`requester_id` carries the fact acceptance needs: the *other* party accepts.

### `phone_hashes`

`user_id` (primary key, → `auth.users`), `phone_hash`, `updated_at`. Written by
a trigger, read by `match_contacts`, returned by nothing.

### RLS

- **select** — rows you are in. The graph of who knows whom is not public.
- **insert** — a request you are making, in a pair you are in, `pending`. There
  is no way to insert an already-accepted friendship.
- **update** — either party, but **the requester cannot land it on
  `accepted`**. Accepting your own request is closed at the policy, not only
  inside the RPC: the RPC is the app's path, the policy is the boundary.
- **update/delete on a blocked row** — the blocker only (D130). See §4.

### RPCs

| Function | Returns | Why definer |
|---|---|---|
| `get_friends()` | accepted friends, by name | `profiles` is owner-only (D129) |
| `get_friend_requests()` | pending, in and out | same |
| `match_contacts(text[])` | matched profiles | same, plus the pepper |
| `friend_request(uuid, text)` | the row | **invoker** — RLS is the boundary |
| `get_plan_people(bigint[])` | a month of rosters in one call | same as `get_friends` |
| `friends_who_liked(bigint)` | the detail screen's row, capped at 24 | same |
| `invite_to_plan(bigint, uuid[])` | rows added | **invoker** |
| `answer_plan_invite(bigint, text)` | the membership row | **invoker** |
| `set_plan_vote(bigint, time, text)` | the vote row | **invoker** |
| `get_plan_votes(bigint)` | the tally, with faces | definer (D129) |

Behind them sit the helpers nothing on the client calls directly:
`is_plan_member`, `sync_phone_hash` (the `after insert` trigger),
`e164_phone_digest`, `peppered_phone_hash` and `contact_match_pepper`. All
fifteen are live on the project as of 2026-09-10.

`friend_request` is one RPC with an action rather than four functions (D131).
Send, accept, decline, remove and block are the same statement against the same
primary key with a different verb, and four functions would be four places to
get the pair ordering wrong. It is security **invoker**: every write it makes
is one the caller's own policies already allow, so it is a convenience — not
making the client compute `least`/`greatest` — rather than a privilege.

**Sending into a request that already exists from the other person accepts
it.** Two people who both tapped Add are friends; making one of them tap again
would be theatre.

## 4. Blocking

Found in review, before the feature shipped, and fixed in
`friendships_block_holds`:

- `"own friendships delete"` let **either** party delete any row they were in.
  A blocked user could `DELETE /friendships?user_hi=eq.<me>` and the block was
  gone.
- `"own friendships update"` let either party rewrite the row, including
  `requester_id` — so the blocked user could make themselves the blocker and
  then unblock.
- `friend_request('send')` returned the existing row, so a blocked caller got
  `status = 'blocked'` back and **learned they had been blocked**.

The fix is one clause in each policy — only the blocker may touch a blocked
row — plus a neutral error on send: the same message a genuine failure gives,
so the two are not distinguishable from outside. A block the other person can
detect is worth much less than one they cannot; the point is to disappear, not
to slam a door.

The correction a few minutes later ("remove branch") is worth keeping in view:
excluding every blocked row from `remove` locked the *blocker* out of their own
block. The blocker may lift it; nobody else may.

## 5. Client shape

`FriendsController` is **one shared instance** for the whole app, because five
surfaces ask the same question and none of them can see the others: the You
tab's count, the invite list, the wishlist's "From Aiman", the calendar's
avatar stacks and the friends page itself. Five controllers would mean five
`get_friends` calls and five chances to disagree about how many friends there
are.

The cache is a **map by id**, not a list, because most of what is asked of it
is "what is this id's name" — a wishlist row has a `from_user_id` and nothing
else.

Beyond the address book it holds three per-key caches: `peopleFor(planId)`,
`votesFor(planId)`, `whoLiked(restaurantId)`. They are not loaded alike.
Rosters are fetched by the **calendar**, a month of plan ids in one call, and
the plan screen reuses what is already in hand; the tally is fetched by the
plan screen alone, one plan at a time, because nothing else draws it; and
`whoLiked` by the restaurant screen. All three fail **silently** — a screen
whose job is the plan says "no votes yet" rather than raising an error about a
tally.

Two things worth knowing about the seams:

- **A generation counter.** `reset()` bumps it, and every in-flight load checks
  it before publishing, so one account's address book cannot land in the next
  account's session.
- **The "I am loading" notification waits a microtask.** `ensureLoaded` is
  called from `initState` on four screens, and an `initState` runs inside a
  build; a shared controller notifying there would ask every *other* listening
  screen to rebuild mid-build, which Flutter refuses outright. The flags are
  set before the wait, so anything built in that frame still sees the spinner —
  only the notification is late.

Pure domain code sits outside the controller and is tested on its own:
`phone_hash.dart` (E.164), `invite_ordering.dart` ("Ate with recently", search
matching), `friend_captions.dart` (the "Aiman, Mei Kee and 4 friends" line,
`planPeopleLine`, `planHeadcount`) and `vote_tally.dart` (the chips' counts).

## 6. The screens

### 01f · Friends (onboarding)

Three states where the prototype draws one, because the design shows the middle
of the story — six matched contacts, three ticked — and the other two are what
the running app shows most of the time:

- **ask** — nothing read yet. One button and the line about what happens to the
  numbers.
- **matched** — the design's screen, with the count read off the result.
- **none** — read, nobody matched. Says so, and leaves Continue as the way out.

Skip sends nothing at all: no contacts read, no requests made. Requests are
sent **sequentially** — six is the realistic maximum, and one that fails does
not stop the ones behind it, because the user chose all of them and five
friends is better than none.

### `/friends`

Three headed lists — waiting on you, waiting on them, and your friends. Every
row is `PersonRow` with something in its `trailing` slot, which is the slot
that widget exists for. **A row with buttons on it is not itself a button**, so
none of these rows tap.

Accept, Decline and Remove each carry the person's name in their semantic
label: two rows can offer the same two words, and "Accept" alone tells a screen
reader which button it is but not whose. In-flight actions are tracked **by
id** rather than by one page-wide flag, because two requests can be answered in
the time one round trip takes.

Removing asks first, in a scrollable sheet.

### S5 · Invite friends

Search, "Ate with recently", then everybody else, and a footer that counts the
selection. `recentCompanionIds` orders by the most recent past plan each person
appears on — so somebody you ate with last week sits above somebody you ate
with in March, even if March was three dinners. Searching collapses both
sections into one unheaded list: a heading over three results answers a
question nobody asked.

The window is whatever the calendar holds, which starts at the first of the
current month, so early in a month the section is short or absent — and the
heading changes to "Your friends" rather than sitting over the whole address
book, which would be a claim the screen has no evidence for.

## 7. Data-empty today

- **The invite screen's context lines.** The design writes *"Free Friday
  evening"*, *"Lives 400 m from there"*, *"Vegetarian — warn her about the
  sambal"*. Each needs a different join — availability, friend home location,
  friend dietary tags — and none of them exists. Rows draw the name alone
  rather than a made-up fact.
- **Friend avatars are initials.** `profiles.avatar_url` is populated only for
  accounts that signed in with a provider that supplied one.
- **Anybody signed in can write a vote onto any plan id, over REST.**
  `plan_time_votes`'s insert policy is `user_id = auth.uid()` with no membership
  check, and `set_plan_vote` is an invoker function, so the policy is the only
  gate. The RPC itself is not the way in: it ends in `returning * into v_row`,
  and Postgres applies the **select** policy to an `insert ... returning`, so a
  stranger's call raises and the row is rolled back (verified 2026-09-11 against
  the live project with a throwaway table: a plain insert under a
  `with check (true)` / `using (false)` pair is allowed, the same insert with
  `returning` is refused). A direct PostgREST insert asking for
  `Prefer: return=minimal` skips the returning clause and lands the row. The
  stranger still cannot read the tally back, but `get_plan_votes` does not
  filter the **voters** it returns, so the row appears in everybody else's tally
  with the stranger's name and avatar, counts toward the leading slot, and can
  put a time on the owner's "Move it to" button that nobody at the dinner
  picked. Not a read leak; it corrupts the answer. The fix is a membership test
  in the insert policy's `with check` (belt and braces: the same test in
  `set_plan_vote`, and a voter join in `get_plan_votes`), which needs a migration
  against the live project and is not in this pass.

## 7a. What the advisors say, and why

Checked against the live project on 2026-09-10. Three findings, of which two
are **accepted** and the third is a **known issue**:

- **`phone_hashes` has RLS enabled and no policy** (security, INFO). By
  design. Nothing selects the table: the trigger writes it and
  `match_contacts` — a definer function — reads it. No policy means no row is
  readable by anybody, which is the strongest form of what §1 promises.
- **Eight security-definer functions are executable by `authenticated`**
  (security, WARN). Also by design, and it is what §1 and D129 are built on: a
  definer function *is* the boundary that keeps `profiles` owner-only. A policy
  expression also runs with the querying role's privileges, so revoking
  `is_plan_member` would make `select … from public.plans` fail outright
  ([Plans-Calendar.md](Plans-Calendar.md) §3, D109). `get_ngap_count` is
  additionally executable by `anon`; its only caller is
  `RestaurantRepository.ngapCount`, from the restaurant detail page.
- **`friendships_requester_id_fkey` is unindexed** (performance). The known
  issue, and a small one: a delete on a `profiles` row takes a sequential scan of `friendships`,
  which currently holds 0 rows. Worth an index before the table has size —
  recorded here rather than fixed, because it needs a migration against the
  live project.

`friendships` carries **no rows at all** today, so none of the three has a
measurable cost yet.

## 8. Out of scope

- **Friend suggestions.** No "people you may know", no friends-of-friends
  traversal. The graph is not a product surface.
- **Usernames or a search by handle.** You find people through your address
  book or through a plan; there is no directory to search.
- **Reporting.** Blocking exists; a report queue does not.
- **Presence.** No "online now", no last-seen.

## 9. Decision log

| ID | Decision | Status |
|---|---|---|
| D127 | Onboarding says what contact matching actually does. The design's *"matching happens on your phone"* cannot be true of any scheme that finds strangers, so the shipped copy promises what the code delivers: the numbers leave scrambled, the names never leave, nothing is kept. | locked 2026-09-06 |
| D128 | The matching path never sees a phone number, and the hash lives in `phone_hashes`, not on `profiles`. Client normalises and SHA-256s; the server peppers from the vault and hashes again; `match_contacts` writes and keeps nothing. The side table avoids a trigger-ordering race on `auth.users` and keeps a secret-ish column off the table every screen selects from. | locked 2026-09-06 |
| D129 | Every cross-user read returns exactly three columns — id, name, avatar url — through a `security definer` function. `profiles` stays owner-only; no policy is ever opened to make a name visible. | locked 2026-09-06 |
| D130 | A friendship pair is one row in one direction, keyed `(user_lo, user_hi)` with `user_lo < user_hi`; `requester_id` records who asked and the *other* party accepts. A blocked row is the blocker's alone to update or delete, and a send into a block returns the same neutral error a genuine failure gives. | locked 2026-09-06 |
| D131 | One `friend_request(user_id, action)` RPC rather than four functions. The five verbs are the same statement against the same primary key, and four functions would be four places to get the pair ordering wrong. Security invoker, so RLS stays the boundary. | locked 2026-09-06 |

D132 (a plan member may see the other members), D133 (time voting needs no new
schema) and D134 (voting gets a screen the design does not draw) are the plan's
rather than the graph's, and live in
[Plans-Calendar.md](Plans-Calendar.md) §9.
