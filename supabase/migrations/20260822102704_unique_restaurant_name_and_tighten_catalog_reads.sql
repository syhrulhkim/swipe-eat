-- Seed idempotency: restaurant names are the seed's natural key.
alter table public.restaurants
  add constraint restaurants_name_key unique (name);

-- Images/reviews of inactive restaurants should not leak through the API:
-- scope catalog reads to active restaurants instead of `using (true)`.
drop policy "read images" on public.restaurant_images;
create policy "read images" on public.restaurant_images
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.is_active
    )
  );

drop policy "read reviews" on public.reviews;
create policy "read reviews" on public.reviews
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.is_active
    )
  );
