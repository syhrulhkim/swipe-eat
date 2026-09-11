-- D148 — a deleted account takes its reviews with it.
--
-- `reviews.user_id` was `on delete set null` from the day the table was seeded,
-- and that was right while a review was catalogue content with an author hook
-- nobody wrote to. D147 made it user-written content, and the same clause now
-- reads: *delete your account and your review stays, still carrying the name
-- you wrote it under, and — because a null `user_id` is what the read policy
-- treats as a seeded snippet — newly readable by everyone instead of only your
-- friends.*
--
-- Deleting the account deletes the review. The rating trigger fires on the
-- delete and takes `restaurants.rating` back down with it, so the column stays
-- true to whatever stars are left.
alter table public.reviews
  drop constraint reviews_user_id_fkey;

alter table public.reviews
  add constraint reviews_user_id_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;
