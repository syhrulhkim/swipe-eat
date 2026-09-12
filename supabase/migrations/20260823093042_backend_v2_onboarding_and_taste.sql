-- Backend v2, phase 1: the account record grows the onboarding state, the
-- location it was last seen at, and a taste vocabulary the deck ranker can
-- score against. Until now a profile held three preference toggles that
-- nothing wrote to, likes lived in device storage, and "nearby" was decided on
-- the phone.

-- ============ profiles: onboarding + location ============
alter table public.profiles
  add column avatar_url text,
  -- null = onboarding still owed; the router gate reads exactly this
  add column onboarded_at timestamptz,
  -- Hard search radius the user sets in Settings: only places within this many
  -- km of their detected location are served. null = no limit (show
  -- everything, including the 85 catalog rows that have no coordinates).
  add column search_radius_km int default 15
    check (search_radius_km is null or search_radius_km between 1 and 200),
  add column last_latitude double precision
    check (last_latitude between -90 and 90),
  add column last_longitude double precision
    check (last_longitude between -180 and 180),
  -- Reverse-geocoded label for the header chip ('Peserai, Batu Pahat'),
  -- resolved on the device and stored here so every surface agrees on it.
  add column last_place_name text,
  add column located_at timestamptz,
  -- 'denied' is a real answer, not a missing one: it tells the ranker to stop
  -- scoring proximity instead of waiting for coordinates that never arrive.
  add column location_source text not null default 'unknown'
    check (location_source in ('unknown', 'gps', 'manual', 'denied'));

-- updated_at existed since the init migration but nothing maintained it.
create function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

revoke execute on function public.touch_updated_at() from public, anon, authenticated;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Social signups (Google/Apple) carry their name and photo in user metadata
-- under different keys than an email signup does.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'name', ''),
      nullif(new.raw_user_meta_data->>'full_name', ''),
      'User'
    ),
    coalesce(
      nullif(new.raw_user_meta_data->>'avatar_url', ''),
      nullif(new.raw_user_meta_data->>'picture', '')
    )
  );
  return new;
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ============ taste vocabulary ============
-- restaurants.tag is scraped free text (70 distinct values: 'Malay', 'Cafe',
-- 'Food', 'Lepak', ...). It is fine as a display badge and useless as a
-- preference key, so the catalog below is the stable vocabulary and
-- cuisine_aliases maps the scraped tags onto it.
create table public.cuisines (
  id bigint generated always as identity primary key,
  slug text not null unique,
  label text not null,
  emoji text,
  -- ranking inputs, kept as data so the deck function has no hardcoded slugs
  is_breakfast boolean not null default false,
  spice_level smallint not null default 0 check (spice_level between 0 and 2),
  position int not null default 0,
  is_active boolean not null default true
);

create table public.cuisine_aliases (
  alias text primary key,               -- lower(trim(restaurants.tag))
  cuisine_id bigint not null references public.cuisines (id) on delete cascade
);

create index cuisine_aliases_cuisine_id_idx on public.cuisine_aliases (cuisine_id);

create table public.restaurant_cuisines (
  restaurant_id bigint not null
    references public.restaurants (id) on delete cascade,
  cuisine_id bigint not null references public.cuisines (id) on delete cascade,
  -- 'tag' rows are derived and re-derived from restaurants.tag; 'manual' rows
  -- are curation the trigger below must never clobber.
  source text not null default 'tag' check (source in ('tag', 'manual')),
  primary key (restaurant_id, cuisine_id)
);

create index restaurant_cuisines_cuisine_id_idx
  on public.restaurant_cuisines (cuisine_id);

create table public.dietary_tags (
  id bigint generated always as identity primary key,
  slug text not null unique,
  label text not null,
  position int not null default 0
);

-- No dietary data exists on the catalog yet, so this table starts empty and
-- the ranker treats a dietary pick as a boost where it matches, never as a
-- filter — filtering on absent data would empty the deck.
create table public.restaurant_dietary_tags (
  restaurant_id bigint not null
    references public.restaurants (id) on delete cascade,
  dietary_tag_id bigint not null
    references public.dietary_tags (id) on delete cascade,
  primary key (restaurant_id, dietary_tag_id)
);

create index restaurant_dietary_tags_tag_idx
  on public.restaurant_dietary_tags (dietary_tag_id);

-- ============ per-user taste picks (onboarding step 2) ============
create table public.profile_cuisines (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  cuisine_id bigint not null references public.cuisines (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, cuisine_id)
);

create index profile_cuisines_cuisine_id_idx
  on public.profile_cuisines (cuisine_id);

create table public.profile_dietary_tags (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  dietary_tag_id bigint not null
    references public.dietary_tags (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, dietary_tag_id)
);

create index profile_dietary_tags_tag_idx
  on public.profile_dietary_tags (dietary_tag_id);

-- ============ swipes: carry the context of the decision ============
alter table public.swipes
  add column source text not null default 'deck'
    check (source in ('deck', 'explore', 'detail', 'likes')),
  add column swiped_at_latitude double precision
    check (swiped_at_latitude between -90 and 90),
  add column swiped_at_longitude double precision
    check (swiped_at_longitude between -180 and 180),
  add column updated_at timestamptz not null default now();

-- Like tab reads newest-first; the deck excludes everything already swiped.
create index swipes_user_created_idx on public.swipes (user_id, created_at desc);

create trigger swipes_touch_updated_at
  before update on public.swipes
  for each row execute function public.touch_updated_at();

-- ============ RLS ============
alter table public.cuisines enable row level security;
alter table public.cuisine_aliases enable row level security;
alter table public.restaurant_cuisines enable row level security;
alter table public.dietary_tags enable row level security;
alter table public.restaurant_dietary_tags enable row level security;
alter table public.profile_cuisines enable row level security;
alter table public.profile_dietary_tags enable row level security;

-- catalog: world-readable, written only by migrations / service_role
create policy "read cuisines" on public.cuisines
  for select to anon, authenticated using (is_active);
create policy "read cuisine aliases" on public.cuisine_aliases
  for select to anon, authenticated using (true);
create policy "read restaurant cuisines" on public.restaurant_cuisines
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = public.restaurant_cuisines.restaurant_id and r.is_active
    )
  );
create policy "read dietary tags" on public.dietary_tags
  for select to anon, authenticated using (true);
create policy "read restaurant dietary tags" on public.restaurant_dietary_tags
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = public.restaurant_dietary_tags.restaurant_id and r.is_active
    )
  );

-- per-user picks: owner-only, full CRUD (the wizard rewrites the whole set)
create policy "own cuisine picks" on public.profile_cuisines
  for all to authenticated
  using (public.profile_cuisines.profile_id = (select auth.uid()))
  with check (public.profile_cuisines.profile_id = (select auth.uid()));

create policy "own dietary picks" on public.profile_dietary_tags
  for all to authenticated
  using (public.profile_dietary_tags.profile_id = (select auth.uid()))
  with check (public.profile_dietary_tags.profile_id = (select auth.uid()));

-- ============ catalog seed (idempotent) ============
insert into public.cuisines (slug, label, emoji, is_breakfast, spice_level, position)
values
  ('malay',          'Malay',          '🍛', false, 2,  1),
  ('cafe',           'Cafe',           '☕', true,  0,  2),
  ('chinese',        'Chinese',        '🥢', false, 0,  3),
  ('indian',         'Indian',         '🍲', false, 2,  4),
  ('western',        'Western',        '🍽️', false, 0,  5),
  ('japanese',       'Japanese',       '🍣', false, 0,  6),
  ('korean',         'Korean',         '🍚', false, 1,  7),
  ('thai',           'Thai',           '🌶️', false, 2,  8),
  ('vietnamese',     'Vietnamese',     '🍜', false, 0,  9),
  ('indonesian',     'Indonesian',     '🥘', false, 1, 10),
  ('seafood',        'Seafood',        '🦐', false, 1, 11),
  ('noodles',        'Noodles',        '🍝', false, 0, 12),
  ('soup',           'Soup',           '🍲', false, 0, 13),
  ('fried-chicken',  'Fried chicken',  '🍗', false, 1, 14),
  ('burger',         'Burgers',        '🍔', false, 0, 15),
  ('pizza',          'Pizza',          '🍕', false, 0, 16),
  ('bakery',         'Bakery',         '🥐', true,  0, 17),
  ('breakfast',      'Breakfast',      '🍳', true,  0, 18),
  ('dessert',        'Dessert',        '🍨', false, 0, 19),
  ('beverage',       'Drinks',         '🧋', true,  0, 20),
  ('mexican',        'Mexican',        '🌮', false, 1, 21),
  ('middle-eastern', 'Middle Eastern', '🥙', false, 1, 22),
  ('vegetarian',     'Vegetarian',     '🥗', false, 0, 23)
on conflict (slug) do nothing;

-- Generic tags ('food', 'restaurant', 'dining', 'buffet', 'asian', 'snack')
-- are deliberately unmapped: an unmapped restaurant simply scores 0 on taste
-- rather than being mislabelled.
insert into public.cuisine_aliases (alias, cuisine_id)
select v.alias, c.id
from (values
  ('malay', 'malay'), ('malaysian', 'malay'), ('nasi lemak', 'malay'),
  ('asam pedas', 'malay'), ('warung', 'malay'), ('local', 'malay'),
  ('mee rebus', 'malay'), ('satay', 'malay'), ('nyonya', 'malay'),
  ('rojak', 'malay'), ('laksa', 'malay'),
  ('cafe', 'cafe'), ('kopitiam', 'cafe'), ('lepak', 'cafe'),
  ('bistro', 'cafe'), ('japanese cafe', 'cafe'), ('matcha', 'cafe'),
  ('coffee', 'cafe'),
  ('chinese', 'chinese'), ('hotpot', 'chinese'), ('stir fry', 'chinese'),
  ('taiwanese', 'chinese'), ('chinese-muslim', 'chinese'),
  ('soup bun', 'chinese'), ('kolok mee', 'chinese'), ('lok lok', 'chinese'),
  ('indian', 'indian'), ('banana leaf', 'indian'), ('briyani', 'indian'),
  ('curry', 'indian'), ('curry noodle', 'indian'), ('indian fusion', 'indian'),
  ('western', 'western'), ('steakhouse', 'western'), ('british', 'western'),
  ('bbq', 'western'),
  ('japanese', 'japanese'), ('ramen', 'japanese'),
  ('korean', 'korean'),
  ('thai', 'thai'),
  ('vietnamese', 'vietnamese'),
  ('indonesian', 'indonesian'),
  ('seafood', 'seafood'),
  ('noodles', 'noodles'),
  ('soup', 'soup'),
  ('fried chicken', 'fried-chicken'),
  ('burger', 'burger'), ('fast food', 'burger'),
  ('pizza', 'pizza'), ('italian', 'pizza'),
  ('bakery', 'bakery'), ('bread', 'bakery'), ('donut', 'bakery'),
  ('breakfast', 'breakfast'),
  ('dessert', 'dessert'), ('cendol', 'dessert'), ('durian', 'dessert'),
  ('beverage', 'beverage'),
  ('mexican', 'mexican'), ('tacos', 'mexican'), ('quesillo', 'mexican'),
  ('middle eastern', 'middle-eastern'),
  ('vegetarian', 'vegetarian')
) as v (alias, slug)
join public.cuisines c on c.slug = v.slug
on conflict (alias) do nothing;

insert into public.dietary_tags (slug, label, position)
values
  ('halal',       'Halal',        1),
  ('vegetarian',  'Vegetarian',   2),
  ('vegan',       'Vegan',        3),
  ('no-pork',     'No pork',      4),
  ('no-beef',     'No beef',      5),
  ('gluten-free', 'Gluten free',  6)
on conflict (slug) do nothing;

-- Backfill the catalog links from the scraped tags.
insert into public.restaurant_cuisines (restaurant_id, cuisine_id, source)
select r.id, a.cuisine_id, 'tag'
from public.restaurants r
join public.cuisine_aliases a on a.alias = lower(trim(r.tag))
on conflict (restaurant_id, cuisine_id) do nothing;

-- Keeps the links honest as the scraper inserts rows or corrects a tag.
-- Only 'tag'-sourced rows are re-derived; manual curation survives.
create function public.sync_restaurant_cuisines()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.restaurant_cuisines rc
  where rc.restaurant_id = new.id
    and rc.source = 'tag'
    and rc.cuisine_id not in (
      select a.cuisine_id
      from public.cuisine_aliases a
      where a.alias = lower(trim(new.tag))
    );

  insert into public.restaurant_cuisines (restaurant_id, cuisine_id, source)
  select new.id, a.cuisine_id, 'tag'
  from public.cuisine_aliases a
  where a.alias = lower(trim(new.tag))
  on conflict (restaurant_id, cuisine_id) do nothing;

  return new;
end $$;

revoke execute on function public.sync_restaurant_cuisines()
  from public, anon, authenticated;

create trigger restaurants_sync_cuisines
  after insert or update of tag on public.restaurants
  for each row execute function public.sync_restaurant_cuisines();
