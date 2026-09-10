-- A block that the blocked person can lift is not a block (D130).
--
-- Applied to the live project as the `friendships_block_holds` migration.
-- Additive in the sense this project means it: the only objects touched are
-- the two policies and the one function created earlier in this same phase,
-- an hour ago, by `20260906160000_friendships_and_contact_matching`. Nothing
-- from an earlier phase is altered.
--
-- The hole, found in review before the feature shipped:
--
--   * `"own friendships delete"` let **either** party delete any row they were
--     in. A blocked user could `DELETE /friendships?user_hi=eq.<me>` and the
--     block was gone.
--   * `"own friendships update"` let either party rewrite the row, including
--     `requester_id` — so the blocked user could make themselves the blocker
--     and then unblock.
--   * `friend_request('send')` returned the existing row, so a blocked caller
--     got `status = 'blocked'` back and learned they had been blocked. A block
--     the other person can detect is worth much less than one they cannot:
--     the point is to disappear, not to slam a door.
--
-- The fix is one clause in each policy — **only the blocker may touch a
-- blocked row** — plus a neutral error on send. "Neutral" is doing real work
-- there: it is the same message a genuine failure gives, so the two are not
-- distinguishable from outside.

-- ---------------------------------------------------------------------------
-- The two policies
-- ---------------------------------------------------------------------------

drop policy if exists "own friendships update" on public.friendships;
create policy "own friendships update" on public.friendships
  for update to authenticated
  using (
    (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
    -- A blocked row is the blocker's to change and nobody else's.
    and (status <> 'blocked' or requester_id = (select auth.uid()))
  )
  with check (
    (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
    -- Still no accepting your own request (the original reason for this
    -- clause), and still no taking ownership of somebody else's block.
    and (status <> 'accepted' or requester_id <> (select auth.uid()))
    and (status <> 'blocked' or requester_id = (select auth.uid()))
  );

drop policy if exists "own friendships delete" on public.friendships;
create policy "own friendships delete" on public.friendships
  for delete to authenticated
  using (
    (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
    and (status <> 'blocked' or requester_id = (select auth.uid()))
  );

-- ---------------------------------------------------------------------------
-- friend_request: say nothing on a blocked send
-- ---------------------------------------------------------------------------
--
-- Identical to the version in `20260906160000` apart from the `send` branch,
-- which now checks for a block before writing and raises the same neutral
-- message a real failure would.
create or replace function public.friend_request(p_user_id uuid, p_action text)
returns public.friendships
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_lo uuid;
  v_hi uuid;
  v_row public.friendships;
  v_existing public.friendships;
begin
  if v_uid is null then
    raise exception 'A friend request needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if p_user_id is null or p_user_id = v_uid then
    raise exception 'A friend request needs somebody else to send it to.'
      using errcode = '22023';
  end if;

  v_lo := least(v_uid, p_user_id);
  v_hi := greatest(v_uid, p_user_id);

  select * into v_existing
    from public.friendships
   where user_lo = v_lo and user_hi = v_hi;

  case p_action
    when 'send' then
      -- Blocked in either direction, the answer is the same and it is not
      -- "you are blocked". The blocker's own row is untouched; the blocked
      -- caller cannot tell this apart from the network being down.
      if v_existing.status = 'blocked' then
        raise exception 'Could not send that request.' using errcode = '22023';
      end if;

      insert into public.friendships as f (user_lo, user_hi, requester_id, status)
      values (v_lo, v_hi, v_uid, 'pending')
      -- Asking somebody who already asked you is an accept: the pair is there,
      -- they requested it, and the natural reading of the tap is "yes".
      on conflict (user_lo, user_hi) do update
        set status = case
              when f.status = 'pending' and f.requester_id <> v_uid then 'accepted'
              else f.status
            end
      returning * into v_row;

    when 'accept' then
      update public.friendships
         set status = 'accepted'
       where user_lo = v_lo and user_hi = v_hi
         and status = 'pending'
         and requester_id <> v_uid
      returning * into v_row;

      if v_row is null then
        raise exception 'No request from that person to accept.'
          using errcode = '22023';
      end if;

    when 'decline', 'remove' then
      -- The `status <> 'blocked'` guard is belt and braces beside the delete
      -- policy above; a blocked caller's delete now matches no row either way.
      delete from public.friendships
       where user_lo = v_lo and user_hi = v_hi
         and status <> 'blocked'
      returning * into v_row;

    when 'block' then
      -- Blocking somebody you have no row with: insert pending (the insert
      -- policy insists on it), then flip. Blocking somebody you do have a row
      -- with: take ownership of it and flip. Both end in the same place, and
      -- the update policy permits the flip because this caller becomes the
      -- requester in the same statement.
      insert into public.friendships (user_lo, user_hi, requester_id, status)
      values (v_lo, v_hi, v_uid, 'pending')
      on conflict (user_lo, user_hi) do nothing;

      update public.friendships
         set status = 'blocked', requester_id = v_uid
       where user_lo = v_lo and user_hi = v_hi
         and (status <> 'blocked' or requester_id = v_uid)
      returning * into v_row;

      if v_row is null then
        raise exception 'Could not block that person.' using errcode = '22023';
      end if;

    else
      raise exception 'Unknown friend action: %', p_action
        using errcode = '22023';
  end case;

  return v_row;
end;
$$;

revoke execute on function public.friend_request(uuid, text) from public, anon;
grant execute on function public.friend_request(uuid, text) to authenticated;
