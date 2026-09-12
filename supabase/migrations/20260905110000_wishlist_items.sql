-- The wishlist: a checklist of places to try, crossed off once eaten.
--
-- Replaces `swipes.super_like` as the store behind the deck's "Later" gesture
-- (D94). Two reasons the flag could not stay:
--
--   * `record_swipe` overwrites `super_like` on every swipe, so re-liking a
--     saved place silently unsaved it. A wishlist has to be a thing you added,
--     not a property of your most recent swipe.
--   * A wishlist row may have **no restaurant** — the user types a name into
--     "Add a place…" and that name is all there is. A flag on `swipes` cannot
--     hold a place that was never in the catalogue.
--
-- Additive only. `swipes.super_like` and `get_super_liked_ids` are left exactly
-- as they were, for data safety; the client simply stops reading them.
--
-- Applied to the live project on 2026-09-05 as migration `wishlist_items`, and
-- kept here verbatim (backfill included) so `supabase db reset` reproduces it.

create table if not exists public.wishlist_items (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  restaurant_id bigint references public.restaurants (id) on delete cascade,
  title text not null,
  source text not null check (source in ('swiped', 'friend', 'manual')),
  from_user_id uuid references public.profiles (id) on delete set null,
  eaten_at timestamptz,
  created_at timestamptz not null default now(),
  -- The one shape the table refuses: a row with neither a restaurant nor the
  -- source that is allowed to lack one.
  constraint wishlist_items_has_subject
    check (restaurant_id is not null or source = 'manual')
);

-- One row per place per user. Partial, so a user may keep as many manual
-- entries as they like without them colliding on a null restaurant.
--
-- Note for the client: PostgREST cannot name a *partial* unique index as an
-- upsert conflict target (Postgres wants the predicate, PostgREST sends none),
-- so `WishlistRepository.addRestaurant` inserts and swallows 23505 instead.
create unique index if not exists wishlist_items_user_restaurant_key
  on public.wishlist_items (user_id, restaurant_id)
  where restaurant_id is not null;

-- The list's own order: to-go first, then eaten.
create index if not exists wishlist_items_user_eaten_idx
  on public.wishlist_items (user_id, eaten_at);

-- Both foreign keys need an index of their own, or a delete on the referenced
-- row takes a sequential scan (and the unindexed-FK advisor fires).
create index if not exists wishlist_items_restaurant_idx
  on public.wishlist_items (restaurant_id);
create index if not exists wishlist_items_from_user_idx
  on public.wishlist_items (from_user_id);

alter table public.wishlist_items enable row level security;

-- Own rows only, one policy per verb. `(select auth.uid())` rather than a bare
-- call so the planner evaluates it once per statement instead of per row.
create policy "own wishlist select" on public.wishlist_items
  for select using (user_id = (select auth.uid()));

create policy "own wishlist insert" on public.wishlist_items
  for insert with check (user_id = (select auth.uid()));

create policy "own wishlist update" on public.wishlist_items
  for update using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own wishlist delete" on public.wishlist_items
  for delete using (user_id = (select auth.uid()));

-- Backfill: every existing super like becomes a swiped wishlist row, so nobody
-- loses what they had saved. The swipe's own `updated_at` carries over as
-- `created_at` so the list's order is the order the user actually saved things
-- in, not the migration's clock. Idempotent, so a re-run is a no-op.
--
-- Live project, 2026-09-05: 3 rows across 1 user.
insert into public.wishlist_items (user_id, restaurant_id, title, source, created_at)
select s.user_id, s.restaurant_id, r.name, 'swiped', s.updated_at
from public.swipes s
join public.restaurants r on r.id = s.restaurant_id
where s.super_like = true
on conflict (user_id, restaurant_id) where restaurant_id is not null
do nothing;
