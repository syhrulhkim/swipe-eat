-- Country and state on a restaurant, so the deck and Explore can be filtered by
-- region later.
--
-- Named in Malay to match how the catalogue is talked about here: `negara` is
-- the country, `negeri` the state. Both are plain text rather than a lookup
-- table — the scrape fills them from the postcode in a TikTok caption, and a
-- foreign key would mean a row cannot be stored at all when the caption is
-- vague, which is the common case rather than the exception.
alter table public.restaurants
  add column negara text not null default 'Malaysia',
  add column negeri text;

comment on column public.restaurants.negara is
  'Country, e.g. Malaysia or Singapore. Defaults to Malaysia: the catalogue is Malaysian and a row that never says otherwise is one.';
comment on column public.restaurants.negeri is
  'State within the country, e.g. Johor. Null when the source caption named no state and none could be derived from its postcode.';

-- Filtering by state always happens inside the active catalogue, so the index
-- carries `is_active` and skips the rows no query can return anyway.
create index restaurants_negeri_idx
  on public.restaurants (negara, negeri)
  where is_active;
