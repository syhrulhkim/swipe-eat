-- A vote needs a seat at the table (D143).
--
-- "own vote insert" checked that the row carried the caller's own id and
-- nothing else, so any signed-in stranger could write a row into any plan's
-- tally with a direct PostgREST insert asking for `Prefer: return=minimal`.
-- The `set_plan_vote` RPC was never the way in — it ends in `returning`, and
-- Postgres applies the *select* policy to an `insert ... returning`, so a
-- non-member's call already raised. The hole was the plain insert.
--
-- A stranger's row is not a read leak: `get_plan_votes` counts it, so it can
-- put a time on the owner's "Move it to" button that nobody at the dinner
-- picked. Three layers, because this one corrupts an answer:
--   1. the insert and update policies test plan membership, the same
--      expression "plan votes select" already uses;
--   2. `set_plan_vote` says so in words, so the app gets a sentence rather
--      than an RLS violation;
--   3. `get_plan_votes` returns only voters who are still in the plan, so a
--      row written before this migration — or by someone since removed —
--      stops counting.

-- Membership, phrased once. Matches "plan votes select": the owner is not
-- necessarily a row in plan_members, so they are named separately.
drop policy if exists "own vote insert" on public.plan_time_votes;
create policy "own vote insert" on public.plan_time_votes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and (
      public.is_plan_member(plan_id)
      or exists (
        select 1 from public.plans p
        where p.id = plan_id and p.owner_id = (select auth.uid())
      )
    )
  );

drop policy if exists "own vote update" on public.plan_time_votes;
create policy "own vote update" on public.plan_time_votes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (
      public.is_plan_member(plan_id)
      or exists (
        select 1 from public.plans p
        where p.id = plan_id and p.owner_id = (select auth.uid())
      )
    )
  );

create or replace function public.set_plan_vote(
  p_plan_id bigint,
  p_plan_time time without time zone default null,
  p_time_label text default null
)
returns public.plan_time_votes
language plpgsql
set search_path to ''
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

  -- The policy refuses this too. Said here so the app hears why.
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
    raise exception 'Only people on the plan can vote on its time.'
      using errcode = '42501';
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

create or replace function public.get_plan_votes(p_plan_id bigint)
returns table (
  user_id uuid,
  name text,
  avatar_url text,
  plan_time time without time zone,
  time_label text
)
language plpgsql
stable
security definer
set search_path to ''
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
      join public.plans pl on pl.id = v.plan_id
     where v.plan_id = p_plan_id
       -- Only people still on the plan are counted. A row left over from
       -- before this migration, or from somebody since removed, is ignored
       -- rather than deleted: the tally is the question, not the history.
       and (
         v.user_id = pl.owner_id
         or exists (
           select 1 from public.plan_members m
            where m.plan_id = v.plan_id and m.user_id = v.user_id
         )
       )
     order by p.name;
end;
$$;
