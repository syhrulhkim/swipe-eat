-- Friends: the friend graph, the contact-matching path, and the three public
-- columns everything cross-user is allowed to see (D127-D131).
--
-- Applied to the live project as the `friendships_and_contact_matching`
-- migration; kept here verbatim so a local stack ends up with the same
-- objects. Additive only — two new tables, one vault secret, one trigger on
-- `auth.users`, and six functions. Nothing existing is dropped or altered.
--
-- Shape decisions worth stating once, here, rather than re-deriving at every
-- call site:
--
--   * **A pair has exactly one row, in one direction.** `friendships` is keyed
--     on (user_lo, user_hi) with `check (user_lo < user_hi)`, so "am I friends
--     with X" is a single primary-key lookup and there is no second row to
--     fall out of step with the first. `requester_id` records who asked, which
--     is the fact acceptance needs: the *other* party accepts (D130).
--   * **Cross-user reads return three columns and no more** (D129): id, name,
--     avatar url. `profiles` is owner-only under RLS and stays that way, so
--     every one of these reads is a `security definer` function that hands
--     back a narrow row rather than a policy that opens the table. The phone
--     hash and the email are never in a return type anywhere in this file.
--   * **The matching path never sees a phone number** (D128). The client
--     normalises to E.164, hashes with SHA-256, and sends hex. The server
--     peppers that hex and hashes again before comparing. Nothing is written
--     to disk by `match_contacts` and the input array is not logged, kept or
--     copied — it lives for the length of one statement.
--
--     The pepper is not there to hide the number from the server, which by
--     construction could grind a peppered hash of every Malaysian mobile in an
--     afternoon. It is there so that `phone_hashes` **at rest** is useless to
--     anyone who walks off with a database dump but not the vault key. That
--     is the threat this design actually addresses, and the onboarding copy
--     was rewritten to say so rather than to claim on-device matching, which
--     no scheme that finds strangers can honestly promise (D127).
--   * **The hash lives in a side table, not on `profiles`** (D128). Its
--     trigger fires on `auth.users`, and `handle_new_user` — which creates the
--     profile row — is also an `after insert` trigger on `auth.users`. Two
--     triggers on one event fire in name order, so a `profiles` column could
--     be written before the row it belongs to exists. A table keyed straight
--     to `auth.users` has no such ordering problem, and it keeps a secret-ish
--     column off the table every screen selects from.

-- ---------------------------------------------------------------------------
-- The pepper
-- ---------------------------------------------------------------------------
--
-- Created once, guarded, so this file is byte-identical across environments
-- while every environment gets its own random secret. A pepper that lived in
-- the migration text would be in git, which is the one place it must not be.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'contact_match_pepper') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'contact_match_pepper',
      'Peppers the stored contact hash so a database dump alone cannot be ground back to phone numbers. Rotating it invalidates every row in public.phone_hashes; re-verification refills them.',
      null
    );
  end if;
end
$$;

-- Reads the pepper for the two functions that need it. Security definer
-- because `authenticated` has no business in `vault` — and execute is revoked
-- from every role, so the only callers are the definer functions below, which
-- run as the owner and need no grant.
create or replace function public.contact_match_pepper()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret
    from vault.decrypted_secrets
   where name = 'contact_match_pepper'
   limit 1;
$$;

revoke execute on function public.contact_match_pepper()
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Hashing, in one place
-- ---------------------------------------------------------------------------
--
-- Both sides of the comparison go through this, so the client's hash and the
-- trigger's hash cannot drift apart. `p_client_hex` is the SHA-256 of the
-- E.164 string ("+60123456789") as the phone sent it; the result is that hex,
-- peppered and hashed again.
--
-- `stable` rather than `immutable`: it reads a secret.
create or replace function public.peppered_phone_hash(p_client_hex text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_client_hex is null or p_client_hex = '' then null
    when public.contact_match_pepper() is null then null
    else encode(
      extensions.digest(
        convert_to(public.contact_match_pepper() || lower(p_client_hex), 'utf8'),
        'sha256'
      ),
      'hex'
    )
  end;
$$;

revoke execute on function public.peppered_phone_hash(text)
  from public, anon, authenticated, service_role;

-- The client's half of the scheme, written out server-side so the trigger can
-- reproduce it from a raw number. E.164 is "+" followed by digits and nothing
-- else, which is exactly what `normalizeE164` produces on the phone.
create or replace function public.e164_phone_digest(p_phone text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_phone is null or regexp_replace(p_phone, '\D', '', 'g') = '' then null
    else encode(
      extensions.digest(
        convert_to('+' || regexp_replace(p_phone, '\D', '', 'g'), 'utf8'),
        'sha256'
      ),
      'hex'
    )
  end;
$$;

revoke execute on function public.e164_phone_digest(text) from public, anon;
grant execute on function public.e164_phone_digest(text) to service_role;

-- ---------------------------------------------------------------------------
-- phone_hashes
-- ---------------------------------------------------------------------------
--
-- RLS on and **no policies at all**: nobody reads this table through PostgREST
-- ever, under any role. `match_contacts` reaches it as the definer, which is
-- the only access path that exists.
create table if not exists public.phone_hashes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone_hash text not null,
  updated_at timestamptz not null default now()
);

-- The matching join's whole query plan. Unique because two accounts cannot
-- verify the same number — Supabase enforces that on `auth.users.phone`, and
-- this keeps the invariant visible here too.
create unique index if not exists phone_hashes_hash_key
  on public.phone_hashes (phone_hash);

alter table public.phone_hashes enable row level security;

revoke all on table public.phone_hashes from public, anon, authenticated;

-- Written only from the phone the user actually verified. An unverified
-- `auth.users.phone` is a number somebody typed, not a number they hold, and
-- matching on it would let anyone claim anyone's contacts entry.
create or replace function public.sync_phone_hash()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_digest text;
  v_hash text;
begin
  if new.phone_confirmed_at is null or new.phone is null then
    delete from public.phone_hashes where user_id = new.id;
    return new;
  end if;

  v_digest := public.e164_phone_digest(new.phone);
  v_hash := public.peppered_phone_hash(v_digest);

  -- No pepper means the vault is not set up in this environment. A sign-up
  -- must not fail over a matching feature, so this warns and moves on; the
  -- row refills the next time the number is re-verified.
  if v_hash is null then
    raise warning 'contact_match_pepper missing; phone hash not stored for %', new.id;
    return new;
  end if;

  insert into public.phone_hashes (user_id, phone_hash, updated_at)
  values (new.id, v_hash, now())
  on conflict (user_id) do update
    set phone_hash = excluded.phone_hash,
        updated_at = excluded.updated_at;

  return new;
end;
$$;

revoke execute on function public.sync_phone_hash()
  from public, anon, authenticated, service_role;

drop trigger if exists on_auth_user_phone_verified on auth.users;
create trigger on_auth_user_phone_verified
  after insert or update of phone, phone_confirmed_at on auth.users
  for each row execute function public.sync_phone_hash();

-- Backfill: every already-verified number, hashed the same way. Empty on a
-- project whose accounts all signed in with Google or Apple, which is the
-- ordinary case today.
insert into public.phone_hashes (user_id, phone_hash, updated_at)
select u.id,
       public.peppered_phone_hash(public.e164_phone_digest(u.phone)),
       now()
  from auth.users u
 where u.phone is not null
   and u.phone_confirmed_at is not null
   and public.peppered_phone_hash(public.e164_phone_digest(u.phone)) is not null
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------------
-- friendships
-- ---------------------------------------------------------------------------

create table if not exists public.friendships (
  -- Ordered pair (D130): the smaller uuid is always `user_lo`, so one pair is
  -- one row no matter who asked.
  user_lo uuid not null references public.profiles(id) on delete cascade,
  user_hi uuid not null references public.profiles(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_lo, user_hi),
  constraint friendships_ordered check (user_lo < user_hi),
  constraint friendships_requester_in_pair
    check (requester_id = user_lo or requester_id = user_hi)
);

-- "Who are my friends" reaches the pair from either side, and the primary key
-- only serves the `user_lo` half.
create index if not exists friendships_user_hi_idx
  on public.friendships (user_hi);

drop trigger if exists friendships_touch_updated_at on public.friendships;
create trigger friendships_touch_updated_at
  before update on public.friendships
  for each row execute function public.touch_updated_at();

alter table public.friendships enable row level security;

-- A user sees only rows they are in. Nothing else on this table is readable —
-- the graph of who knows whom is not public.
drop policy if exists "own friendships select" on public.friendships;
create policy "own friendships select" on public.friendships
  for select to authenticated
  using (user_lo = (select auth.uid()) or user_hi = (select auth.uid()));

-- I may only create a request I am making, in a pair I am in, and it starts
-- pending. There is no way to insert an already-accepted friendship.
drop policy if exists "own friendships insert" on public.friendships;
create policy "own friendships insert" on public.friendships
  for insert to authenticated
  with check (
    requester_id = (select auth.uid())
    and (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
    and status = 'pending'
  );

-- Either party may change a row they are in, but **the requester cannot land
-- it on `accepted`**. That closes accepting your own request at the policy
-- level rather than only inside the RPC, which is where it has to be closed:
-- the RPC is the app's path, the policy is the boundary.
drop policy if exists "own friendships update" on public.friendships;
create policy "own friendships update" on public.friendships
  for update to authenticated
  using (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
  with check (
    (user_lo = (select auth.uid()) or user_hi = (select auth.uid()))
    and (status <> 'accepted' or requester_id <> (select auth.uid()))
  );

drop policy if exists "own friendships delete" on public.friendships;
create policy "own friendships delete" on public.friendships
  for delete to authenticated
  using (user_lo = (select auth.uid()) or user_hi = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- get_friends
-- ---------------------------------------------------------------------------
--
-- Security definer because `profiles` is owner-only and always will be: the
-- alternative is a select policy that lets any authenticated user read any
-- profile row, which would hand out every column on it. This hands out three
-- (D129).
create or replace function public.get_friends()
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
   where f.status = 'accepted'
     and ((select auth.uid()) in (f.user_lo, f.user_hi))
   order by p.name;
$$;

revoke execute on function public.get_friends() from public, anon;
grant execute on function public.get_friends() to authenticated, service_role;

-- Requests still waiting on somebody. `incoming` is true when the other person
-- asked me — the only rows that carry Accept and Decline.
create or replace function public.get_friend_requests()
returns table(id uuid, name text, avatar_url text, incoming boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id,
         p.name,
         p.avatar_url,
         f.requester_id <> (select auth.uid()) as incoming
    from public.friendships f
    join public.profiles p
      on p.id = case
                  when f.user_lo = (select auth.uid()) then f.user_hi
                  else f.user_lo
                end
   where f.status = 'pending'
     and ((select auth.uid()) in (f.user_lo, f.user_hi))
   order by p.name;
$$;

revoke execute on function public.get_friend_requests() from public, anon;
grant execute on function public.get_friend_requests() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- match_contacts
-- ---------------------------------------------------------------------------
--
-- Security definer, and the reason is the whole feature: it reads *other
-- people's* `phone_hashes` rows, which no policy grants and none should. It
-- returns the same three public columns as `get_friends` and nothing else — in
-- particular it never returns the hash it matched on, so a caller learns only
-- that somebody came back, not which of their guesses produced them.
--
-- Rate limited by shape: the array is capped at 500, and a caller who wanted
-- to walk the number space would have to do it 500 at a time against a
-- peppered hash they cannot compute themselves. Blocked pairs are excluded, so
-- blocking somebody also hides you from their address book.
create or replace function public.match_contacts(p_hashes text[])
returns table(id uuid, name text, avatar_url text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer := coalesce(array_length(p_hashes, 1), 0);
begin
  if v_uid is null then
    raise exception 'Matching contacts needs a signed-in caller.'
      using errcode = '28000';
  end if;

  if v_count > 500 then
    raise exception 'Too many contacts in one call (% sent, 500 allowed).', v_count
      using errcode = '22023';
  end if;

  if v_count = 0 then
    return;
  end if;

  return query
    select p.id, p.name, p.avatar_url
      from unnest(p_hashes) as h(client_hex)
      join public.phone_hashes ph
        on ph.phone_hash = public.peppered_phone_hash(h.client_hex)
      join public.profiles p on p.id = ph.user_id
     where ph.user_id <> v_uid
       and not exists (
         select 1
           from public.friendships f
          where f.status = 'blocked'
            and f.user_lo = least(v_uid, ph.user_id)
            and f.user_hi = greatest(v_uid, ph.user_id)
       )
     order by p.name;
end;
$$;

revoke execute on function public.match_contacts(text[]) from public, anon;
grant execute on function public.match_contacts(text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- friend_request
-- ---------------------------------------------------------------------------
--
-- One RPC with an action rather than four (D131). Send, accept, decline and
-- remove are the same statement against the same primary key with a different
-- verb, and four functions would be four places to get the pair ordering
-- wrong. `block` is here too because the status exists and a status nothing
-- can reach is dead schema.
--
-- Security **invoker**: every write it makes is one the caller's own policies
-- already allow, so RLS stays the boundary and this function is only the
-- convenience of not making the client compute `least`/`greatest`.
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

  case p_action
    when 'send' then
      insert into public.friendships as f (user_lo, user_hi, requester_id, status)
      values (v_lo, v_hi, v_uid, 'pending')
      -- Asking somebody who already asked you is an accept: the pair is there,
      -- they requested it, and the natural reading of the tap is "yes".
      on conflict (user_lo, user_hi) do update
        set status = case
              when f.status = 'blocked' then f.status
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
         and status <> 'blocked'
      returning * into v_row;

    when 'block' then
      insert into public.friendships as f (user_lo, user_hi, requester_id, status)
      values (v_lo, v_hi, v_uid, 'pending')
      on conflict (user_lo, user_hi) do update
        set status = 'blocked', requester_id = v_uid
      returning * into v_row;

      -- The insert path lands on 'pending' because the insert policy insists
      -- on it; blocking a stranger is a second statement rather than a looser
      -- policy.
      if v_row.status <> 'blocked' then
        update public.friendships
           set status = 'blocked'
         where user_lo = v_lo and user_hi = v_hi
        returning * into v_row;
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
