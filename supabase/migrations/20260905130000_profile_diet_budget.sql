-- Diet & budget preferences: the first-run "Any rules?" step (design 01e) and
-- the You tab's "Your taste" list (design S10).
--
-- Applied to the live project as the `profile_diet_budget` migration; kept
-- here verbatim so `supabase db reset` and a local stack land on the same
-- schema as production.
--
-- Two things in here are worth reading before changing them:
--
--   * spice_level 1–4 is the stored truth and spice_bias is derived from it on
--     every write (D104). deck_scored's spice term still reads spice_bias, so
--     writing both keeps the existing ranking working without a second pass
--     over the scoring function.
--   * update_preferences and complete_onboarding are DROPped and recreated
--     rather than CREATE OR REPLACEd. Postgres identifies a function by its
--     argument list, so appending parameters to a replace would leave the old
--     function behind as an overload and make every named-argument call
--     ambiguous ("function is not unique"). Every parameter of the old
--     signature survives on the new one, in the same order, so no caller has
--     to change — and both statements are in one transaction, so the function
--     is never missing.

alter table public.profiles
  add column if not exists halal_only boolean not null default false,
  add column if not exists vegetarian boolean not null default false,
  add column if not exists spice_level smallint,
  add column if not exists budget_min integer,
  add column if not exists budget_max integer;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_spice_level_check'
  ) then
    alter table public.profiles
      add constraint profiles_spice_level_check
      check (spice_level between 1 and 4);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_budget_check'
  ) then
    alter table public.profiles
      add constraint profiles_budget_check check (
        (budget_min is null or budget_min >= 0)
        and (budget_max is null or budget_max >= 0)
        and (budget_min is null or budget_max is null or budget_min <= budget_max)
      );
  end if;
end $$;

comment on column public.profiles.halal_only is
  'Hard deck filter: only restaurants with is_halal = true are served. Off by '
  'default because is_halal is unknown for most of the catalogue, so turning '
  'it on legitimately empties the deck rather than silently narrowing it.';
comment on column public.profiles.vegetarian is
  'Hard deck filter: the restaurant must carry the "vegetarian" dietary tag.';
comment on column public.profiles.spice_level is
  '1 Mild, 2 Medium, 3 Pedas, 4 Bring it. Null = never answered. The stored '
  'truth; spice_bias is derived from it on every write (D104).';
comment on column public.profiles.budget_min is
  'Ringgit per person, lower end of the answered range. Null = no answer.';
comment on column public.profiles.budget_max is
  'Ringgit per person, upper cap. Null with a non-null budget_min means "and '
  'up" — the deck then applies no price ceiling. Rows with an unknown '
  'price_from always pass the filter (D105).';

-- ---------------------------------------------------------------------------
-- update_preferences — same name, superset of parameters.
-- ---------------------------------------------------------------------------
drop function if exists public.update_preferences(
  text, boolean, text, boolean, integer, boolean, bigint[], bigint[]
);

create or replace function public.update_preferences(
  p_name text default null,
  p_morning_mode boolean default null,
  p_spice_bias text default null,
  p_nearby_focus boolean default null,
  p_radius_km integer default null,
  p_clear_radius boolean default false,
  p_cuisine_ids bigint[] default null,
  p_dietary_ids bigint[] default null,
  p_halal_only boolean default null,
  p_vegetarian boolean default null,
  p_spice_level smallint default null,
  p_budget_min integer default null,
  p_budget_max integer default null,
  p_clear_budget boolean default false
)
returns public.profiles
language plpgsql
set search_path to ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'update_preferences requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set name = coalesce(nullif(btrim(p_name), ''), p.name),
         morning_mode = coalesce(p_morning_mode, p.morning_mode),
         -- spice_level is what the app asks for; spice_bias is derived from it
         -- so the deck's existing three-way term keeps scoring (D104). The
         -- legacy p_spice_bias still works for callers that have not moved.
         spice_level = coalesce(p_spice_level, p.spice_level),
         spice_bias = coalesce(
           case p_spice_level
             when 1 then 'low'
             when 2 then 'medium'
             when 3 then 'high'
             when 4 then 'high'
           end,
           p_spice_bias,
           p.spice_bias
         ),
         nearby_focus = coalesce(p_nearby_focus, p.nearby_focus),
         halal_only = coalesce(p_halal_only, p.halal_only),
         vegetarian = coalesce(p_vegetarian, p.vegetarian),
         search_radius_km = case
           when coalesce(p_clear_radius, false) then null
           else coalesce(p_radius_km, p.search_radius_km)
         end,
         -- The two budget ends move together: "RM 10 and up" is a null cap
         -- with a real floor, which a per-column coalesce could never express.
         -- So a non-null p_budget_min makes the pair authoritative, and
         -- p_clear_budget is the only way back to "no answer".
         budget_min = case
           when coalesce(p_clear_budget, false) then null
           when p_budget_min is not null then p_budget_min
           else p.budget_min
         end,
         budget_max = case
           when coalesce(p_clear_budget, false) then null
           when p_budget_min is not null then p_budget_max
           else p.budget_max
         end
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  if p_cuisine_ids is not null then
    delete from public.profile_cuisines pc
     where pc.profile_id = v_user
       and pc.cuisine_id <> all (p_cuisine_ids);

    insert into public.profile_cuisines (profile_id, cuisine_id)
    select v_user, unnest(p_cuisine_ids)
    on conflict (profile_id, cuisine_id) do nothing;
  end if;

  if p_dietary_ids is not null then
    delete from public.profile_dietary_tags pdt
     where pdt.profile_id = v_user
       and pdt.dietary_tag_id <> all (p_dietary_ids);

    insert into public.profile_dietary_tags (profile_id, dietary_tag_id)
    select v_user, unnest(p_dietary_ids)
    on conflict (profile_id, dietary_tag_id) do nothing;
  end if;

  return v_profile;
end $function$;

revoke all on function public.update_preferences(
  text, boolean, text, boolean, integer, boolean, bigint[], bigint[],
  boolean, boolean, smallint, integer, integer, boolean
) from public;
grant execute on function public.update_preferences(
  text, boolean, text, boolean, integer, boolean, bigint[], bigint[],
  boolean, boolean, smallint, integer, integer, boolean
) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- complete_onboarding — same treatment.
-- ---------------------------------------------------------------------------
drop function if exists public.complete_onboarding(
  text, bigint[], bigint[], boolean, text, boolean, integer,
  double precision, double precision, text, text
);

create or replace function public.complete_onboarding(
  p_name text default null,
  p_cuisine_ids bigint[] default null,
  p_dietary_ids bigint[] default null,
  p_morning_mode boolean default null,
  p_spice_bias text default null,
  p_nearby_focus boolean default null,
  p_radius_km integer default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_place_name text default null,
  p_location_source text default null,
  p_halal_only boolean default null,
  p_vegetarian boolean default null,
  p_spice_level smallint default null,
  p_budget_min integer default null,
  p_budget_max integer default null,
  p_clear_budget boolean default false
)
returns public.profiles
language plpgsql
set search_path to ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'complete_onboarding requires an authenticated user'
      using errcode = '42501';
  end if;

  update public.profiles p
     set name = coalesce(nullif(btrim(p_name), ''), p.name),
         morning_mode = coalesce(p_morning_mode, p.morning_mode),
         spice_level = coalesce(p_spice_level, p.spice_level),
         spice_bias = coalesce(
           case p_spice_level
             when 1 then 'low'
             when 2 then 'medium'
             when 3 then 'high'
             when 4 then 'high'
           end,
           p_spice_bias,
           p.spice_bias
         ),
         nearby_focus = coalesce(p_nearby_focus, p.nearby_focus),
         halal_only = coalesce(p_halal_only, p.halal_only),
         vegetarian = coalesce(p_vegetarian, p.vegetarian),
         -- radius is nullable on purpose ("No limit"), so an explicit null
         -- from the wizard must be able to clear it
         search_radius_km = p_radius_km,
         -- likewise the budget: the wizard writes the whole answer once, and
         -- a skipped step has to leave "no answer" behind rather than a range
         -- the user never chose.
         budget_min = case
           when coalesce(p_clear_budget, false) then null else p_budget_min end,
         budget_max = case
           when coalesce(p_clear_budget, false) then null else p_budget_max end,
         last_latitude = coalesce(p_latitude, p.last_latitude),
         last_longitude = coalesce(p_longitude, p.last_longitude),
         last_place_name = coalesce(p_place_name, p.last_place_name),
         located_at = case
           when p_latitude is not null and p_longitude is not null
           then pg_catalog.now() else p.located_at end,
         location_source = coalesce(p_location_source, p.location_source),
         onboarded_at = coalesce(p.onboarded_at, pg_catalog.now())
   where p.id = v_user
   returning p.* into v_profile;

  if not found then
    raise exception 'profile % not found', v_user using errcode = 'P0002';
  end if;

  if p_cuisine_ids is not null then
    delete from public.profile_cuisines pc
     where pc.profile_id = v_user
       and pc.cuisine_id <> all (p_cuisine_ids);

    insert into public.profile_cuisines (profile_id, cuisine_id)
    select v_user, unnest(p_cuisine_ids)
    on conflict (profile_id, cuisine_id) do nothing;
  end if;

  if p_dietary_ids is not null then
    delete from public.profile_dietary_tags pdt
     where pdt.profile_id = v_user
       and pdt.dietary_tag_id <> all (p_dietary_ids);

    insert into public.profile_dietary_tags (profile_id, dietary_tag_id)
    select v_user, unnest(p_dietary_ids)
    on conflict (profile_id, dietary_tag_id) do nothing;
  end if;

  return v_profile;
end $function$;

revoke all on function public.complete_onboarding(
  text, bigint[], bigint[], boolean, text, boolean, integer,
  double precision, double precision, text, text,
  boolean, boolean, smallint, integer, integer, boolean
) from public;
grant execute on function public.complete_onboarding(
  text, bigint[], bigint[], boolean, text, boolean, integer,
  double precision, double precision, text, text,
  boolean, boolean, smallint, integer, integer, boolean
) to anon, authenticated, service_role;
