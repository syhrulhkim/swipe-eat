-- D147 — "Did you go? Would you go back?"
--
-- The app has never had a way for a user to rate anything. `reviews` holds six
-- scraped snippets, `restaurants.rating` is non-zero on 2 of 1 607 rows, and
-- the deck's quality term is therefore inert while its unrated-row jitter is
-- doing all the work. This is the only signal the app can collect that is not a
-- proxy for intent, so it is worth a column, a policy and a trigger.
--
-- Four decisions are encoded here:
--
--   1. **A star is a review row**, not a new table. `reviews` already has the
--      restaurant, the author and the body; it was missing a number. A second
--      table would have needed the same policy, the same index and the same
--      join, to hold one smallint.
--
--   2. **A user's review is visible to their friends, not to the world** (the
--      owner's call). The seeded snippets have a null `user_id` and stay
--      public; everything with an author is fenced by the same accepted-pair
--      test `friends_who_liked` uses. This is the app's first user-written
--      content that leaves its author, which is why the fence goes in at the
--      policy and not in a query.
--
--   3. **`restaurants.rating` follows the stars**, by trigger rather than by
--      the write path, so a review edited or deleted by any route still leaves
--      the column true. From here the column means "what our users say"; the
--      two imported values are noise the first real review overwrites.
--
--   4. **The question is asked about a plan, not only about a walk-in.** D108
--      already flips a past plan to `kept` on the client's next load — an
--      assumption, made with no evidence. `next_visit_prompt` turns that
--      assumption into a question, and "I didn't go" writes the answer back as
--      `cancelled`, which is the only status that says the meal did not happen.

-- ---------------------------------------------------------------------------
-- reviews: the star
-- ---------------------------------------------------------------------------

alter table public.reviews
  add column if not exists rating smallint;

alter table public.reviews
  drop constraint if exists reviews_rating_range;
alter table public.reviews
  add constraint reviews_rating_range
  check (rating is null or rating between 1 and 5);

-- One review per person per place: the second visit edits the first rather
-- than stacking. Partial, because the seeded rows share a null author and
-- would otherwise collide with each other.
create unique index if not exists reviews_user_restaurant_key
  on public.reviews (user_id, restaurant_id)
  where user_id is not null;

-- ---------------------------------------------------------------------------
-- reviews: who may read one
-- ---------------------------------------------------------------------------

drop policy if exists "read reviews" on public.reviews;
create policy "read reviews" on public.reviews
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = reviews.restaurant_id and r.is_active
    )
    and (
      -- Seeded catalogue snippets: no author, no privacy question.
      reviews.user_id is null
      or reviews.user_id = (select auth.uid())
      or exists (
        select 1 from public.friendships f
        where f.status = 'accepted'
          and (
            (f.user_lo = (select auth.uid()) and f.user_hi = reviews.user_id)
            or (f.user_hi = (select auth.uid()) and f.user_lo = reviews.user_id)
          )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- restaurants.rating follows the stars
-- ---------------------------------------------------------------------------
--
-- Security definer because `restaurants` has a read policy and nothing else:
-- no user may write that table, and this trigger is not a user.
create or replace function public.refresh_restaurant_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_restaurant bigint;
  v_avg numeric;
begin
  if tg_op = 'DELETE' then
    v_restaurant := old.restaurant_id;
  else
    v_restaurant := new.restaurant_id;
  end if;

  select round(avg(rating), 1) into v_avg
    from public.reviews
   where restaurant_id = v_restaurant
     and rating is not null;

  update public.restaurants
     set rating = coalesce(v_avg, 0)
   where id = v_restaurant
     and rating is distinct from coalesce(v_avg, 0);

  return null;
end $$;

drop trigger if exists reviews_refresh_rating on public.reviews;
create trigger reviews_refresh_rating
  after insert or delete or update of rating on public.reviews
  for each row execute function public.refresh_restaurant_rating();

-- ---------------------------------------------------------------------------
-- record_visit_answer
-- ---------------------------------------------------------------------------
--
-- One round trip for the whole sheet: "I didn't go", "I went", and "I went and
-- here are four stars" are the same question answered three ways.
--
-- Security definer for the insert into `reviews`, which has no write policy —
-- the RPC is the only way a review is written, so there is nothing to open at
-- the table. It still writes as the caller: every row is keyed on `auth.uid()`.
create or replace function public.record_visit_answer(
  p_restaurant_id bigint,
  p_went boolean,
  p_rating smallint default null,
  p_body text default null,
  p_plan_id bigint default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_name text;
  v_body text := coalesce(pg_catalog.btrim(p_body), '');
begin
  if v_user is null then
    raise exception 'record_visit_answer requires an authenticated user'
      using errcode = '42501';
  end if;

  if p_rating is not null and (p_rating < 1 or p_rating > 5) then
    raise exception 'rating must be between 1 and 5'
      using errcode = '22023';
  end if;

  if not coalesce(p_went, false) then
    -- The plan was flipped to `kept` on assumption (D108); this is the first
    -- evidence either way, so it wins.
    if p_plan_id is not null then
      update public.plans
         set status = 'cancelled'
       where id = p_plan_id
         and owner_id = v_user
         and status = 'kept';
    end if;
    return;
  end if;

  perform public.mark_visited(p_restaurant_id);

  if p_rating is null then
    return;
  end if;

  -- `nullif` is syntax, not a schema function: it needs no qualification and
  -- cannot take one.
  select coalesce(nullif(pg_catalog.btrim(p.name), ''), 'Someone')
    into v_name
    from public.profiles p
   where p.id = v_user;

  insert into public.reviews (restaurant_id, user_id, author_name, body, rating)
  values (
    p_restaurant_id, v_user, coalesce(v_name, 'Someone'), v_body, p_rating
  )
  on conflict (user_id, restaurant_id) where user_id is not null
  do update set
    rating = excluded.rating,
    body = excluded.body,
    author_name = excluded.author_name,
    created_at = pg_catalog.now();
end $$;

revoke execute on function
  public.record_visit_answer(bigint, boolean, smallint, text, bigint)
  from public, anon;
grant execute on function
  public.record_visit_answer(bigint, boolean, smallint, text, bigint)
  to authenticated;

-- ---------------------------------------------------------------------------
-- next_visit_prompt
-- ---------------------------------------------------------------------------
--
-- The meal to ask about: the caller's most recent plan whose day has passed and
-- which they have not rated. `p_today` is the *phone's* today for the same
-- reason `mark_plan_kept` takes one — the database clock is UTC and Kuala
-- Lumpur is +8.
--
-- Fourteen days is the memory window. Past that the answer is a guess, and a
-- guess is worse than silence in the one place the app gets a real opinion.
create or replace function public.next_visit_prompt(p_today date default current_date)
returns table(plan_id bigint, restaurant_id bigint, name text, plan_date date)
language sql
stable
set search_path = ''
as $$
  select p.id, p.restaurant_id, r.name, p.plan_date
    from public.plans p
    join public.restaurants r on r.id = p.restaurant_id and r.is_active
   where p.owner_id = (select auth.uid())
     and p.status = 'kept'
     and p.plan_date < p_today
     and p.plan_date >= p_today - 14
     and not exists (
       select 1 from public.reviews v
        where v.restaurant_id = p.restaurant_id
          and v.user_id = (select auth.uid())
     )
   order by p.plan_date desc, p.id desc
   limit 1;
$$;

revoke execute on function public.next_visit_prompt(date) from public, anon;
grant execute on function public.next_visit_prompt(date) to authenticated;
