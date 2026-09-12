-- A plan can reach a phone (D152).
--
-- Invites have worked since Phase 7 and nobody was ever told. The missing
-- piece is small on purpose: one table of device tokens, one trigger, and an
-- edge function that does the talking to Firebase. No queue table, no
-- outbox, no retry ladder — three events a dinner is not a pipeline.
--
--   * **The database sends it, not the client.** A push that the inviter's
--     phone had to fire would arrive only while that phone was awake and
--     online, and would have to hold a key that lets it push to somebody
--     else. The trigger is the one place that sees every one of the three
--     moments, whichever screen or RPC caused it.
--   * **A push must never fail the write.** The whole body sits inside
--     `exception when others then raise warning`: if the vault is empty, if
--     `net` is unhappy, if Firebase is down, the invite still lands. A guest
--     who was not told is a worse product; a guest who was not *invited* is a
--     bug.
--   * **Inert until the owner sets the secrets** — the same shape as the
--     thumbnail cron (see `20260823073618_reschedule_thumbnail_refresh_
--     portable.sql`). `push_url` and `push_key` are read from this
--     environment's vault at fire time; missing either, the trigger returns
--     without sending. A local stack, a branch, or a fresh restore therefore
--     never pushes at production's users.
--
-- Bootstrap per environment (see docs/General/RUNBOOK.md §5):
--   select vault.create_secret('<random hex>', 'push_key');
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/send-push', 'push_url');

-- ---------------------------------------------------------------------------
-- Device tokens
-- ---------------------------------------------------------------------------
--
-- The token is the primary key, not a surrogate with a unique index on top:
-- a token *is* the identity of an install, and the same token moving to
-- another account (a shared phone, a re-login) must move the row rather than
-- leave a second one pointing at the old owner.
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text check (platform in ('ios', 'android')),
  updated_at timestamptz default now()
);

-- "Where do I send this person's push?" — the only read the edge function makes.
create index if not exists push_tokens_user_idx
  on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- Owner-only, one policy for every verb: a device registers and unregisters
-- itself. Nothing signed in has any business reading another account's
-- tokens, and the sender is `service_role`, which RLS does not apply to.
drop policy if exists "own push tokens all" on public.push_tokens;
create policy "own push tokens all" on public.push_tokens
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- The trigger that does the telling
-- ---------------------------------------------------------------------------
--
-- Three moments, named once here and read by `supabase/functions/send-push`:
--
--   | type           | fires on                          | who is told   |
--   |----------------|-----------------------------------|---------------|
--   | plan_invite    | insert at 'invited'               | `user_id`     |
--   | join_request   | insert at 'requested'             | plan's owner  |
--   | join_accepted  | 'requested' → 'going'             | `user_id`     |
--
-- The payload always carries the *row's* `user_id`, never the recipient's:
-- the function resolves who to wake from the type, so the two sides cannot
-- drift into disagreeing about whose id is in the envelope.
--
-- Definer because it reads the vault, and execute is revoked from every API
-- role — a trigger function is called by the trigger, not over REST, and
-- `authenticated` holding EXECUTE on a definer function is an advisor finding
-- with nothing behind it. Same idiom as `handle_new_user`.
create or replace function public.notify_plan_member_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_url text;
  v_key text;
begin
  begin
    if tg_op = 'INSERT' and new.status = 'invited' then
      v_type := 'plan_invite';
    elsif tg_op = 'INSERT' and new.status = 'requested' then
      v_type := 'join_request';
    elsif tg_op = 'UPDATE' and new.status = 'going'
          and old.status = 'requested' then
      v_type := 'join_accepted';
    else
      -- Declining, being un-invited, an owner re-saving the same row: real
      -- changes, none of them worth a buzz in somebody's pocket.
      return new;
    end if;

    select decrypted_secret into v_url
      from vault.decrypted_secrets where name = 'push_url';
    select decrypted_secret into v_key
      from vault.decrypted_secrets where name = 'push_key';

    if v_url is null or v_key is null then
      return new;
    end if;

    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-key', v_key
      ),
      body := jsonb_build_object(
        'type', v_type,
        'plan_id', new.plan_id,
        'user_id', new.user_id
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'push for plan % (%) skipped: %', new.plan_id, v_type, sqlerrm;
  end;

  return new;
end;
$$;

revoke execute on function public.notify_plan_member_change()
  from public, anon, authenticated;

-- `of status` rather than a bare update: a re-save that leaves the status
-- alone is not news, and the trigger would otherwise have to work that out
-- for itself on every write.
drop trigger if exists plan_members_notify on public.plan_members;
create trigger plan_members_notify
  after insert or update of status on public.plan_members
  for each row execute function public.notify_plan_member_change();
