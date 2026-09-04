# History

Delivered plans and superseded specs. **Nothing here is maintained**, and
nothing here should be cited as current behaviour — each file's header says
which doc replaced it.

They are kept because a plan records *why* something was built the way it was,
and that reasoning outlives the plan.

| Doc | Status | What it is | Read instead |
|---|---|---|---|
| [backend-plan.md](backend-plan.md) | SHIPPED | The original Supabase migration plan. All six phases delivered; the schema has since grown well past its DDL | [Features/Backend-Schema.md](../Features/Backend-Schema.md) |
| [dashboard-spec.md](dashboard-spec.md) | **SUPERSEDED** | The pre-Supabase app: hardcoded data, dummy GPS, dead search bar, and a Quiz tab that no longer exists | [Features/Swipe-Deck.md](../Features/Swipe-Deck.md), [Explore-Search.md](../Features/Explore-Search.md), [Likes-Visits.md](../Features/Likes-Visits.md) |
| [improvement-plan.md](improvement-plan.md) | SHIPPED | 29 Aug 2026 audit + six-phase plan, all delivered. Its "297 tests" is now 269 | [General/PLAN.md](../General/PLAN.md) |
| [tinder-parity-plan.md](tinder-parity-plan.md) | SHIPPED | Which Tinder features map onto restaurants, and the four that never can | [Features/Swipe-Deck.md](../Features/Swipe-Deck.md) |

## Why these are worth keeping

- **`tinder-parity-plan.md`** is still the clearest statement of why chat,
  "Likes You", Boost and mutual matching are permanently out of scope: a
  restaurant never swipes back. Any future proposal to add them should read it
  first.
- **`backend-plan.md` §0** is the reasoning for dropping the Laravel API
  entirely rather than bridging custom JWTs (D1).
- **`dashboard-spec.md` §4** explains the TikTok player's original constraints,
  which is why the current player is shaped the way it is.
- **`improvement-plan.md`** carries the Sources list — the published guidance
  behind the CI, player, observability and offline decisions.
