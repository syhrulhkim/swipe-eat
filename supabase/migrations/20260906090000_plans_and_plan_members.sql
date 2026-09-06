-- Plans: the Calendar tab's whole backend (D107–D110). Applied to the live
-- project as the `plans_and_plan_members` migration; kept here verbatim so a
-- local stack ends up with the same objects.
--
-- Additive only. Three new tables, one security-definer helper and three RPCs;
-- nothing existing is dropped, renamed or altered.
--
-- Shape decisions worth stating once, here, rather than re-deriving at every
-- call site:
--
--   * A plan is **one owner + one restaurant + one day** (D107). That is a
--     unique index, not a convention — `create_plan` upserts onto it, so
--     picking a second time for the same day moves the time rather than
--     stacking a duplicate the calendar would draw twice.
--   * A plan whose day has passed is **kept unless it was cancelled** (D108).
--     There is no "did you go?" prompt for plans; the calendar is a record of
--     intent, and intent that survived to the day counts. `mark_plan_kept`
--     does the flip, called from the client on load.
--   * Both date-sensitive RPCs take `p_today` (D108). The database clock is
--     UTC and Kuala Lumpur is +8, so a 23:30 plan would otherwise flip to kept
--     eight hours before the evening it belongs to. The phone knows what day
--     it is locally; it says so.
--   * Membership is answered by a **security definer helper** (D109), not by a
--     policy on `plan_members` that reads `plans` while a policy on `plans`
--     reads `plan_members`. That pair recurses and Postgres raises at query
--     time, which is a runtime failure for a shape that can be seen to be
--     wrong when it is written.
--   * The five time slots (12:30, 18:30, 20:00, 21:30, Late) are the whole
--     vocabulary (D110). Four are real times; "Late" is a *label*, because
--     "whenever we're done" is not a clock reading — hence `plan_time` nullable
--     beside a constrained `time_label`.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.plans (
  id bigint generated always as identity primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  restaurant_id bigint not null references public.restaurants(id) on delete cascade,
  plan_date date not null,
  -- Null when the slot chosen was "Late": see D110 above.
  plan_time time,
  time_label text check (time_label is null or time_label in ('late')),
  with_friends boolean not null default false,
  status text not null default 'planned'
    check (status in ('planned', 'kept', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- D107 made enforceable. `create_plan` names this as its conflict target.
create unique index if not exists plans_owner_restaurant_date_key
  on public.plans (owner_id, restaurant_id, plan_date);

-- The Calendar tab's only query shape: my plans, this month, in day order.
create index if not exists plans_owner_date_idx
  on public.plans (owner_id, plan_date);

create index if not exists plans_restaurant_idx
  on public.plans (restaurant_id);

create table if not exists public.plan_members (
  plan_id bigint not null references public.plans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'invited'
    check (status in ('invited', 'going', 'declined')),
  invited_at timestamptz default now(),
  primary key (plan_id, user_id)
);

-- "Which plans am I in?" — the friends phase's read, and the helper's lookup.
-- The primary key already covers (plan_id, user_id); this covers the other way
-- round, which no index would otherwise serve.
create index if not exists plan_members_user_idx
  on public.plan_members (user_id);

create table if not exists public.plan_time_votes (
  plan_id bigint not null references public.plans(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_time time,
  time_label text check (time_label is null or time_label in ('late')),
  primary key (plan_id, user_id)
);

create index if not exists plan_time_votes_user_idx
  on public.plan_time_votes (user_id);

-- The trigger function already exists in this database; plans reuses it rather
-- than growing a second one that does the same thing.
drop trigger if exists plans_touch_updated_at on public.plans;
create trigger plans_touch_updated_at
  before update on public.plans
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Membership helper (D109)
-- ---------------------------------------------------------------------------
--
-- Security definer so it can read `plan_members` without that read being
-- filtered by the very policy it is being called from. The identity check is
-- inside the body — a definer function that took the caller's word for who
-- they are would be an open door — and execute is revoked from everyone who
-- has no business calling it directly.
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
  );
$$;

revoke execute on function public.is_plan_member(bigint) from public, anon;
-- `authenticated` keeps EXECUTE and cannot be talked out of it: an RLS policy
-- expression runs with the querying role's privileges, so revoking here turns
-- every read of `plans` into "permission denied for function is_plan_member"
-- (verified against the live project before this comment was written).
--
-- That leaves the linter's `authenticated_security_definer_function_executable`
-- warning standing, because a function in `public` is also reachable at
-- `/rest/v1/rpc/is_plan_member`. It is accepted rather than silenced: the
-- function answers exactly one question — "am *I* in this plan?" — about the
-- caller and nobody else, which is the same fact `own membership select`
-- already hands them off `plan_members`. It leaks nothing that is not already
-- theirs.
grant execute on function public.is_plan_member(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.plans enable row level security;
alter table public.plan_members enable row level security;
alter table public.plan_time_votes enable row level security;

-- Plans: the owner does everything; a member may only look.
drop policy if exists "own plans all" on public.plans;
create policy "own plans all" on public.plans
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy if exists "member plans select" on public.plans;
create policy "member plans select" on public.plans
  for select to authenticated
  using (public.is_plan_member(id));

-- Members: the owner invites and uninvites, each guest answers for themselves.
-- Reading the owner off `plans` from here is safe — the policies on `plans`
-- never read `plan_members`, they call the definer helper, so there is no
-- cycle to fall into.
drop policy if exists "plan owner manages members" on public.plan_members;
create policy "plan owner manages members" on public.plan_members
  for all to authenticated
  using (
    exists (
      select 1 from public.plans p
      where p.id = plan_id and p.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.plans p
      where p.id = plan_id and p.owner_id = (select auth.uid())
    )
  );

drop policy if exists "own membership select" on public.plan_members;
create policy "own membership select" on public.plan_members
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "own membership update" on public.plan_members;
create policy "own membership update" on public.plan_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Votes: everyone in the plan sees the tally; you only cast your own.
drop policy if exists "plan votes select" on public.plan_time_votes;
create policy "plan votes select" on public.plan_time_votes
  for select to authenticated
  using (
    public.is_plan_member(plan_id)
    or exists (
      select 1 from public.plans p
      where p.id = plan_id and p.owner_id = (select auth.uid())
    )
  );

drop policy if exists "own vote insert" on public.plan_time_votes;
create policy "own vote insert" on public.plan_time_votes
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "own vote update" on public.plan_time_votes;
create policy "own vote update" on public.plan_time_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "own vote delete" on public.plan_time_votes;
create policy "own vote delete" on public.plan_time_votes
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- "Lock it in". One plan per owner + restaurant + day (D107): picking the same
-- day twice moves the time rather than stacking a second row, and a plan the
-- user had cancelled comes back rather than blocking the insert forever.
--
-- Security invoker, so RLS still applies: the insert can only ever write the
-- caller's own row because the with-check on "own plans all" says so.
create or replace function public.create_plan(
  p_restaurant_id bigint,
  p_plan_date date,
  p_plan_time time default null,
  p_time_label text default null,
  p_with_friends boolean default false
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
    (owner_id, restaurant_id, plan_date, plan_time, time_label, with_friends)
  values
    (v_uid, p_restaurant_id, p_plan_date, p_plan_time, p_time_label, p_with_friends)
  on conflict (owner_id, restaurant_id, plan_date) do update
    set plan_time = excluded.plan_time,
        time_label = excluded.time_label,
        with_friends = excluded.with_friends,
        -- Re-picking a cancelled day is how you un-cancel it.
        status = case when p.status = 'cancelled' then 'planned' else p.status end
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke execute on function
  public.create_plan(bigint, date, time, text, boolean) from public, anon;
grant execute on function
  public.create_plan(bigint, date, time, text, boolean) to authenticated;

-- D108: a plan whose day has passed is kept unless it was cancelled. Called by
-- the client on load, with the *phone's* today — see the header.
create or replace function public.mark_plan_kept(p_today date default current_date)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    return 0;
  end if;

  with flipped as (
    update public.plans
       set status = 'kept'
     where owner_id = v_uid
       and status = 'planned'
       and plan_date < p_today
    returning 1
  )
  select count(*) into v_count from flipped;

  return v_count;
end;
$$;

revoke execute on function public.mark_plan_kept(date) from public, anon;
grant execute on function public.mark_plan_kept(date) to authenticated;

-- The two numbers on the profile: how many plans were kept, and how long the
-- run of weeks with a plan in them has been going.
--
-- The streak counts *ISO weeks*, not plans, and only weeks already in the past
-- — a plan booked for next Friday is not a week you have eaten out in yet. It
-- may end on the current week or the previous one: requiring the current week
-- would reset every streak at midnight on Sunday, which punishes the user for
-- the calendar turning over rather than for stopping.
--
-- The prefix trick in the last select: weeks come back newest first, so the
-- Nth week of an unbroken run is exactly `anchor - (n-1) * 7`. The first gap
-- pushes every later week below its expected date and none of them can match
-- again, so counting matches counts the unbroken prefix.
create or replace function public.plan_stats(p_today date default current_date)
returns table(plans_kept integer, streak_weeks integer)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_kept integer := 0;
  v_streak integer := 0;
  v_anchor date;
  v_this_week date := date_trunc('week', p_today)::date;
begin
  if v_uid is null then
    plans_kept := 0;
    streak_weeks := 0;
    return next;
    return;
  end if;

  select count(*) into v_kept
    from public.plans
   where owner_id = v_uid and status = 'kept';

  select max(date_trunc('week', plan_date)::date) into v_anchor
    from public.plans
   where owner_id = v_uid
     and status <> 'cancelled'
     and plan_date < p_today;

  if v_anchor is not null
     and v_anchor in (v_this_week, v_this_week - 7) then
    select count(*) into v_streak
      from (
        select w, row_number() over (order by w desc) as rn
          from (
            select distinct date_trunc('week', plan_date)::date as w
              from public.plans
             where owner_id = v_uid
               and status <> 'cancelled'
               and plan_date < p_today
          ) weeks
      ) ranked
     where ranked.w = v_anchor - (((ranked.rn - 1) * 7)::integer);
  end if;

  plans_kept := v_kept;
  streak_weeks := v_streak;
  return next;
end;
$$;

revoke execute on function public.plan_stats(date) from public, anon;
grant execute on function public.plan_stats(date) to authenticated;
