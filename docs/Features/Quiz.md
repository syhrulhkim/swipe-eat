Status: ORPHANED
Owner: Swipe Eat team
Last updated: 2026-09-03
Cross-references: [Backend-Schema.md](Backend-Schema.md), [General/PLAN.md](../General/PLAN.md), [History/dashboard-spec.md](../History/dashboard-spec.md)

# Quiz

**Dead weight.** Four database objects exist and nothing in `lib/` reaches
them. Documented so the next reader knows this is not a feature they somehow
missed.

## 1. What exists

Verified against the live database and the Flutter source on 2026-09-03.

| Object | Rows | Reached by app code? |
|---|---|---|
| `quiz_questions` | 1 | No |
| `quiz_options` | — | No |
| `quiz_responses` | 0 | No |
| `submit_quiz_answer(p_question_id, p_option_id) → quiz_options` | — | No |
| RLS policies: `read questions`, `read options`, `own quiz responses` | 3 | No |

```
$ grep -rn "quiz\|Quiz" lib/ --include="*.dart"
(no matches outside lib/dev)
```

The tables are fully formed — RLS on, roles named, indexes on every FK,
`quiz_responses` uniquely keyed `(user_id, question_id)` so the latest answer
wins on upsert. It is correct code with no caller.

## 2. How it got here

The original build had a **Quiz tab** at nav index 3: one hardcoded
multiple-choice question, and a result card that (as
[History/dashboard-spec.md](../History/dashboard-spec.md) records) did not
actually change based on the answer.

The Supabase migration gave it a real schema — questions, options, per-option
result cards with a `recommended_restaurant_id`, and recorded responses. Then
the tab was replaced by **Group** during the redesign, and the schema was left
behind.

The taste signal the quiz was reaching for now lives in onboarding
(`profile_cuisines`, `profile_dietary_tags`) and feeds `deck_scored` directly,
which is a better answer than a quiz: it runs once, before the first card,
instead of asking the user to visit a tab.

## 3. The decision to make

One of two, and leaving it orphaned is the only wrong answer:

**Drop it.** One migration: `drop function submit_quiz_answer`, drop the three
tables (`quiz_responses` → `quiz_options` → `quiz_questions`, in FK order), and
their policies go with them. `seed.sql` loses its quiz block. Nothing in the
app changes, because nothing in the app reads it. This is the recommendation —
onboarding already does the job better.

**Or build it.** The schema is waiting: multi-question quizzes, per-option
result cards, a recommended restaurant per answer. That needs a surface, and
the nav has no free slot — Group has index 3 now. It would have to live inside
Explore or Profile.

## 4. Cost of leaving it

Small but real: three tables in every schema dump and type generation, three
RLS policies in every security review, one function in the grant audit, and a
seed block that has to keep working. Mostly it is the cost of every reader
having to work out — as this doc just did — whether the quiz is a feature.

## 5. Decision log

| ID | Decision | Status |
|---|---|---|
| D54 | The cold-start taste signal is collected in onboarding, not by a quiz tab — it runs before the first card instead of requiring a visit. | locked 2026-08-23 |
| D55 | Quiz schema retained at the redesign rather than dropped with the tab. **Revisit** — this doc exists because that was deferral, not a decision. | open |
