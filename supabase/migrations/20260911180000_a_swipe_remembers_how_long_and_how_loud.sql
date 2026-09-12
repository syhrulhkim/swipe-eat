-- Two columns the deck writes and nothing reads yet (D149).
--
-- `liked` is a one-bit summary of a decision that took a moment to make. A
-- pass after four seconds of watching is not the pass that came half a second
-- in, and a clip somebody turned the sound on for is not the clip they
-- skimmed. Neither can be backfilled: the moment is gone the instant the card
-- flies out, so the columns go in now and the ranking can learn to use them
-- when there are months of rows rather than the 64 there are today.
--
-- Both are nullable on purpose. Every historic row has no answer, a swipe
-- from any surface other than the deck has no answer either, and a null says
-- exactly that — which a 0 and a false would not.
--
-- `dwell_ms` is the time the card spent on top, measured client-side, so it
-- is a phone's clock and a user who backgrounded the app mid-card can report
-- a long one. The cap is deliberate rather than trusting: the client clamps
-- at ten minutes and the constraint only refuses negatives, because a bad
-- number here is a weak signal, not a broken write.
--
-- `unmuted` is the sound state at the moment of the swipe, not a latch. A
-- user who turned the sound on and then off again before swiping records
-- false. Latching would need the mute toggle to report upward through three
-- widgets; the state at the decision is the part that says something about
-- the decision.

alter table public.swipes
  add column if not exists dwell_ms integer,
  add column if not exists unmuted boolean;

alter table public.swipes
  drop constraint if exists swipes_dwell_ms_nonnegative;
alter table public.swipes
  add constraint swipes_dwell_ms_nonnegative
  check (dwell_ms is null or dwell_ms >= 0);

-- A new argument list is a new function, not a replacement: leaving the old
-- one in place would give PostgREST two `record_swipe`s to choose between and
-- every existing caller an ambiguity error. Both new arguments default to
-- null so a client that has not shipped yet keeps working unchanged.
drop function public.record_swipe(bigint, boolean, text, double precision, double precision, boolean);

create function public.record_swipe(
  p_restaurant_id bigint,
  p_liked boolean,
  p_source text default 'deck',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_super_like boolean default false,
  p_dwell_ms integer default null,
  p_unmuted boolean default null
) returns void
language plpgsql security invoker set search_path = '' as $function$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'record_swipe requires an authenticated user'
      using errcode = '42501';
  end if;

  insert into public.swipes (
    user_id, restaurant_id, liked, source,
    swiped_at_latitude, swiped_at_longitude, super_like,
    dwell_ms, unmuted
  )
  values (
    v_user, p_restaurant_id, p_liked, coalesce(p_source, 'deck'),
    p_latitude, p_longitude,
    -- a super like is a like; refuse the contradiction rather than storing it
    coalesce(p_super_like, false) and p_liked,
    -- a negative dwell is a clock that moved backwards, not a measurement
    case when p_dwell_ms >= 0 then p_dwell_ms end,
    p_unmuted
  )
  on conflict (user_id, restaurant_id) do update
    set liked = excluded.liked,
        source = excluded.source,
        swiped_at_latitude = excluded.swiped_at_latitude,
        swiped_at_longitude = excluded.swiped_at_longitude,
        -- a re-swipe is a new decision; visited_at is not, so it survives
        super_like = excluded.super_like,
        -- and the new decision's attention, not the old one's
        dwell_ms = excluded.dwell_ms,
        unmuted = excluded.unmuted;
end $function$;

revoke execute on function public.record_swipe(bigint, boolean, text, double precision, double precision, boolean, integer, boolean) from public;
grant execute on function public.record_swipe(bigint, boolean, text, double precision, double precision, boolean, integer, boolean) to authenticated, service_role;
