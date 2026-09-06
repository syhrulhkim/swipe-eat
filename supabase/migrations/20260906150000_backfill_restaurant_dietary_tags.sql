-- `restaurant_dietary_tags` was empty, so every dietary predicate that reads
-- it — the Filters sheet's tag filter and the profile's Vegetarian switch
-- (D105) — emptied the deck and the map for anyone who used it. A hard filter
-- over a table with no rows is worse than an absent one.
--
-- This backfills the two slugs the catalogue can actually evidence:
--
--   halal       from `restaurants.is_halal is true` — the certification the
--               scraper captured, 27 rows of 1 605. Off by default for exactly
--               that reason; this only makes the switch honest, not broader.
--   vegetarian  from the restaurant's own cuisine (a cuisine whose slug or
--               label names vegetarian or vegan) or from its name or tag
--               saying so. Six rows. Thin, and deliberately conservative: a
--               false positive here sends someone to eat something they do
--               not eat.
--
-- The other four slugs (vegan, no-beef, no-pork, gluten-free) stay empty: no
-- column and no caption in the catalogue evidences them, and guessing is the
-- failure this migration exists to fix. A place tagged vegetarian by its own
-- cuisine is not therefore vegan.
--
-- Idempotent: `on conflict do nothing` against the (restaurant_id,
-- dietary_tag_id) primary key, so a re-run after the scraper adds rows is a
-- no-op on what is already there.

insert into public.restaurant_dietary_tags (restaurant_id, dietary_tag_id)
select r.id, dt.id
from public.restaurants r
cross join public.dietary_tags dt
where dt.slug = 'halal'
  and r.is_halal is true
on conflict (restaurant_id, dietary_tag_id) do nothing;

insert into public.restaurant_dietary_tags (restaurant_id, dietary_tag_id)
select distinct r.id, dt.id
from public.restaurants r
cross join public.dietary_tags dt
where dt.slug = 'vegetarian'
  and (
    exists (
      select 1
      from public.restaurant_cuisines rc
      join public.cuisines c on c.id = rc.cuisine_id
      where rc.restaurant_id = r.id
        and (c.slug ilike '%veg%' or c.label ilike '%veg%')
    )
    or r.name ilike '%vegetarian%'
    or r.name ilike '%vegan%'
    or r.tag ilike '%vegetarian%'
    or r.tag ilike '%vegan%'
  )
on conflict (restaurant_id, dietary_tag_id) do nothing;
