-- A plan can be shared with friends, and a friend can ask to come (D153, D154).
--
-- Two new ideas, one migration, because neither works without the other:
--
--   * **Sharing is per plan and off by default** (D153). A switch on the plan,
--     not a setting on the profile: "who knows I am eating here on Saturday"
--     is a question about the Saturday, not about me. The column is the whole
--     of it — no second table, no audience list. Reading somebody else's plan
--     still goes through a `security definer` function (D129), because adding
--     a third permissive select policy to `plans` would widen an advisor
--     finding the project already carries deliberately.
--   * **`requested` is not a membership** (D154). A friend who asks to join
--     writes a `plan_members` row, which is the only place a per-person status
--     on a plan can live — but every existing read treats *any* row as "you
--     are in". So the status is added to the check constraint and then
--     excluded, one by one, from each of the four places that answered "is
--     this person on the plan": `is_plan_member`, the `own membership update`
--     policy, `get_plan_people` and `get_plan_votes`. Miss one and asking to
--     join is the same as letting yourself in.
--
-- The last two were not in the plan for this migration. The plan said they
-- "already gate on `is_plan_member`"; they do not — both carry their own
-- inline `exists (… from plan_members …)`, written before the helper existed,
-- so a requester would have read the roster and the tally of a dinner nobody
-- had let them into. Fixed here rather than filed.

-- ---------------------------------------------------------------------------
-- Sharing
-- ---------------------------------------------------------------------------

alter table public.plans
  add column if not exists shared_with_friends boolean not null default false;

-- The friends read's whole where-clause, in index order: one owner's shared,
-- live plans from a date forward. Partial, because the column is false on
-- nearly every row and a shared plan is the rare one worth an index entry.
create index if not exists plans_shared_date_idx
  on public.plans (owner_id, plan_date)
  where shared_with_friends and status <> 'cancelled';

-- ---------------------------------------------------------------------------
-- The fourth status (D154)
-- ---------------------------------------------------------------------------

alter table public.plan_members
  drop constraint if exists plan_members_status_check;
alter table public.plan_members
  add constraint plan_members_status_check
  check (status in ('invited', 'going', 'declined', 'requested'));

-- The RLS helper (D109). A row that is asking to come is not a seat at the
-- table: this one change carries `member plans select`, `plan members see
-- members`, `plan votes select` and both vote-write policies with it.
create or replace function public.is_plan_member(p_plan_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.plan_members m
    where m.plan_id = p_plan_id
      and m.user_id = (select auth.uid())
      and m.status <> 'requested'
  );
$$;

-- `create or replace` keeps the grants, but say them again so this file reads
-- as the whole story of the function. See the original migration for why
-- `authenticated` cannot be revoked here.
revoke execute on function public.is_plan_member(bigint) from public, anon;
grant execute on function public.is_plan_member(bigint) to authenticated;

-- Without this, a requester PATCHes their own row to 'going' over REST and is
-- at the dinner. The with-check is what stops the promotion; the using clause
-- stops the row being found in the first place.
drop policy if exists "own membership update" on public.plan_members;
create policy "own membership update" on public.plan_members
  for update to authenticated
  using (user_id = (select auth.uid()) and status <> 'requested')
  with check (user_id = (select auth.uid()) and status <> 'requested');

-- ---------------------------------------------------------------------------
-- The two definer reads that had their own idea of membership
-- ---------------------------------------------------------------------------

create or replace function public.get_plan_people(p_plan_ids bigint[])
returns table(
  plan_id bigint,
  user_id uuid,
  status text,
  name text,
  avatar_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer := coalesce(array_length(p_plan_ids, 1), 0);
begin
  if v_uid is null then
    raise exception 'Reading a plan needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if v_count > 200 then
    raise exception 'Too many plans in one call (% sent, 200 allowed).', v_count
      using errcode = '22023';
  end if;

  if v_count = 0 then
    return;
  end if;

  return query
    select m.plan_id, m.user_id, m.status, p.name, p.avatar_url
      from public.plan_members m
      join public.plans pl on pl.id = m.plan_id
      join public.profiles p on p.id = m.user_id
     where m.plan_id = any(p_plan_ids)
       and (
         pl.owner_id = v_uid
         or exists (
           select 1 from public.plan_members mine
            where mine.plan_id = m.plan_id
              and mine.user_id = v_uid
              -- D154: asking is not being in. The owner still sees the
              -- requester's row through the branch above — they have to, to
              -- answer it — but a requester sees nobody.
              and mine.status <> 'requested'
         )
       )
     order by m.plan_id, p.name;
end;
$$;

revoke execute on function public.get_plan_people(bigint[]) from public, anon;
grant execute on function public.get_plan_people(bigint[]) to authenticated;

create or replace function public.get_plan_votes(p_plan_id bigint)
returns table(
  user_id uuid,
  name text,
  avatar_url text,
  plan_time time,
  time_label text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Reading votes needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if not exists (
    select 1 from public.plans pl
     where pl.id = p_plan_id
       and (
         pl.owner_id = v_uid
         or exists (
           select 1 from public.plan_members m
            where m.plan_id = pl.id
              and m.user_id = v_uid
              and m.status <> 'requested'   -- D154
         )
       )
  ) then
    return;
  end if;

  return query
    select v.user_id, p.name, p.avatar_url, v.plan_time, v.time_label
      from public.plan_time_votes v
      join public.profiles p on p.id = v.user_id
      join public.plans pl on pl.id = v.plan_id
     where v.plan_id = p_plan_id
       -- Only people still on the plan are counted. A row left over from
       -- before this migration, or from somebody since removed, is ignored
       -- rather than deleted: the tally is the question, not the history.
       and (
         v.user_id = pl.owner_id
         or exists (
           select 1 from public.plan_members m
            where m.plan_id = v.plan_id
              and m.user_id = v.user_id
              and m.status <> 'requested'   -- D154
         )
       )
     order by p.name;
end;
$$;

revoke execute on function public.get_plan_votes(bigint) from public, anon;
grant execute on function public.get_plan_votes(bigint) to authenticated;

-- Answering an invite is for people who were invited. A requester has no
-- invite to answer, and the policy above already refuses them the row — this
-- says it in words so the app gets a sentence rather than "0 rows updated".
create or replace function public.answer_plan_invite(
  p_plan_id bigint,
  p_status text
)
returns public.plan_members
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.plan_members;
begin
  if v_uid is null then
    raise exception 'Answering an invite needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if p_status not in ('going', 'declined', 'invited') then
    raise exception 'Unknown invite answer: %', p_status
      using errcode = '22023';
  end if;

  update public.plan_members
     set status = p_status
   where plan_id = p_plan_id
     and user_id = v_uid
     and status <> 'requested'
  returning * into v_row;

  if v_row is null then
    raise exception 'No invite to that plan.' using errcode = '22023';
  end if;

  return v_row;
end;
$$;

revoke execute on function public.answer_plan_invite(bigint, text) from public, anon;
grant execute on function public.answer_plan_invite(bigint, text) to authenticated;

-- ---------------------------------------------------------------------------
-- create_plan grows a sixth argument
-- ---------------------------------------------------------------------------
--
-- A new parameter is a new signature, so this is a drop and a create: `create
-- or replace` would leave both overloads in place and every call would be
-- ambiguous. The grants have to be reissued against the new signature.
drop function if exists public.create_plan(bigint, date, time, text, boolean);

create or replace function public.create_plan(
  p_restaurant_id bigint,
  p_plan_date date,
  p_plan_time time default null,
  p_time_label text default null,
  p_with_friends boolean default false,
  p_shared boolean default false
)
returns public.plans
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_plan public.plans;
begin
  if v_uid is null then
    raise exception 'A plan needs a signed-in owner.'
      using errcode = '28000';
  end if;

  insert into public.plans as p
    (owner_id, restaurant_id, plan_date, plan_time, time_label, with_friends,
     shared_with_friends)
  values
    (v_uid, p_restaurant_id, p_plan_date, p_plan_time, p_time_label,
     p_with_friends, p_shared)
  on conflict (owner_id, restaurant_id, plan_date) do update
    set plan_time = excluded.plan_time,
        time_label = excluded.time_label,
        with_friends = excluded.with_friends,
        shared_with_friends = excluded.shared_with_friends,
        -- Re-picking a cancelled day is how you un-cancel it.
        status = case when p.status = 'cancelled' then 'planned' else p.status end
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke execute on function
  public.create_plan(bigint, date, time, text, boolean, boolean) from public, anon;
grant execute on function
  public.create_plan(bigint, date, time, text, boolean, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Inviting somebody who already asked
-- ---------------------------------------------------------------------------
--
-- Only the on-conflict clause changed. An owner who sees "Farah asked to
-- join" and reaches for the invite screen instead of the Accept button means
-- the same thing by it, so the request is accepted in place rather than left
-- pending beside a duplicate that cannot exist. The upgrade fires the same
-- `join_accepted` push the Accept button does, which is the point.
create or replace function public.invite_to_plan(
  p_plan_id bigint,
  p_user_ids uuid[]
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer := coalesce(array_length(p_user_ids, 1), 0);
  v_added integer := 0;
begin
  if v_uid is null then
    raise exception 'Inviting needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if v_count > 50 then
    raise exception 'Too many guests in one call (% sent, 50 allowed).', v_count
      using errcode = '22023';
  end if;

  if v_count = 0 then
    return 0;
  end if;

  with invitable as (
    select u.user_id
      from unnest(p_user_ids) as u(user_id)
     where u.user_id <> v_uid
       and exists (
         select 1
           from public.friendships f
          where f.status = 'accepted'
            and f.user_lo = least(v_uid, u.user_id)
            and f.user_hi = greatest(v_uid, u.user_id)
       )
  ), added as (
    insert into public.plan_members (plan_id, user_id, status)
    select p_plan_id, invitable.user_id, 'invited'
      from invitable
    -- Inviting somebody who is already on the plan is a no-op, not an error:
    -- the screen is multi-select and re-sending is the obvious mistake. The
    -- one exception is a pending request, which the invite answers.
    on conflict (plan_id, user_id) do update
      set status = 'going'
      where plan_members.status = 'requested'
    returning 1
  )
  select count(*) into v_added from added;

  return v_added;
end;
$$;

revoke execute on function public.invite_to_plan(bigint, uuid[]) from public, anon;
grant execute on function public.invite_to_plan(bigint, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Asking to come, and answering
-- ---------------------------------------------------------------------------
--
-- Security definer, because the whole gate is a read of a plan the caller
-- cannot see yet: `member plans select` is exactly what asking is trying to
-- earn. The gate is therefore the insert's own where-clause, all of it in one
-- statement so there is no window between checking and writing — not the
-- owner, shared, not cancelled, not already past, and an accepted friendship
-- in either direction. Nothing about the plan comes back out of the failure
-- path: a plan that does not exist, is private, is over, or belongs to a
-- stranger all give the same sentence.
create or replace function public.ask_to_join(
  p_plan_id bigint,
  p_today date default current_date
)
returns public.plan_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.plan_members;
begin
  if v_uid is null then
    raise exception 'Asking to join needs a signed-in caller.'
      using errcode = '28000';
  end if;

  insert into public.plan_members (plan_id, user_id, status)
  select pl.id, v_uid, 'requested'
    from public.plans pl
   where pl.id = p_plan_id
     and pl.owner_id <> v_uid
     and pl.shared_with_friends
     and pl.status <> 'cancelled'
     -- The phone's today, for the reason every date-sensitive RPC here takes
     -- one (D108): the database clock is UTC and Kuala Lumpur is +8.
     and pl.plan_date >= p_today
     and exists (
       select 1 from public.friendships f
        where f.status = 'accepted'
          and f.user_lo = least(v_uid, pl.owner_id)
          and f.user_hi = greatest(v_uid, pl.owner_id)
     )
  -- Already invited, already going, already asked: nothing to do, and the
  -- raise below says so in the same neutral words as a refusal.
  on conflict (plan_id, user_id) do nothing
  returning * into v_row;

  if v_row is null then
    raise exception 'That plan is not open to you.' using errcode = '22023';
  end if;

  return v_row;
end;
$$;

revoke execute on function public.ask_to_join(bigint, date) from public, anon;
grant execute on function public.ask_to_join(bigint, date) to authenticated;

-- Invoker: `plan owner manages members` already says only the plan's owner may
-- touch its rows, so this RPC exists to name the two answers, not to grant
-- anything. Returns whether it changed something, so the screen can tell
-- "declined" from "somebody already answered this".
--
-- Declining deletes rather than parking the row at 'declined': a request that
-- was turned down should not sit in the roster looking like an invite that
-- was, and the friend can ask again if it was a mistake.
create or replace function public.answer_join_request(
  p_plan_id bigint,
  p_user_id uuid,
  p_accept boolean
)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Answering a request needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if p_accept then
    update public.plan_members
       set status = 'going'
     where plan_id = p_plan_id
       and user_id = p_user_id
       and status = 'requested';
  else
    delete from public.plan_members
     where plan_id = p_plan_id
       and user_id = p_user_id
       and status = 'requested';
  end if;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke execute on function
  public.answer_join_request(bigint, uuid, boolean) from public, anon;
grant execute on function
  public.answer_join_request(bigint, uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- The friends' journey
-- ---------------------------------------------------------------------------
--
-- The Calendar tab's "Friends" section: shared, live, not-yet-past plans
-- belonging to people the caller is actually friends with. Definer for the
-- usual reason (D129) — `plans`, `profiles` and `plan_members` are all closed
-- to a non-member — and the friendship join is what keeps it honest, both
-- ways round:
--
--   * the plan's owner must be an accepted friend of the caller;
--   * `going_friends` names only the going members who are *also* the
--     caller's friends. Who else is at the dinner is the owner's business,
--     not a directory: a stranger's name never leaves the server, and the
--     headcount next to it is a number, not a list.
--
-- Plans the caller is already invited to or going to are left out — those are
-- already in their own calendar and would draw twice. A plan they have only
-- *asked* about stays, with `asked` true, because the row is how the screen
-- remembers to show "Asked" instead of the button.
--
-- `going_count` counts members at 'going' and not the owner: the owner is the
-- face on the row, and "with Farah +2" is about everyone else.
create or replace function public.get_friends_plans(
  p_from date,
  p_limit integer default 100
)
returns table(
  plan_id bigint,
  owner_id uuid,
  owner_name text,
  owner_avatar_url text,
  restaurant_id bigint,
  restaurant_name text,
  cover_url text,
  plan_date date,
  plan_time time,
  time_label text,
  going_count integer,
  going_friends jsonb,
  asked boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    pl.id,
    pl.owner_id,
    op.name,
    op.avatar_url,
    pl.restaurant_id,
    r.name,
    (select i.url
       from public.restaurant_images i
      where i.restaurant_id = r.id
      order by i.position
      limit 1),
    pl.plan_date,
    pl.plan_time,
    pl.time_label,
    (select count(*)::integer
       from public.plan_members m
      where m.plan_id = pl.id and m.status = 'going'),
    coalesce((
      select jsonb_agg(picked.friend)
        from (
          select jsonb_build_object(
                   'id', p.id, 'name', p.name, 'avatar_url', p.avatar_url
                 ) as friend
            from public.plan_members m
            join public.profiles p on p.id = m.user_id
            join public.friendships gf
              on gf.status = 'accepted'
             and gf.user_lo = least((select auth.uid()), m.user_id)
             and gf.user_hi = greatest((select auth.uid()), m.user_id)
           where m.plan_id = pl.id
             and m.status = 'going'
           order by p.name
           limit 6
        ) picked
    ), '[]'::jsonb),
    exists (
      select 1 from public.plan_members mine
       where mine.plan_id = pl.id
         and mine.user_id = (select auth.uid())
         and mine.status = 'requested'
    )
  from public.plans pl
  -- A signed-out caller has a null uid, `least`/`greatest` collapse the pair
  -- to one id, and no friendship row has user_lo = user_hi: nothing matches.
  join public.friendships f
    on f.status = 'accepted'
   and f.user_lo = least((select auth.uid()), pl.owner_id)
   and f.user_hi = greatest((select auth.uid()), pl.owner_id)
  join public.profiles op on op.id = pl.owner_id
  join public.restaurants r on r.id = pl.restaurant_id
 where pl.shared_with_friends
   and pl.status <> 'cancelled'
   and pl.plan_date >= p_from
   and not exists (
     select 1 from public.plan_members mem
      where mem.plan_id = pl.id
        and mem.user_id = (select auth.uid())
        and mem.status <> 'requested'
   )
 order by pl.plan_date, pl.plan_time nulls last, pl.id
 limit least(coalesce(p_limit, 100), 200);
$$;

revoke execute on function public.get_friends_plans(date, integer) from public, anon;
grant execute on function public.get_friends_plans(date, integer) to authenticated;
