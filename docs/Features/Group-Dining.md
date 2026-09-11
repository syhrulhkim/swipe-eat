Status: Superseded 2026-09-06 by [Plans-Calendar.md](Plans-Calendar.md)
Owner: Swipe Eat team
Last updated: 2026-09-10
Cross-references: [Friends.md](Friends.md), [Plans-Calendar.md](Plans-Calendar.md), [General/PLAN.md](../General/PLAN.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md)

# Group Dining

**Superseded.** Tab index 3 is the **Calendar** now — see
[Plans-Calendar.md](Plans-Calendar.md). `group_tab.dart` is deleted and the
empty state it held is gone with it. The social layer this document was waiting
on also exists now: the friend graph, invites and per-plan time voting are
[Friends.md](Friends.md) and [Plans-Calendar.md](Plans-Calendar.md) §6a.

What survives from this document is section 3 onward: the shared-deck sketch
and its open questions are still unanswered, and still worth answering before
any schema. Plans took the tab; they did not answer group swiping.

The `plan_members` and `plan_time_votes` tables the plans phase added are the
nearest thing that exists to the "session and its members" sketched below, but
they carry a *plan*, not a deck. A group session would still need its own
shape.

## 1. What used to ship here

```
Swipe together
Group

  Coming soon
  Nothing here yet
  Group sessions — where you and your friends swipe the same deck
  and the places you all like win — are on the way.
```

The tab existed because the design's nav carries five items, and it said so
honestly rather than being hidden (D7). D87 then renamed the tab to Calendar,
and the plans phase filled it.

## 2. Why it is the most interesting unbuilt feature

Everything else in Swipe Eat is a one-sided market: a restaurant never swipes
back, which is why chat, "Likes You", Boost and mutual matching are all
permanently out of scope
([History/tinder-parity-plan.md](../History/tinder-parity-plan.md)).

Group dining is the one feature that **restores the second side** — and it does
it with other users rather than with restaurants. Two or more people swipe the
same deck, and a place everyone liked is a genuine mutual match. That makes it
the only place in the product where "match" would mean what it means in Tinder.

It is also the first feature that would need **Realtime**, which nothing else
in the product does.

## 3. Sketch (not decided)

Nothing here is locked. Shape, roughly:

- A **session**: one creator, a join code, N members, a location and radius
  resolved once for the group rather than per member.
- A **shared deck**, dealt from `get_deck` against the session's location so
  every member sees the same cards in the same order — otherwise "we all liked
  it" is not comparable.
- **Per-member swipes** against the session, not against `swipes` (which is
  keyed `unique (user_id, restaurant_id)` and would conflate a solo decision
  with a group one).
- A **result surface**: places liked by everyone, then by most, ranked.

Open questions worth answering before any schema. Note that question 1 and
question 4 were written when the deck still had a **daily limit**; D84 removed
it, so what is left of those two is only whether a group swipe retires a card
from the solo deck:

1. Does a group swipe also count as a personal swipe? If yes, a group session
   burns the daily limit and retires cards from the solo deck. If no, the same
   restaurant can be swiped twice with different answers.
2. Is a session live (everyone swiping at once, Realtime) or asynchronous
   (everyone swipes by tonight)? Async is much cheaper and probably more
   useful.
3. What happens when members are in different places? A group deck needs one
   origin; whose?
4. Does the daily limit apply per person or per session?

## 4. Out of scope even when this is built

- **Chat within a session.** The result is a place, not a conversation.
- **Public / discoverable sessions.** Join by code, among people who already
  know each other.

## 5. Decision log

| ID | Decision | Status |
|---|---|---|
| D7 | Unbuilt surfaces ship an explicit empty state rather than being hidden from the nav. | locked 2026-08-31 |
