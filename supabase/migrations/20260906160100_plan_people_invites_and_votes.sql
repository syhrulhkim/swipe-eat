-- Plan people: who is on a plan, who is coming, and what time they want
-- (D123, D126, D127).
--
-- Applied to the live project as the `plan_people_invites_and_votes`
-- migration; kept here verbatim so a local stack ends up with the same
-- objects. Additive only — one new policy on an existing table and five
-- functions. No table is created, dropped or altered: `plan_members` and
-- `plan_time_votes` both arrived with `20260906090000_plans_and_plan_members`
-- and this file is the wiring they were waiting for.
--
--   * **Voting needs no new schema** (D127). A member upserts their own row in
--     `plan_time_votes`, which the policies written in Phase 7 already allow;
--     the tally is a group-by the client does over rows it is permitted to
--     read; and locking a time is the owner updating `plans.plan_time`, which
--     `PlansRepository.setTime` has been doing since Phase 7. The only thing
--     missing was a read that could put a *name* next to a vote.
--   * **A plan member may now see the other members** (D126). Phase 7 gave a
--     guest "own membership select" only, so a guest opening the calendar
--     would see an avatar stack of exactly one face — themselves — on a dinner
--     with five people at it. The new policy is scoped by `is_plan_member`,
--     the same definer helper the rest of the plan policies already lean on,
--     so it introduces no recursion.
--   * **Names still come through definer functions** (D123). The new policy
--     opens `plan_members` — ids and statuses — and nothing else. Turning
--     those ids into faces goes through `get_plan_people`, which returns the
--     same three public columns as `get_friends` and gates on membership
--     inside its own body.

-- ---------------------------------------------------------------------------
-- The missing policy (D126)
-- ---------------------------------------------------------------------------

drop policy if exists "plan members see members" on public.plan_members;
create policy "plan members see members" on public.plan_members
  for select to authenticated
  using (public.is_plan_member(plan_id));

-- ---------------------------------------------------------------------------
-- get_plan_people
-- ---------------------------------------------------------------------------
--
-- The avatar stack on a calendar card, and the roster on a plan. Takes the
-- ids the calendar already holds so one round trip covers a month of plans
-- rather than one call per row.
--
-- Security definer for the reason every cross-user read in this project is
-- (D123): `profiles` is owner-only, so names and faces cannot be joined by an
-- invoker. The gate is inside the body — a plan the caller neither owns nor
-- belongs to contributes nothing, so passing somebody else's plan id returns
-- an empty set rather than an error, which is also the answer that leaks least.
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
            where mine.plan_id = m.plan_id and mine.user_id = v_uid
         )
       )
     order by m.plan_id, p.name;
end;
$$;

revoke execute on function public.get_plan_people(bigint[]) from public, anon;
grant execute on function public.get_plan_people(bigint[]) to authenticated;

-- ---------------------------------------------------------------------------
-- friends_who_liked
-- ---------------------------------------------------------------------------
--
-- "Aiman, Mei Kee and 4 friends ngap'd this" — the detail screen's friends
-- row. Accepted friends only, so this never tells you about a stranger, and
-- never tells a stranger about you.
--
-- Capped at 24: the row draws three faces and names two, so anything past a
-- couple of dozen is a number, and the number stops being interesting long
-- before the cap.
create or replace function public.friends_who_liked(p_restaurant_id bigint)
returns table(id uuid, name text, avatar_url text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name, p.avatar_url
    from public.friendships f
    join public.profiles p
      on p.id = case
                  when f.user_lo = (select auth.uid()) then f.user_hi
                  else f.user_lo
                end
    join public.swipes s
      on s.user_id = p.id
     and s.restaurant_id = p_restaurant_id
     and s.liked = true
   where f.status = 'accepted'
     and ((select auth.uid()) in (f.user_lo, f.user_hi))
   order by s.created_at desc nulls last, p.name
   limit 24;
$$;

revoke execute on function public.friends_who_liked(bigint) from public, anon;
grant execute on function public.friends_who_liked(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- invite_to_plan
-- ---------------------------------------------------------------------------
--
-- "Send invites". Security **invoker**: the `plan owner manages members`
-- policy from Phase 7 is what actually authorises the write, so an owner can
-- only ever add rows to a plan that is theirs.
--
-- The friendship check inside is a product rule rather than a security
-- boundary, and it is worth being honest about which: the policy already
-- stops you adding people to somebody else's dinner, and `get_plan_people`
-- gates its own reads, so the worst a caller who went around this RPC could
-- do is put a stranger's id on their *own* plan. That is untidy, not a leak.
-- Doing it here rather than in the policy keeps the policy readable and keeps
-- one friendship lookup out of every row of every membership read.
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
    -- the screen is multi-select and re-sending is the obvious mistake.
    on conflict (plan_id, user_id) do nothing
    returning 1
  )
  select count(*) into v_added from added;

  return v_added;
end;
$$;

revoke execute on function public.invite_to_plan(bigint, uuid[]) from public, anon;
grant execute on function public.invite_to_plan(bigint, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Answering an invite
-- ---------------------------------------------------------------------------
--
-- Invoker: "own membership update" already restricts this to the caller's own
-- row, so the RPC exists to name the two legal answers rather than to grant
-- anything.
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
   where plan_id = p_plan_id and user_id = v_uid
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
-- Time voting (D127)
-- ---------------------------------------------------------------------------
--
-- One row per person per plan, replaced on each vote. Invoker: the Phase 7
-- policies already say a member may write their own vote and nobody else's,
-- so this is the upsert the client would otherwise hand-roll.
--
-- `plan_time` null with `time_label` 'late' is the "Late" slot, exactly as on
-- `plans` itself (D110) — the vote speaks the same vocabulary as the thing it
-- votes on, so locking a winning slot is a copy rather than a translation.
create or replace function public.set_plan_vote(
  p_plan_id bigint,
  p_plan_time time default null,
  p_time_label text default null
)
returns public.plan_time_votes
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.plan_time_votes;
begin
  if v_uid is null then
    raise exception 'Voting needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if p_plan_time is null and p_time_label is null then
    raise exception 'A vote needs a time or the "late" label.'
      using errcode = '22023';
  end if;

  insert into public.plan_time_votes (plan_id, user_id, plan_time, time_label)
  values (p_plan_id, v_uid, p_plan_time, p_time_label)
  on conflict (plan_id, user_id) do update
    set plan_time = excluded.plan_time,
        time_label = excluded.time_label
  returning * into v_row;

  return v_row;
end;
$$;

revoke execute on function
  public.set_plan_vote(bigint, time, text) from public, anon;
grant execute on function
  public.set_plan_vote(bigint, time, text) to authenticated;

-- The tally, with a face against each vote. Definer for the usual reason
-- (D123); gated on membership or ownership inside, so a plan you have nothing
-- to do with comes back empty.
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
            where m.plan_id = pl.id and m.user_id = v_uid
         )
       )
  ) then
    return;
  end if;

  return query
    select v.user_id, p.name, p.avatar_url, v.plan_time, v.time_label
      from public.plan_time_votes v
      join public.profiles p on p.id = v.user_id
     where v.plan_id = p_plan_id
     order by p.name;
end;
$$;

revoke execute on function public.get_plan_votes(bigint) from public, anon;
grant execute on function public.get_plan_votes(bigint) to authenticated;
