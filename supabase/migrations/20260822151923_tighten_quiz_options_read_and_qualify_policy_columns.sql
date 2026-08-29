-- Options of inactive (staged/unreleased) quiz questions were world-readable
-- via `using (true)` — the same hole closed for images/reviews previously.
drop policy "read options" on public.quiz_options;
create policy "read options" on public.quiz_options
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.quiz_questions q
      where q.id = public.quiz_options.question_id and q.is_active
    )
  );

-- Recreate the image/review read policies with fully qualified column
-- references: unqualified `restaurant_id` would silently rebind to
-- `r.restaurant_id` if restaurants ever gained a column of that name.
drop policy "read images" on public.restaurant_images;
create policy "read images" on public.restaurant_images
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = public.restaurant_images.restaurant_id and r.is_active
    )
  );

drop policy "read reviews" on public.reviews;
create policy "read reviews" on public.reviews
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.restaurants r
      where r.id = public.reviews.restaurant_id and r.is_active
    )
  );
