-- Ngap redesign, phase A: the facts the detail screen, the swipe card and the
-- Nearby map show. Applied to the project on 2026-09-05 via the Supabase MCP;
-- this file is the same SQL so a local stack or `supabase db reset` matches.
--
-- Additive only. The captions already carried an opening span (⏰), a price
-- (RM …), a halal statement and an address with a postcode; the DO block at
-- the end parses them once into nullable columns. `hours_text` keeps the
-- caption's line verbatim so a bad parse can be redone. Anything the caption
-- does not say stays null and the client hides it. See
-- docs/Features/Restaurant-Data.md §2a (D91, D92).

alter table public.restaurants
  add column if not exists hours_text text,
  add column if not exists opens_at time,
  add column if not exists closes_at time,
  add column if not exists closed_dow smallint[] not null default '{}',
  add column if not exists price_from integer
    check (price_from is null or price_from >= 0),
  add column if not exists is_halal boolean,
  add column if not exists neighbourhood text;

comment on column public.restaurants.hours_text is
  'The opening-hours line as the source caption wrote it (after the clock emoji). Kept verbatim so a bad parse can be redone.';
comment on column public.restaurants.opens_at is
  'Daily opening time, local (Asia/Kuala_Lumpur). Null when the caption gave none.';
comment on column public.restaurants.closes_at is
  'Daily closing time, local. Earlier than opens_at means the span runs past midnight; equal to opens_at means 24 hours.';
comment on column public.restaurants.closed_dow is
  'ISO weekdays (1 = Monday … 7 = Sunday) the place is closed. Empty when it never says.';
comment on column public.restaurants.price_from is
  'Lowest RM figure the caption mentions — a dish price, not a per-person band. Null when it names none.';
comment on column public.restaurants.is_halal is
  'True when the caption says halal, false when it says non-halal, null when it does not say. Not a certification check.';
comment on column public.restaurants.neighbourhood is
  'Town or suburb after the postcode in the caption address. Null when the caption carried no address.';

-- Dishes: "What people bite" on the detail screen. Empty until curated;
-- the client hides the section when a restaurant has none.
create table if not exists public.dishes (
  id bigint generated always as identity primary key,
  restaurant_id bigint not null references public.restaurants(id) on delete cascade,
  name text not null,
  description text not null default '',
  price_rm numeric(8,2) check (price_rm is null or price_rm >= 0),
  image_url text,
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists dishes_restaurant_position_idx
  on public.dishes (restaurant_id, position);

alter table public.dishes enable row level security;

drop policy if exists "read dishes of active restaurants" on public.dishes;
create policy "read dishes of active restaurants"
  on public.dishes for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = dishes.restaurant_id and r.is_active
    )
  );

-- Open right now? Evaluated in Kuala Lumpur time like deck_scored. Null when
-- the hours are unknown, so the client can hide the chip rather than lie.
-- Weekdays are ISO (isodow) to match Dart's DateTime.weekday.
create or replace function public.is_open_at(
  p_opens time,
  p_closes time,
  p_closed smallint[],
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
set search_path to ''
as $$
declare
  v_local timestamp := p_at at time zone 'Asia/Kuala_Lumpur';
  v_time time := v_local::time;
  v_dow smallint := extract(isodow from v_local)::smallint;
  v_yesterday smallint := extract(isodow from v_local - interval '1 day')::smallint;
  v_closed smallint[] := coalesce(p_closed, '{}');
begin
  if p_opens is null or p_closes is null then
    return null;
  end if;
  if p_opens = p_closes then
    return not (v_dow = any (v_closed));
  end if;
  if p_closes > p_opens then
    return v_time >= p_opens and v_time < p_closes
       and not (v_dow = any (v_closed));
  end if;
  -- Overnight span, e.g. 17:30 → 02:00. Before midnight it is today's
  -- opening; after midnight it belongs to yesterday's.
  return (v_time >= p_opens and not (v_dow = any (v_closed)))
      or (v_time < p_closes and not (v_yesterday = any (v_closed)));
end $$;

-- How many people have bitten a place. swipes is own-rows-only under RLS,
-- so the aggregate needs definer rights; it returns a single number and
-- nothing about who.
create or replace function public.get_ngap_count(p_restaurant_id bigint)
returns bigint
language sql
stable
security definer
set search_path to ''
as $$
  select count(*)
  from public.swipes s
  where s.restaurant_id = p_restaurant_id and s.liked;
$$;

revoke all on function public.get_ngap_count(bigint) from public;
grant execute on function public.get_ngap_count(bigint) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Backfill: parse the caption once. Idempotent — re-running rewrites the same
-- values from the same captions.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  v_raw text;
  m text[];
  v_open_h int; v_open_m int; v_open_ap text;
  v_close_h int; v_close_m int; v_close_ap text;
  v_opens time; v_closes time;
  v_closed smallint[];
  v_after text;
  d text[];
  v_price int;
  v_halal boolean;
  v_hood text;
begin
  for r in select id, details from public.restaurants loop
    v_opens := null; v_closes := null; v_closed := '{}'; v_raw := null;

    -- hours: the text after the clock emoji, up to the next emoji-led field
    if r.details ~ '⏰' then
      v_raw := trim(substring(r.details from '⏰\s*([^⏰📍🔥💚🇲🇾📞☎️🍽️✨]{1,160})'));
      v_raw := regexp_replace(v_raw, '\s*(Find out more|Save up to|Book now|Follow).*$', '', 'i');
      v_raw := trim(v_raw);

      m := regexp_match(v_raw,
        '(\d{1,2})(?:[:.](\d{2}))?\s*([ap]\.?m\.?)?\s*(?:-|–|—|to|until|till|hingga|~)\s*(\d{1,2})(?:[:.](\d{2}))?\s*([ap]\.?m\.?)',
        'i');
      if m is not null then
        v_open_h := m[1]::int; v_open_m := coalesce(m[2], '0')::int;
        v_open_ap := lower(replace(coalesce(m[3], ''), '.', ''));
        v_close_h := m[4]::int; v_close_m := coalesce(m[5], '0')::int;
        v_close_ap := lower(replace(m[6], '.', ''));
        -- an opening time with no am/pm: morning if the hour reads like one
        if v_open_ap = '' then
          v_open_ap := case when v_open_h between 5 and 11 then 'am' else 'pm' end;
        end if;
        if v_open_h between 1 and 12 and v_close_h between 1 and 12
           and v_open_m between 0 and 59 and v_close_m between 0 and 59 then
          v_open_h := (v_open_h % 12) + case when v_open_ap = 'pm' then 12 else 0 end;
          v_close_h := (v_close_h % 12) + case when v_close_ap = 'pm' then 12 else 0 end;
          v_opens := make_time(v_open_h, v_open_m, 0);
          v_closes := make_time(v_close_h, v_close_m, 0);
        end if;
      end if;

      -- closed days, English or Malay, after "closed"/"tutup"/"off day"
      v_after := substring(v_raw from '(?i)(?:closed|tutup|off day|rest day|cuti)(.{0,80})');
      if v_after is not null then
        for d in select regexp_matches(v_after,
            '(mon|tue|wed|thu|fri|sat|sun|isnin|selasa|rabu|khamis|jumaat|sabtu|ahad)', 'gi') loop
          v_closed := v_closed || case lower(d[1])
            when 'mon' then 1 when 'isnin' then 1
            when 'tue' then 2 when 'selasa' then 2
            when 'wed' then 3 when 'rabu' then 3
            when 'thu' then 4 when 'khamis' then 4
            when 'fri' then 5 when 'jumaat' then 5
            when 'sat' then 6 when 'sabtu' then 6
            else 7 end::smallint;
        end loop;
        select array_agg(distinct x order by x) into v_closed from unnest(v_closed) x;
        v_closed := coalesce(v_closed, '{}');
      end if;
    end if;

    -- price: the lowest RM figure named
    select min(p::int) into v_price
    from (
      select (regexp_matches(r.details, 'RM\s?(\d{1,4})(?:\.\d+)?', 'gi'))[1] p
    ) s
    where p::int >= 1;

    -- halal: only what the caption states
    v_halal := case
      when r.details ~* 'non[- ]?halal|not halal|bukan halal' then false
      when r.details ~* '\mhalal\M' then true
      else null end;

    -- neighbourhood: the town after the postcode
    v_hood := substring(r.details from '\d{5},?\s+([A-Z][A-Za-z''.]+(?:\s+[A-Z][A-Za-z''.]+){0,2})');
    if v_hood is not null then
      v_hood := regexp_replace(v_hood, '\s+(Johor|Pulau|Penang|Kedah|Perak|Selangor|Kuala|Perlis|Malaysia|Darul|Dahrul|Daerah)\M.*$', '');
      v_hood := nullif(trim(v_hood), '');
      if v_hood in ('Johor', 'Pulau', 'Penang', 'Kedah', 'Perak', 'Malaysia', 'Perlis', 'Selangor') then
        v_hood := null;
      end if;
    end if;

    update public.restaurants set
      hours_text = v_raw,
      opens_at = v_opens,
      closes_at = v_closes,
      closed_dow = v_closed,
      price_from = v_price,
      is_halal = v_halal,
      neighbourhood = v_hood
    where id = r.id;
  end loop;
end $$;

-- Second pass, after eyeballing the first: "24 hours" / "24 Jam" is an
-- all-day span; a clock line with no digit is not hours at all; a
-- "neighbourhood" that is a street or shouting is not a neighbourhood.
update public.restaurants set
  opens_at = case when hours_text ~* '24\s*(hours|hrs|jam|h\M|/7)' then '00:00'::time else opens_at end,
  closes_at = case when hours_text ~* '24\s*(hours|hrs|jam|h\M|/7)' then '00:00'::time else closes_at end
where hours_text is not null and opens_at is null;

update public.restaurants set hours_text = null
where hours_text is not null and hours_text !~ '\d';

update public.restaurants set neighbourhood = null
where neighbourhood is not null
  and (neighbourhood ~* '^(jalan|persiaran|lorong|email|lot|no\.?)\M' or neighbourhood = upper(neighbourhood));
