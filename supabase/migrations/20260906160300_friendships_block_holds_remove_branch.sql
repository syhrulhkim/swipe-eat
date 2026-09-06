-- Correction to `friendships_block_holds`, applied minutes later and folded
-- back into that same file in the repository: the `remove` branch had excluded
-- every blocked row, which locked the blocker out of their own block. The
-- blocker may lift it; nobody else may.
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
      if v_existing.status = 'blocked' then
        raise exception 'Could not send that request.' using errcode = '22023';
      end if;

      insert into public.friendships as f (user_lo, user_hi, requester_id, status)
      values (v_lo, v_hi, v_uid, 'pending')
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
      delete from public.friendships
       where user_lo = v_lo and user_hi = v_hi
         and (status <> 'blocked' or requester_id = v_uid)
      returning * into v_row;

    when 'block' then
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
