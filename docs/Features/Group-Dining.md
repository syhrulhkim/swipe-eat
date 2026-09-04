Status: DRAFT
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [General/PLAN.md](../General/PLAN.md), [Swipe-Deck.md](Swipe-Deck.md), [Backend-Schema.md](Backend-Schema.md)

# Group Dining

**Not built.** Tab index 3 exists and ships an honest empty state.

File: `lib/features/dashboard/presentation/group_tab.dart` — 30 lines, all of
it the empty state.

## 1. What ships today

```
Swipe together
Group

  Coming soon
  Nothing here yet
  Group sessions — where you and your friends swipe the same deck
  and the places you all like win — are on the way.
```

The tab exists because the design's nav carries five items. It says so
honestly rather than pretending, and rather than being hidden (D7). A nav that
silently changes shape between builds is worse than a nav with one visible
"coming soon".

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

Open questions worth answering before any schema:

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
