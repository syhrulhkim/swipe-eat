# Swipe Eat — Supabase Backend Plan

Plan for replacing every hardcoded data source in the current UI with Supabase
(Postgres + Auth + Storage), scoped to "all the UI for now": Swipe deck,
Explore, Like, Quiz, Profile, and auth.

## 0. Decision: Supabase Auth replaces the Laravel API

The app's only real backend integration today is Laravel bearer-token auth
(`AuthApi`, `AuthRepository`, `TokenStorage`). Supabase's security model (RLS
keyed on `auth.uid()`) assumes Supabase Auth issues the JWT, and keeping
Laravel just for login while Supabase holds all data would force custom-JWT
bridging for no benefit — there is no other Laravel functionality to preserve.

**Decision: drop the Laravel API entirely and use Supabase Auth
(email/password) via `supabase_flutter`.**

What this means in the app:

- `AuthRepository` keeps its interface (login/register/logout/currentUser) but
  its implementation becomes `supabase.auth.signInWithPassword(...)` etc.
- `TokenStorage` and `dio`/`ApiClient` are deleted — `supabase_flutter`
  persists and refreshes the session itself.
- The demo bypass (`demo@swipeeat.test` / `password`) becomes a real seeded
  Supabase user, so the special-case code path can go away.
- `AppUser` maps from `auth.users` + a `profiles` row (Supabase user ids are
  UUIDs, so `AppUser.id` changes from `int?` to `String?`).

## 1. Schema

One initial migration (`supabase/migrations/0001_init.sql`). Conventions from
the Postgres best-practices skill: `bigint generated always as identity` PKs
for internal tables, `text` over `varchar`, `timestamptz`, RLS on every table
with `(select auth.uid())`, and an index on every FK / RLS column.

### Entity map (UI → tables)

| UI element | Backing |
|---|---|
| Swipe deck cards (`_SwipeCardData`) | `restaurants` + `restaurant_images` + `reviews` |
| Card review carousel | `reviews` |
| TikTok player (`videoUrl`) | `restaurants.video_url` |
| Explore tab cards + search bar | same `restaurants` tables + FTS index |
| Like tab ("saved places") | `swipes` where `liked = true` (finally fed by real swipes) |
| Quiz tab | `quiz_questions` + `quiz_options` + `quiz_responses` |
| Quiz result card | `quiz_options.recommended_restaurant_id` → `restaurants` |
| Profile card + preference tiles | `profiles` |

### DDL

```sql
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
```

Notes:

- `rating` stays denormalized on `restaurants` (it's seed/scraped data, not an
  aggregate of `reviews`) — matches the UI, no trigger needed for now.
- Distance is computed client-side with `geolocator` from lat/lng, exactly as
  the UI does today — no PostGIS needed until server-side "nearby" queries.
- `brand_color`/`result_accent` as hex text rather than int keeps the DB
  readable; the app already converts payloads to `Color`.

### RLS

Every table gets `enable row level security`. Catalog data is world-readable;
per-user data is owner-only. Writes to catalog tables happen only via
migrations/`service_role` (no policies for `authenticated` writes).

```sql
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
  for update to authenticated using (id = (select auth.uid()));

-- swipes / quiz_responses: owner-only, full CRUD
create policy "own swipes" on public.swipes
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "own quiz responses" on public.quiz_responses
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
```

## 2. Seed data (`supabase/seed.sql`)

- The 5 swipe-deck restaurants, 3 Explore spots, and 2 Like-tab places from
  `dashboard_page.dart` collapse into one `restaurants` set (they overlap) with
  their images, review snippets, and TikTok `video_url`s.
- The 1 quiz question + its 4 answers from `_quizAnswers`, each option mapped
  to a result card (today's constant "Warung Wak Jaferi" card becomes one
  option's result).
- Demo user `demo@swipeeat.test` / `password` created via
  `supabase auth admin` (or dashboard) so the login bypass can be deleted.
- `scripts/scrape_tiktok.py` gains a small "push to Supabase" step (update
  `restaurants.video_url`) instead of feeding hardcoded Dart.

Images keep their current external URLs for now; moving them into a Supabase
Storage bucket (`restaurant-images`, public-read) is a later, mechanical step.

## 3. Flutter integration

**Dependencies**: add `supabase_flutter`; remove `dio` and
`flutter_secure_storage` once auth is swapped.

**Init**: `Supabase.initialize(url, anonKey)` in `main.dart`; keys live in
`AppConfig` (anon key is safe to ship; RLS is the security boundary).

**New data layer** (mirrors the existing `features/*/data` pattern):

- `features/restaurants/data/restaurant_repository.dart` —
  `fetchDeck()` (active restaurants not yet swiped by me, with images +
  reviews via one PostgREST nested select), `search(query)` (FTS
  `textSearch('search', ...)` for Explore), `fetchById()`.
- `features/swipes/data/swipe_repository.dart` — `record(restaurantId, liked)`
  (upsert on the unique key), `likedPlaces()` for the Like tab.
- `features/quiz/data/quiz_repository.dart` — `fetchActiveQuestion()`,
  `submit(optionId)` (upsert), returning the option's result card fields.
- `features/profile/data/profile_repository.dart` — `get()`, `updatePrefs()`.

**Model change**: `_SwipeCardData`/`RestaurantDetailData` get `fromJson`
factories (id, hex-color parsing) and move out of `dashboard_page.dart` into
`features/restaurants/models/`.

## 4. Rollout phases

1. **Schema + seed** — apply the migration and seed via Supabase MCP/CLI;
   verify with `select`s. *(Blocked on fixing the MCP `28P01` auth failure —
   reset the DB password / MCP token in the Supabase dashboard.)*
2. **Auth swap** — `supabase_flutter` in, Laravel plumbing out, seeded demo
   user, `AppUser.id` → uuid string.
3. **Swipe deck + Like tab** — deck reads from `fetchDeck()`, swipes recorded,
   Like tab reads real likes (fixes the current disconnect).
4. **Explore** — same restaurant source; wire the dead search bar to FTS.
5. **Quiz** — question/options/result from DB, responses recorded.
6. **Profile** — preference tiles become editable and persist to `profiles`.

Each phase is independently shippable; the UI keeps its current look
throughout.

## 5. Explicitly out of scope (for now)

- User-authored reviews/ratings (schema already leaves a `user_id` hook).
- Server-side nearby/geo queries (PostGIS) and personalization from quiz/prefs.
- Push notifications, realtime, edge functions.
- Moving images into Supabase Storage.
