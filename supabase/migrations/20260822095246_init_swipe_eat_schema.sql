-- Swipe Eat initial schema (docs/backend-plan.md)
-- Note: the empty legacy tables from the Aug 2026 TikTok-scrape experiments
-- (restaurants, restaurant_reviews; migrations 20260816*) were dropped ad hoc
-- with user approval before this migration ran.

-- ============ profiles (1:1 with auth.users) ============
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default 'User',
  role text,
  -- the three Profile-tab preference tiles, now editable
  morning_mode boolean not null default true,
  spice_bias text not null default 'high'
    check (spice_bias in ('low', 'medium', 'high')),
  nearby_focus boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- auto-create a profile on signup
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', 'User'));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ restaurants ============
create table public.restaurants (
  id bigint generated always as identity primary key,
  name text not null,
  tag text not null,                    -- category badge, e.g. 'Breakfast'
  details text not null default '',
  brand_color text not null default '#141922',  -- hex; UI parses to Color
  rating numeric(2,1) not null default 0
    check (rating >= 0 and rating <= 5),
  latitude double precision not null,
  longitude double precision not null,
  video_url text,                       -- TikTok embed URL (scrape script)
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  -- Explore search
  search tsvector generated always as (
    to_tsvector('simple', name || ' ' || tag || ' ' || details)
  ) stored
);

create index restaurants_search_idx on public.restaurants using gin (search);
create index restaurants_active_idx on public.restaurants (is_active)
  where is_active;

-- ============ restaurant_images (ordered gallery) ============
create table public.restaurant_images (
  id bigint generated always as identity primary key,
  restaurant_id bigint not null
    references public.restaurants (id) on delete cascade,
  url text not null,                    -- external URL now; Storage path later
  position int not null default 0,
  unique (restaurant_id, position)
);

create index restaurant_images_restaurant_id_idx
  on public.restaurant_images (restaurant_id);

-- ============ reviews (carousel snippets) ============
create table public.reviews (
  id bigint generated always as identity primary key,
  restaurant_id bigint not null
    references public.restaurants (id) on delete cascade,
  author_name text not null,            -- scraped/seeded names, not FK yet
  user_id uuid references public.profiles (id) on delete set null,
  body text not null,
  created_at timestamptz not null default now()
);

create index reviews_restaurant_id_idx on public.reviews (restaurant_id);
create index reviews_user_id_idx on public.reviews (user_id);

-- ============ swipes (deck decisions; Like tab = liked = true) ============
create table public.swipes (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  restaurant_id bigint not null
    references public.restaurants (id) on delete cascade,
  liked boolean not null,
  created_at timestamptz not null default now(),
  unique (user_id, restaurant_id)       -- re-swipe = upsert
);

create index swipes_restaurant_id_idx on public.swipes (restaurant_id);
create index swipes_user_liked_idx on public.swipes (user_id)
  where liked;                          -- Like-tab query

-- ============ quiz ============
create table public.quiz_questions (
  id bigint generated always as identity primary key,
  prompt text not null,
  is_active boolean not null default true,
  position int not null default 0
);

create table public.quiz_options (
  id bigint generated always as identity primary key,
  question_id bigint not null
    references public.quiz_questions (id) on delete cascade,
  label text not null,
  position int not null default 0,
  -- what the result card shows when this option is picked
  result_title text not null default 'Best next bite',
  result_body text not null default '',
  result_accent text not null default '#B7E4C7',
  recommended_restaurant_id bigint
    references public.restaurants (id) on delete set null
);

create index quiz_options_question_id_idx
  on public.quiz_options (question_id);
create index quiz_options_recommended_restaurant_id_idx
  on public.quiz_options (recommended_restaurant_id);

create table public.quiz_responses (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  question_id bigint not null
    references public.quiz_questions (id) on delete cascade,
  option_id bigint not null
    references public.quiz_options (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, question_id)         -- latest answer wins (upsert)
);

create index quiz_responses_question_id_idx
  on public.quiz_responses (question_id);
create index quiz_responses_option_id_idx
  on public.quiz_responses (option_id);

-- ============ RLS ============
alter table public.profiles enable row level security;
alter table public.restaurants enable row level security;
alter table public.restaurant_images enable row level security;
alter table public.reviews enable row level security;
alter table public.swipes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_options enable row level security;
alter table public.quiz_responses enable row level security;

-- catalog: readable by everyone (anon included, for future logged-out browse)
create policy "read restaurants" on public.restaurants
  for select to anon, authenticated using (is_active);
create policy "read images" on public.restaurant_images
  for select to anon, authenticated using (true);
create policy "read reviews" on public.reviews
  for select to anon, authenticated using (true);
create policy "read questions" on public.quiz_questions
  for select to anon, authenticated using (is_active);
create policy "read options" on public.quiz_options
  for select to anon, authenticated using (true);

-- profiles: owner read/update (insert handled by trigger)
create policy "own profile select" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "own profile update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- swipes / quiz_responses: owner-only, full CRUD
create policy "own swipes" on public.swipes
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "own quiz responses" on public.quiz_responses
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
