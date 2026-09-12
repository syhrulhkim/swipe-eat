-- Seed: restaurants scraped from the @johorfoodie TikTok account
-- (scripts/scrape_tiktok.py; captions -> details, Nominatim-geocoded).
-- Ratings and reviews are intentionally absent: TikTok does not provide them,
-- so rating stays at the 0 default ("none") until a real source exists.
-- Image URLs point at the permanent public restaurant-images Storage bucket
-- (cached from TikTok by the refresh-thumbnails edge function; see plan.md
-- "Thumbnail Expiration"). They do not expire.
-- Idempotent: safe to re-run; existing rows are left untouched. That also
-- means re-running never CORRECTS data - fixing a wrong value in an
-- already-seeded row needs a migration or a manual update.

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Sedap Corner', 'Mee Rebus', 'Some flavours don’t just stay on the menu, they stay in people’s memories. ❤️ For over 40 years, Sedap Corner has been one of those familiar names for Johoreans, with the second generation now carrying forward the recipes and flavours that many grew up with. Among the favourites is their Mee Rebus, a fusion-style dish that has become one of the restaurant’s best sellers, loved for its rich, comforting and familiar taste. For many customers, coming back to Sedap Corner is more than just returning for a meal, it’s coming back to a flavour they already know and love. These familiar moments have become part of their own stories, shared across generations, good food and good company. 🇲🇾✨ Follow the Rasa Kita series to discover more stories behind the people and food we love, and join us at the upcoming MAGGI®️ Gathering at AEON Mall Tebrau City from 18–23 August! Enjoy, Foodie!',
   1.4633506, 103.7447959,
   'https://www.tiktok.com/@johorfoodie/video/7676799160422518037'),
  ('Atap Nipah', 'Malay', 'New Kampung-Style Malay Restaurant in JB Atap Nipah 📍61, Jalan Yahya Awal, Bandar Johor Bahru, 80100 Johor Bahru, Johor Darul Ta''zim ⏰11:30am - 10pm',
   1.4667851, 103.7525193,
   'https://www.tiktok.com/@johorfoodie/video/7676755621290478868'),
  ('Adam Kitchen', 'Seafood', 'Adam Kitchen keeps customers coming back for a reason: their crowd-favourite sweet & sour and chilli crab are packed with bold, comforting flavours that just hit the spot. 🦀🔥 Using MAGGI®️ Chilli Sauce in the cooking helps bring that familiar sweet, tangy and spicy kick together, making every bite extra satisfying and penuh rasa. ❤️ For the customers who keep coming back, these familiar flavours have become part of their own moments; shared over good food and with good company. It’s the kind of flavour that turns first-time customers into regulars, and that’s what makes Adam Kitchen part of the Rasa Kita story. 🇲🇾✨ Follow the Rasa Kita series to discover more stories behind the people and food we love, and join us at the upcoming MAGGI®️ Gathering at AEON Mall Tebrau City from 18–23 August! Enjoy, Foodie!',
   1.5661795, 103.75885,
   'https://www.tiktok.com/@johorfoodie/video/7676386972969209109'),
  ('Hard Rock Cafe Puteri Harbour', 'Western', 'Hard Rock Cafe Puteri Harbour is turning up the excitement this August with its NEW Special Menu and a lineup of exciting promotions! 🎸🔥 🍴 Midday Madness Lunch Set — RM23.90++ Daily | 12PM–3PM 🍽️ Buy 3 Entrées, Get 1 FREE 1–31 Aug Gather the crew and enjoy more delicious bites together! 🤘 🥗 Buy 1 Appetizer, Get 1 FREE 1–31 Aug More appetizers, more sharing, more Merdeka vibes! 🇲🇾 Enjoy a choice of 6 delicious mains with a soft drink included. Whether it’s a quick lunch, an after-work catch-up or a meal with family and friends, Hard Rock Cafe Puteri Harbour has more reasons to make August a month of great food, great company and memorable dining moments. 🎸✨ 📍 Hard Rock Cafe Puteri Harbour ⏰ 10am - 12am',
   1.4240029, 103.6623872,
   'https://www.tiktok.com/@johorfoodie/video/7676323882676079893'),
  ('Borneo Muslim Kolok Mee', 'Kolok Mee', 'Borneo Muslim Kolok Mee 📍Tajai Borneo GP SENTRAL, 81550 Gelang Patah, Johor ⏰11am-8:30pm (Closed on Thurday)',
   1.4781807, 103.5830265,
   'https://www.tiktok.com/@johorfoodie/video/7673718204992277780'),
  ('George & Dragon Cafe', 'British', 'Over 20 Years Family-run British Colonial Restaurant 📍George & Dragon Cafe No. 1 & 3, Jalan Glasiar, Taman Tasek, 80200 Johor Bahru, Johor Darul Ta''zim ⏰ 12pm - 10.30pm',
   1.4867136, 103.7244281,
   'https://www.tiktok.com/@johorfoodie/video/7673461079967567124'),
  ('Sunway Puteri Hills', 'Dining', 'New Hilltop Seaside Dining Spot in JB! Sunway Puteri Hills has finally opened its doors! Located at Iskandar Puteri, here’s what you can find there: ✨Khunya Thai Kitchen Signature ✨Reef Seafood ✨Kaetsu ✨a’rest Cafe ✨Made on Monday ✨Makan Makan by Hock Kee Coming soon in Q4 2026: ✨The Enchanted by the sea ✨Kenny Hills Bakers by the sea ✨Cili Kampung ✨Padi Malaya ✨Padi House 📍Sunway Puteri Hills',
   1.3806703, 103.6399221,
   'https://www.tiktok.com/@johorfoodie/video/7673422798588710165'),
  ('Littleearthku Tearoom', 'Cafe', 'Hidden Scones Cafe in a Park Littleearthku Tearoom 📍Taman Merdeka, Jalan Kolam Air, Royal Johor Country Club, 80100 Johor Bahru, Johor Darul Ta''zim ⏰ Wednesday, Thursday, Friday: 8.30am - 12pm | Sunday: 8.30am - 1pm, Saturday: 8.30am - 2pm',
   1.483472, 103.7204155,
   'https://www.tiktok.com/@johorfoodie/video/7671138664340163860'),
  ('Kay''s Steak & Lobster', 'Steakhouse', 'NEW Halal Lobster Steakhouse in Johor Bahru Kay’s Steak & Lobster has finally opened its first branch in Johor, right here at SKS City Mall, Johor Bahru! Enjoy lobsters imported from Canada and premium steaks sourced from Australia, Argentina and Japan. And don’t miss their first halal-certified Beef Wellington , definitely one for the steak lovers to try! 🤤✨ 📍Kay’s Steak & Lobster L1-02, SKS City Mall, Jalan Storey, Bukit Senyum, 80300 Johor Bahru, Johor Darul Ta''zim ⏰ 11am - 10pm',
   1.4993418, 103.7459972,
   'https://www.tiktok.com/@johorfoodie/video/7670859059138022676'),
  ('Madhen Hot Chicken', 'Fried Chicken', 'NEW Spiciest Nashville Fried Chicken in a Prison 📍Madhen Hot Chicken by Woodfire Lot C6 Kotajail, Penjara (Lama, Jalan Ayer Molek, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ Saturday to Thursday: 12pm - 9.30 Friday: 3pm - 9.30pm',
   1.4632862, 103.7554239,
   'https://www.tiktok.com/@johorfoodie/video/7670493613733940501')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Sedap Corner', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r11-p0-sedap-corner.jpg'),
  ('Atap Nipah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r12-p0-atap-nipah.jpg'),
  ('Adam Kitchen', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r13-p0-adam-kitchen.jpg'),
  ('Hard Rock Cafe Puteri Harbour', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r14-p0-hard-rock-cafe-puteri-harbour.jpg'),
  ('Borneo Muslim Kolok Mee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r15-p0-borneo-muslim-kolok-mee.png'),
  ('George & Dragon Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r16-p0-george-dragon-cafe.jpg'),
  ('Sunway Puteri Hills', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r17-p0-sunway-puteri-hills.png'),
  ('Littleearthku Tearoom', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r18-p0-littleearthku-tearoom.jpg'),
  ('Kay''s Steak & Lobster', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r19-p0-kay-s-steak-lobster.jpg'),
  ('Madhen Hot Chicken', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r20-p0-madhen-hot-chicken.jpg')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

-- ============ quiz (single active question driving the Quiz tab) ============

insert into public.quiz_questions (prompt, is_active, position)
select 'Choose one answer to get a suggestion.', true, 0
where not exists (
  select 1 from public.quiz_questions
  where prompt = 'Choose one answer to get a suggestion.'
);

insert into public.quiz_options
  (question_id, label, position, result_title, result_body, result_accent,
   recommended_restaurant_id)
select q.id, v.label, v.position, 'Best next bite', v.result_body,
       v.result_accent, r.id
from (values
  (
    'I want something comforting and familiar.', 0,
    'Over 40 years of Mee Rebus loved for its rich, comforting and familiar taste.',
    '#B7E4C7', 'Sedap Corner'
  ),
  (
    'I want bold spice and bigger flavor.', 1,
    'The spiciest Nashville fried chicken in JB, served inside an old prison.',
    '#F6D365', 'Madhen Hot Chicken'
  ),
  (
    'I want a quick, easy breakfast stop.', 2,
    'A hidden scones cafe in a park, open from 8.30am.',
    '#F4A261', 'Littleearthku Tearoom'
  )
) as v(label, position, result_body, result_accent, restaurant_name)
join public.quiz_questions q
  on q.prompt = 'Choose one answer to get a suggestion.'
-- inner join: a typo'd restaurant name skips the option entirely instead of
-- silently inserting one with no recommendation
join public.restaurants r on r.name = v.restaurant_name
where not exists (
  select 1 from public.quiz_options existing
  where existing.question_id = q.id and existing.label = v.label
);

-- ---------------------------------------------------------------------------
-- Scraped catalog: 273 additional restaurants from @johorfoodie (2026-08-23).
-- Generated by the scrape pipeline (yt-dlp -> caption extraction -> Nominatim
-- geocoding). Idempotent via on-conflict-do-nothing; rows with lat/lng 0,0
-- could not be geocoded and get no proximity boost in the deck ranker.
-- Image URLs are permanent restaurant-images Storage URLs (see header note).
-- ---------------------------------------------------------------------------

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Little Bun Cafe', 'Cafe', 'Matcha Mochi Brioche in JB 😍 They also serve a whole variety of sourdough bread & other main dishes 🔥 Little Bun Cafe 📍 G-08 , Eco Nest Apartment Jalan Eko Botanic 3/5, Taman, Persiaran Eko Botani, 79100, Johor ⏰9:30am - 9:30pm (Daily)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7670115348573621525'),
  ('Star Fish Leisure Farm', 'Cafe', 'First Floating Cafe in JB 📍 Star Fish Leisure Farm ⏰ 11am - 5pm (Close on Thursday)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7668539034611780881'),
  ('Annalakshmi Restaurant', 'Vegetarian', 'Pay-as-you-wish Vegetarian Restaurant in JB Annalakshmi Restaurant 📍19,Jalan Dapat, Kampung Bahru, 80100 Johor Bahru ⏰11am to 3pm (Monday to Friday)', 1.4672773, 103.7441165, 'https://www.tiktok.com/@johorfoodie/video/7668527421334867217'),
  ('Manmila Nasi Lemak Panas', 'Nasi Lemak', 'RM35 Nasi Lemak Sotong Talam Manmila Nasi Lemak Panas 📍LOT 596, 2, JLN RAYA KG MELAYU, Bukit Batu, 81000 kulai, Johor Darul Ta''zim ⏰7am - 5pm (Closed on Friday)', 1.6438791, 103.6066531, 'https://www.tiktok.com/@johorfoodie/video/7667848367484996885'),
  ('WANG WANG F&B', 'Briyani', 'RM 10 Chicken Briyani 📍WANG WANG F&B, 旺旺美食中心 25, 27, Jalan Kempas 16, Taman Megah Ria, 81750 Masai, Johor ⏰ 10am to 2:45pm', 1.4885124, 103.8519826, 'https://www.tiktok.com/@johorfoodie/video/7667054633319238928'),
  ('SOLENE', 'Restaurant', 'NEW Luxury Rooftop Restaurant in JB 🤩 SOLENE 📍 SKS Tower, Level 26 ⏰ 12pm - 12am', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7665671302480432405'),
  ('Warong Dessert', 'Dessert', 'Late night dessert spot until 12am 📍Warong Dessert Perbadanan Islam Larkin, No 8 Kedai Pij Jalan Cenderasari, 3, Taman, Larkin, 80350 Johor Bahru, Johor Darul Ta''zim ⏰ 12pm to 11:45pm', 1.4992399, 103.7350281, 'https://www.tiktok.com/@johorfoodie/video/7664469501643558164'),
  ('Gebekk Western Food', 'Western', 'RM5 Chicken Chop Gebekk Western Food''s Kota Tinggi 📍LOT 19138, JALAN BY PASS, Jalan Kota Tinggi, 81900 Kota Tinggi, Johor Darul Ta''zim ⏰3:30pm to 11pm', 1.7264118, 103.9123179, 'https://www.tiktok.com/@johorfoodie/video/7663421804219878676'),
  ('Jacket Potato', 'Western', 'Big Mac Beef Jacket Potato Warong Dessert 📍Perbadanan Islam Larkin, No 8 Kedai Pij Jalan Cenderasari, 3, Taman, Larkin, 80350 Johor Bahru, Johor Darul Ta''zim ⏰ 6pm - 11:45pm', 1.4992399, 103.7350281, 'https://www.tiktok.com/@johorfoodie/video/7663343678294887696'),
  ('Moonierena Restaurant', 'Chinese-Muslim', 'NEW Chinese-Muslim Restaurant in a Bungalow Moonierena Restaurant 📍 375, Tebrau Highway, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta’zim ⏰ 12.30pm - 3pm | 5pm - 10.30pm', 1.4893865, 103.7669521, 'https://www.tiktok.com/@johorfoodie/video/7662684539776421141'),
  ('Soup Bun Bun', 'Soup Bun', 'NEW Chicken Pan-Fried Soup Bun in JB 📍Soup Bun Bun 一生煎定 Eco Botanic 2, No.50, Jalan Eko Botani 2B Persiaran Eko Botani 2, 2, Taman Eko Botani, 79100 Iskandar Puteri, Johor Darul Ta''zim ⏰ 8am - 10pm', 1.4599636, 103.6294022, 'https://www.tiktok.com/@johorfoodie/video/7662253343133273364'),
  ('SBS Resort Permas', 'Lepak', 'NEW Forest-Themed Lepak Spot Till 12am in JB 📍SBS Resort Permas ⏰ 11am - 11pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7660481286737415444'),
  ('Chutneys & Chai', 'Indian', 'Lotus Biscoff Chocolate Pani Puri Chutneys & Chai 📍 Tampoi - 2, Jalan Titiwangsa 3, Taman Tampoi Indah, 81200 Johor Bahru, Johor Darul Ta''zim 📍 Masai - Gravity Green (In front of Family Mart GL1, Jln Suria, Bandar Baru Seri Alam, Johor Masai, 81750 Johor Bahru, Johor Darul Ta''zim ⏰ 2:30pm - 12am (Close on Mon)', 1.5111441, 103.6861756, 'https://www.tiktok.com/@johorfoodie/video/7659335402905423125'),
  ('The Sweetzy Dessert', 'Dessert', 'RM15 USA Strawberry Chocolate 📍The Sweetzy Dessert CBS Laman Semerak Penajja, Bandar Baru Uda, Johor ⏰6:30pm until sold out (Closed on Monday and Tuesday)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7659231196638956820'),
  ('JustWant Dessert', 'Dessert', 'Ayam Gepuk Pistachio in JB 📍JustWant Dessert @ Impian Emas 📍 JustWant Dessert @ Pelangi 📍 JustWant Dessert @ Kulai', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7658294101603011861'),
  ('Larkin Highland', 'Dessert', 'Strawberry Dessert Heaven In Johor Bahru 🍓 📍Larkin Highland Jalan Dato Jaafar, Larkin Jaya, 80350 Johor Bahru, Johor Darul Ta’zim ⏰12pm to 12am', 1.4979176, 103.7481047, 'https://www.tiktok.com/@johorfoodie/video/7658251056329116949'),
  ('Ichigo by Tea Cottage', 'Matcha', 'First DIY Matcha Experience in Johor with choice of 14 different matcha 🍵 📍 @Ichigo by Tea Cottage MY @ Horizon Hill ⏰ 11am - 8pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7655944944443477269'),
  ('Haji Padil', 'Rojak', 'Legendary Rojak Haji Padil 📍Bandar Baru Uda', 1.4972879, 103.7212307, 'https://www.tiktok.com/@johorfoodie/video/7654538291471027476'),
  ('Fayyadh Cafe', 'Cafe', 'RM20 Chicken Chop Set Dulang Putra 📍Fayyadh Cafe 10, Jalan Padi Emas 2/1, Bandar Baru Uda, 81200 Johor Bahru ⏰6:30pm - 1am', 1.4952242, 103.7100378, 'https://www.tiktok.com/@johorfoodie/video/7654439865777622293'),
  ('Nenek in Forest', 'Matcha', 'Viral Sheep Matcha in Johor Bahru 📍Nenek in Forest B228-B230, Jalan Tun Abdul Razak, Wadi Hana, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 11.30am - 8.30pm (Monday Closed)', 1.4737434, 103.755231, 'https://www.tiktok.com/@johorfoodie/video/7654189514394504469'),
  ('The Tribus', 'Indian Fusion', 'Indian Fusion Bar in Johor Bahru 🔥 Enjoy a delicious spread of Indian fusion dishes, sip on your favourite drinks, and catch the FIFA World Cup action live with friends. ⚽🍛 📍The Tribus 28, Jalan Impian Emas 7, Taman Impian Emas, 81300 Skudai, Johor Darul Ta''zim ⏰ 11:30am - 12:30am (Daily)', 1.5401915, 103.6857027, 'https://www.tiktok.com/@johorfoodie/video/7653032750127090965'),
  ('Penang Rojak Lao Wu Rojak', 'Rojak', 'Over 30 Years Nangka Rojak @ Johor Jaya 📍Penang Rojak Lao Wu Rojak ⏰11:30am - 5pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7651448442169920786'),
  ('linn cafe', 'Cafe', 'NEW Forest-Themed Cafe in Johor Bahru 📍@linncafejb 27, Jalan Balau, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰10am - 9pm', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7650354870008007957'),
  ('Casa Quesillo', 'Quesillo', 'Matcha Strawberry Quesillo 📍Casa Quesillo JB KR Heritage Kopitiam ⏰5pm-10pm (Closed on Sunday)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7649984078095125781'),
  ('Kluang Cendol Kader', 'Cendol', 'Popular Cendol Since 1942 in Johor 📍Kluang Cendol Kader 1950, Jln. Dato Kaptain Ahmad, Kampung Masjid Lama, 86000 Kluang, Johor Darul Ta''zim ⏰10:30am - 6pm', 2.0343004, 103.3273065, 'https://www.tiktok.com/@johorfoodie/video/7647756098643971345'),
  ('Waronk Maju', 'Lepak', 'NEW lepak spot with train view till 3am Waronk Maju 📍Jalan Petaling, Kawasan Perindustrian Dato Onn, Larkin, 80350 Johor Bahru, Johor Darul Ta''zim ⏰ 6pm - 3am', 1.5078255, 103.7434649, 'https://www.tiktok.com/@johorfoodie/video/7647464721729326343'),
  ('Shantea Dessert', 'Dessert', 'Matcha Taufu Fah and DIY Dessert Cup in JB! 🍧 Shantea Dessert openings in JB, focusing on their unique and healthy desserts! From now till 7th June, get 50% OFF your 2nd cup of their drinks~ 🤩 Shantea Dessert 📍 G10, Ground Floor, Ibrahim International Business, Komtar JBCC, Jalan Wong Ah Fook, Bandar Johor Bahru, 80888 Johor Bahru, Johor Darul Ta''zim ⏰ 10am - 10pm', 1.4655433, 103.7594338, 'https://www.tiktok.com/@johorfoodie/video/7647455340023336210'),
  ('Kulaifornia Tacos', 'Tacos', 'Street Tacos with Avocado Sauce 📍Kulaifornia Tacos', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7644941518838451477'),
  ('Ayam Goreng Faizal', 'Fried Chicken', 'RM19 Whole Fried Chicken 📍 Ayam Goreng Faizal 78, Jalan Padi 2, Bandar Baru Uda 81200 Johor Bahru, Johor Dahrul Ta''zim ⏰ 9.30am - 8pm', 1.5048156, 103.7158165, 'https://www.tiktok.com/@johorfoodie/video/7644865192634993940'),
  ('Kopi Antara Senja', 'Coffee', 'Coffee healing in the middle of paddy fields 📍Kopi Antara Senja', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7644559421753888020'),
  ('Donuf', 'Donut', 'FIRST Donuf Puff in Malaysia 📍 Donuf Jalan Dhoby 26, Jalan Dhoby, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 9am - 8.30pm', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7644066106042486037'),
  ('Satay Bajet Waklan', 'Satay', 'RM0.85 Satay Bajet 📍Satay Bajet Waklan', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7643807837449260309'),
  ('The Veil', 'Restaurant', 'Beautiful Garden Restaurant By The River in JB The Veil 📍 THE VEIL, Persiaran Bayu Delima, Emerald Bay, 79000 Iskandar Puteri, Johor Darul Ta''zim ⏰ 12pm - 10pm (Closed on Monday)', 1.4182087, 103.6566214, 'https://www.tiktok.com/@johorfoodie/video/7642713008535260436'),
  ('Elvys Pizza', 'Pizza', 'New American-Style Pizza Spot in JB New Elvys Pizza 📍 137A, Jln Beringin, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 5pm - 11pm (Mon - Fri), 12pm - 11pm (Sat - Sun)', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7639688200797064469'),
  ('Nasi Lemak Sotong Aliff', 'Nasi Lemak', 'RM 55 Nasi Lemak 📍Nasi Lemak Sotong Aliff Jalan Bayu Puteri, 80150 Johor Bahru ⏰3pm until 12am', 1.5000579, 103.7902488, 'https://www.tiktok.com/@johorfoodie/video/7638456118297103623'),
  ('Mood Cafe', 'Cafe', 'New Italian Sandwich Café in a neighbourhood Mood Cafe 📍28, Jalan Cokmar, Taman Sri Tebrau, 80050 Johor Bahru, Johor Darul Ta''zim ⏰9.30am - 6.30pm', 1.4885628, 103.7768042, 'https://www.tiktok.com/@johorfoodie/video/7636716664763206932'),
  ('Tree in One', 'Cafe', 'New Industrial Cafe in JB Tree in One 📍PTD 203253, Persiaran Medini 5, Bandar Medini Iskandar, 79250 Iskandar Puteri, Johor Darul Ta''zim ⏰12pm - 11pm (Daily)', 1.4158451, 103.6291426, 'https://www.tiktok.com/@johorfoodie/video/7636253229818350869'),
  ('Kopistry Coffee & Pizza', 'Pizza', 'Sukiya Pizza in JB 📍Kopistry Coffee & Pizza 16, Jalan Padi Mahsuri 11, Bandar Baru Uda, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 8pm - 12am, Thursday - Sunday', 1.4944873, 103.718508, 'https://www.tiktok.com/@johorfoodie/video/7634400027762543892'),
  ('Cafe Jufei', 'Cafe', 'We visited this charming cafe filled with antiques and collectibles ☺️ With the OPPO Reno15 Pro, we captured the cozy vibes perfectly with: ✨ 50MP 0.6x Ultra Wide Selfie Camera ✨ AI Motion Photo Popout ✨ AI Mind Space So, where would you take the Reno15? Let us know in the comments below 📲 📍Cafe Jufei, 3D, Jalan Ismail, Taman Kulai, 81000 Kulai, Johor', 1.654791, 103.5964294, 'https://www.tiktok.com/@johorfoodie/video/7631432456368868616'),
  ('Ruma Tengah', 'Laksa', 'Laksa Johor till 11pm in JB Ruma Tengah 📍18, Lorong Murni, Kampung Melayu Majidee, 81100 Johor Bahru, Johor Darul Ta''zim ⏰Wednesday to Sunday: 6pm - 11pm', 1.5149519, 103.7564864, 'https://www.tiktok.com/@johorfoodie/video/7631138703229930760')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Little Bun Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r21-p0-little-bun-cafe.png'),
  ('Star Fish Leisure Farm', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r22-p0-star-fish-leisure-farm.png'),
  ('Annalakshmi Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r23-p0-annalakshmi-restaurant.png'),
  ('Manmila Nasi Lemak Panas', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r24-p0-manmila-nasi-lemak-panas.jpg'),
  ('WANG WANG F&B', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r25-p0-wang-wang-f-b.png'),
  ('SOLENE', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r26-p0-solene.jpg'),
  ('Warong Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r27-p0-warong-dessert.jpg'),
  ('Gebekk Western Food', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r28-p0-gebekk-western-food.jpg'),
  ('Jacket Potato', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r29-p0-jacket-potato.png'),
  ('Moonierena Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r30-p0-moonierena-restaurant.jpg'),
  ('Soup Bun Bun', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r31-p0-soup-bun-bun.jpg'),
  ('SBS Resort Permas', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r32-p0-sbs-resort-permas.jpg'),
  ('Chutneys & Chai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r33-p0-chutneys-chai.jpg'),
  ('The Sweetzy Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r34-p0-the-sweetzy-dessert.png'),
  ('JustWant Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r35-p0-justwant-dessert.jpg'),
  ('Larkin Highland', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r36-p0-larkin-highland.jpg'),
  ('Ichigo by Tea Cottage', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r37-p0-ichigo-by-tea-cottage.jpg'),
  ('Haji Padil', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r38-p0-haji-padil.jpg'),
  ('Fayyadh Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r39-p0-fayyadh-cafe.jpg'),
  ('Nenek in Forest', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r40-p0-nenek-in-forest.jpg'),
  ('The Tribus', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r41-p0-the-tribus.jpg'),
  ('Penang Rojak Lao Wu Rojak', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r42-p0-penang-rojak-lao-wu-rojak.png'),
  ('linn cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r43-p0-linn-cafe.jpg'),
  ('Casa Quesillo', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r44-p0-casa-quesillo.jpg'),
  ('Kluang Cendol Kader', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r45-p0-kluang-cendol-kader.png'),
  ('Waronk Maju', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r46-p0-waronk-maju.png'),
  ('Shantea Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r47-p0-shantea-dessert.png'),
  ('Kulaifornia Tacos', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r48-p0-kulaifornia-tacos.jpg'),
  ('Ayam Goreng Faizal', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r49-p0-ayam-goreng-faizal.jpg'),
  ('Kopi Antara Senja', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r50-p0-kopi-antara-senja.jpg'),
  ('Donuf', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r51-p0-donuf.jpg'),
  ('Satay Bajet Waklan', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r52-p0-satay-bajet-waklan.jpg'),
  ('The Veil', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r53-p0-the-veil.jpg'),
  ('Elvys Pizza', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r54-p0-elvys-pizza.png'),
  ('Nasi Lemak Sotong Aliff', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r55-p0-nasi-lemak-sotong-aliff.png'),
  ('Mood Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r56-p0-mood-cafe.png'),
  ('Tree in One', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r57-p0-tree-in-one.jpg'),
  ('Kopistry Coffee & Pizza', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r58-p0-kopistry-coffee-pizza.png'),
  ('Cafe Jufei', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r59-p0-cafe-jufei.png'),
  ('Ruma Tengah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r60-p0-ruma-tengah.png')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('AHBOY BANANA LEAF', 'Banana Leaf', 'Over 45 Dishes Banana Leaf 📍AHBOY BANANA LEAF 29, Jln Anggerik 2/5, Taman Anggerik, 81200 Johor Bahru, Johor Darul Ta''zim ⏰12pm- 4pm', 1.5330534, 103.6906329, 'https://www.tiktok.com/@johorfoodie/video/7631111859071929608'),
  ('Fella Quesillo', 'Cafe', 'First quesillo coffee in Malaysia 📍@Fella Quesillo 1st in JB , CBS Tebing Bandar Dato’ Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7630041954461535509'),
  ('Lucky Cup', 'Cafe', 'Spotted NEW RM5.50 Grape Coffee in JB! 🍇 Mixue-backed coffee chain, Lucky Cup just launched their all-new Grape Series: 🥤 Grape Tea RM4.50 ☕️ Grape Coffee RM5.50 🍨 Grape Snowball Lucky Frappe RM7 FREE 1x Grape Magnet when you get any 2 Grape drinks!! 🎉 📍 Lucky Cup outlets (nationwide)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7629929056854740245'),
  ('NASI LEMAK ANGGERIK TAMAN MOLEK', 'Nasi Lemak', 'Nasi Lemak Banjir 📍NASI LEMAK ANGGERIK TAMAN MOLEK Jalan Molek 2/4, Taman Molek, 81100 Johor Bahru, Johor Darul Ta''zim, Malaysia ⏰5:30pm - 10pm', 1.5276589, 103.790277, 'https://www.tiktok.com/@johorfoodie/video/7629215169373097217'),
  ('Naug Just Plants', 'Cafe', 'Largest Moss Sculpture & Terrarium Cafe in Johor Naug Just Plants 📍50, Jalan Tan Hiok Nee, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰Daily: 9am - 6pm Naug Cafe ⏰Tuesday to Sunday: 11am - 6pm', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7629205106851859732'),
  ('Zao Cha', 'Cafe', 'White Kaya Roti Bakar in JB! 🤩 Zao Cha 📍 26, Jalan Sagu 8, Taman Daya, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 9am - 8pm (daily)', 1.5446827, 103.7628017, 'https://www.tiktok.com/@johorfoodie/video/7628916405219495185'),
  ('Nooduo by Kioku', 'Noodles', 'French Onion Soup Noodle in JB 🍜 Nooduo by Kioku 📍 13, Jalan Dedap, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 11am - 6pm', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7628816222368353552'),
  ('Pdafu by pbaking', 'Dessert', 'First Strawberry Daifuku in JB Pdafu by pbaking 📍40 A, Jalan Pendekar 13, Taman Ungku Tun Aminah, 81300 Skudai, Johor Darul Ta''zim ⏰1pm - 8pm Closed on Wednesday and Thursday', 1.5133007, 103.6546304, 'https://www.tiktok.com/@johorfoodie/video/7627024511140941076'),
  ('KOMÉ Café', 'Japanese Cafe', 'New Modern Japanese Cafe in JB KOMÉ Café 📍80, Jalan Meranti, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰Sunday to Thursday: 11am - 6pm ⏰Friday to Sunday: 11am - 8.30pm', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7626975449423416596'),
  ('Akak Kuih Vadai', 'Indian', 'Rm0.50 Indian Kuih 📍Akak Kuih Vadai Restoran Liew Soon Bandar Baru Kangkar Pulai , Johor ⏰12pm-8pm (Monday Closed)', 1.5655276, 103.5885568, 'https://www.tiktok.com/@johorfoodie/video/7626299641235066129'),
  ('Starhill Seafood Restaurant', 'Seafood', 'Malaysian-Style Buffet at One of Johor’s Oldest Golf Course! ⛳️ There’s also their newly renovated event halls and private rooms for many occasions like weddings, corporate dinners and many more! 🎉 Starhill Seafood Restaurant 📍 Jalan Kampung Maju Jaya, Kempas Lama, 81300 Johor Bahru, Johor Darul Ta''zim ⏰ 11:30am - 10:30pm (Daily) 📞 For bookings: +60125242249 +60127282249 +60124382249', 1.5618101, 103.6198751, 'https://www.tiktok.com/@johorfoodie/video/7625955059750194453'),
  ('Kok Ki Curry Noodle', 'Curry Noodle', '83 Year Old Famous Curry Noodle in JB Kok Ki Curry Noodle 📍 Jalan Tun Teja, Taman Ungku Tun Aminah, 81300 Skudai, Johor Darul Ta''zim ⏰ 4pm - 11:30pm (Closed on Sunday)', 1.5290259, 103.6644193, 'https://www.tiktok.com/@johorfoodie/video/7625871054732414225'),
  ('Redfloor Bar & Dessert', 'Cafe', 'New Modern Red-Themed Cafe in JB Redfloor Bar & Dessert 📍 Jln Molek 3/20, Taman Molek, 80100 Johor Bahru, Johor Darul Ta''zim ⏰ 11am - 3pm | 8pm - 12am (Closed on Tues)', 1.5200351, 103.7843457, 'https://www.tiktok.com/@johorfoodie/video/7624749226932636944'),
  ('Shüü Cafe', 'Cafe', 'Over 10 types of Fresh Cream Puffs 🤤 Freshly baked cream puffs in over 10 flavours, other desserts, brunch menus and drinks! Shüü Cafe 📍203, Jln Wijaya, Taman Abad, 81100 Johor Bahru, Johor Darul Ta''zim ⏰10am - 6pm (Closed on Wednesday)', 1.5452652, 103.7585042, 'https://www.tiktok.com/@johorfoodie/video/7624363164682997009'),
  ('Suka & Co', 'Malay', 'Nasi Gepuk Chicken Tenders 📍Suka & Co, Near Masjid Taman Perling', 1.4229534, 103.5505112, 'https://www.tiktok.com/@johorfoodie/video/7623731379364302101'),
  ('Lemang Poksu', 'Malay', '9 Years Old Lemang Boss 📍Lemang Poksu', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7621168359693913364'),
  ('RuRu', 'Japanese', 'New Library-themed Japanese Grill Restaurant in JB RuRu 📍 58, Jalan Mutiara Emas 5/9, Taman Mount Austin, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 3pm - 12am', 1.5492023, 103.7709046, 'https://www.tiktok.com/@johorfoodie/video/7621105241727028481'),
  ('Annie Sammies', 'Cafe', 'NEW Mother-Daughter Run Sourdough Cafe in JB Annie Sammies 📍 30, Jalan Camar 1, Taman Perling, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 8am - 7pm (Closed on Wed)', 1.4948976, 103.6795075, 'https://www.tiktok.com/@johorfoodie/video/7621073136301247764'),
  ('JIN Gastrobar', 'Steakhouse', 'Ribeye Steak In A Cinema?! 😳 Indulge in fine dining only at JIN Gastrobar hidden inside of GSC Aurum theatre at Mid Valley Southkey 🥩 Choose from dishes like Black Angus Ribeye, Canadian Atlantic Lobster Roll, Smoked Duck Carbonara, Wagyu Burger & more 🍔 📍 @jingastrobar at Mid Valley Southkey ⏰ (Daily) 11am - 10pm', 1.5009732, 103.7777493, 'https://www.tiktok.com/@johorfoodie/video/7618539871245765908'),
  ('Bubur Maneh Station', 'Malay', 'RM5 Badak Berendam and 7 types of Bubur Bubur Maneh Station 📍Bazaar Ramadan Tebing Dato Onn Jln Dato'' Onn Utama, Nasa City, 81100 Johor Bahru, Johor Darul Ta''zim 3pm - 8pm', 1.5452652, 103.7585042, 'https://www.tiktok.com/@johorfoodie/video/7617778584333192465'),
  ('Gula Cakery', 'Bakery', 'KL’s popular Gula Cakery is opening its FIRST outlet in Johor 🔥 Gula Cakery is known for its beautifully crafted cakes, cupcakes, and sweet desserts made with creative designs and delightful flavours, served in a variety of tempting options such as Signature Cakes, Cupcake Boxes, Burnt Cheesecakes, and more 🎂🧁 📍 Toppen Shopping Centre 📆 Official opening date to be announced soon Source & Photo: Gula Cakery', 1.5529334, 103.7978494, 'https://www.tiktok.com/@johorfoodie/video/7617720251559578888'),
  ('Kopi Malaya', 'Malaysian', 'RM10 Nasi Ambang Set + Drink! Kopi Malaya 📍 210, Jalan Layang 16, Taman Perling, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 3pm - 8pm', 1.4762879, 103.6797361, 'https://www.tiktok.com/@johorfoodie/video/7616649967654096136'),
  ('Nasi Ambang Wan Mahdam', 'Malaysian', 'Huge Nasi Ambang Dulang Set 📍Nasi Ambang Wan Mahdam Bazaar Ramadan Plaza Angsana ⏰ 12pm - 7pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7616661940756057365'),
  ('Warung Bunda by OMB', 'Malaysian', 'Bahulu Gulung Panas 🔥 📍 Warung Bunda by OMB', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7616559049005468948'),
  ('Restoran Arzhad Baru', 'Malay', 'Crispy Chicken Nasi Lemak Till 4am 🍗 Restoran Arzhad Baru 📍 23, Jalan Hang Tuah 40, Taman Skudai Baru, 81300 Skudai, Johor Darul Ta''zim ⏰ 5:30pm - 4am', 1.5192604, 103.653104, 'https://www.tiktok.com/@johorfoodie/video/7616300738414775569'),
  ('Dachshund & Friends', 'Cafe', 'First Dachshund Cafe in Jb 🐶 📍 Dachshund & Friends 1-01, 5, Jln Austin Heights 7, Taman Mount Austin, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 1pm - 6pm (Closed on Wednesday)', 1.5452652, 103.7585042, 'https://www.tiktok.com/@johorfoodie/video/7616291808057789713'),
  ('Warong Tacos', 'Mexican', 'Sos Hijau Mexican Tacos 📍Warong Tacos Bazaar Ramadan Taman Dahlia', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7616215202018626817'),
  ('KFC Seri Gelam', 'Fast Food', 'KFC Open House at Johor is the last stop of the celebration! Plenty of exciting activities: ✅ Kongsi Semeja ✅ Wall of Wishes ✅ Kongsi Photo Booth ✅ Kiap Kiap Kongsi (Big Bucket Lucky Draw) ✅ Stage performances & more! It was the perfect festive hangout with friends and family! 📍 7 March 2026 (Saturday) KFC Seri Gelam DT 🍗✨', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7615198882351336721'),
  ('The Starter Cafe', 'Cafe', 'Over 20 Unique Sourdough Bread in JB! 🍞 They also serve a whole variety of sourdough menu for their mains!🤤 The Starter Cafe 📍1, Jalan Kuning 1, Taman Pelangi, 80400 Johor Bahru, Johor Darul Ta''zim ⏰8am - 6pm (Closed on Monday)', 1.4772004, 103.771881, 'https://www.tiktok.com/@johorfoodie/video/7615145385341766928'),
  ('Ya Xiang Herbal Roast Duck', 'Chinese', 'Famous Herbal Duck Rice Ya Xiang Herbal Roast Duck 📍Jalan Sutera, Taman Sentosa, 80150 Johor Bahru ⏰ 5pm - 7pm (Closed on Monday)', 1.4935389, 103.7751089, 'https://www.tiktok.com/@johorfoodie/video/7615090351958789392'),
  ('LEGOLAND Malaysia Resort', 'Buffet', 'LEGOLAND’s Eat-All-You-Can Ramadan Buffet 🌙🍽️ Ramadan Buffet Period: 21st February - 18th March 2026, 6pm - 10pm. Enjoy Promo price until 8 March! Price details: Weekdays: 🏷️ Adult: RM168 (NP: RM188) 🏷️ Senior: RM118 (NP: RM138) 🏷️ Child: RM68 (NP: RM88) Weekends: 🏷️ Adult: RM200(NP: RM228) 🏷️ Senior: RM148 (NP: RM178) 🏷️ Child: RM98 (NP: RM128) 📞Booking Hotline: +6075978888 Email: info@legoland.my 📍LEGOLAND Malaysia Resort No 7, Jln Legoland, Bandar, 79250 Johor Bahru, Johor', 1.4223164, 103.6278134, 'https://www.tiktok.com/@johorfoodie/video/7613742297611635989'),
  ('ZUS Signature', 'Cafe', 'ZUS Signature is now in JB!🥤 Enjoy a different “Atas” side of ZUS that you have never seen before! 🤩 Get their unique Single Origin Espresso and all their signature drinks ONLY at this spot. ZUS Signature 📍Mount Austin, 65, Jalan Mutiara Emas 2A, Taman Mount Austin, 81100 Johor Bahru, Johor Darul Ta''zim ⏰7am - 10pm (Daily)', 1.5535014, 103.7848567, 'https://www.tiktok.com/@johorfoodie/video/7613711875913600277'),
  ('Beard Brothers BBQ', 'BBQ', 'RM9 Roti James 📍Beard Brothers BBQ', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7612752374377106709'),
  ('Hey Yi Dessert', 'Dessert', 'NEW Over 80 Types Dessert & Tong Shui Spot till 2am 😍 Hey Yi Dessert [Pork-free] 📍130, Jalan Sutera Tanjung 8/3 Taman Sutera Utama Skudai, 81300 Johor Bahru, Johor Darul Ta''zim ⏰ 5pm - 2am Tues to Fri | 2pm - 2am Sat to Sun (Closed on Monday)', 1.5162678, 103.6678053, 'https://www.tiktok.com/@johorfoodie/video/7611366007248112917'),
  ('Vine Cafe', 'Cafe', 'In conjunction with this blessed month, Vine Cafe is introducing a special Ala-Carte Iftar Buffet thoughtfully prepared for the Muslim community who wish to break their fast with meals that are lighter, wholesome, and refreshing 🌙✨ Item’s on their Ala-carte menu: ✨ Briyani Rice ✨ Blue Pea Nasi Lemak ✨ Rendang Lion’s Mane Mushroom ✨ Signature Laksa And many more! 🤤 💰Adult: RM68 | Child: RM38 (6-12) Vine Cafe 📍 16-01, Laman Niaga Sunway, Persiaran Medini 3, Sunway Iskandar, 79250 Iskandar Puteri, Johor Darul Ta''zim 🌙 22 Feb - 15 March 📞 Early reservations are highly encouraged: https://wa.link/0z9oly', 1.4158451, 103.6291426, 'https://www.tiktok.com/@johorfoodie/video/7611452895732485396'),
  ('Anjung Selera Hutan Bandar', 'Malay', 'Capati Tujoh Pagi 📍Anjung Selera Hutan Bandar, ulu Air molek, 80200,Johor Bahru , Johor (last stall) ⏰7am-12:30pm', 1.479724, 103.7478274, 'https://www.tiktok.com/@johorfoodie/video/7610316145412918544'),
  ('Restoran Nasi Briyani & Ambang', 'Malaysian', 'Famous Nasi Ambang Spot in JB Get up to 25% OFF TOTAL BILL with Grab Dine Out Deals💚with your first visit Restoran Haji Briyani and Ambang or other participating restaurants 🤑 Restoran Nasi Briyani & Ambang 📍24, Jalan Dataran 3/1, Taman Kempas, 81200 Johor Bahru, Johor Darul Ta''zim ⏰9:30AM - 6PM (Close on Sunday) Find out more on the Grab App!', 1.5367166, 103.7094441, 'https://www.tiktok.com/@johorfoodie/video/7609506739398003969'),
  ('Attic by RAW', 'Cafe', 'RM78 buffet at JB industrial cafe 🔥 Attic by RAW is also serving a la carte menu featuring Nasi Lemak Royale Ayam Berempah, Basil Salmon, Cilantro Lime Burger & many more 😍 💰RM78++ per adult 💰RM60++ per senior citizen (60 years old & above) 💰RM35++ per child (4 - 12 years old) ✅ Buy 10 adult buffet meals, get 1 FREE! Promo until 19 March 2026 Buffet starting from 23/2 to 19/3, 7pm - 10pm Normal operation hours Weekday 10am-10pm Weekend 9am-10pm Attic by RAW 📍 1, Jalan Mutiara Emas 5/13, Taman Mount Austin, 81100 Johor Bahru, Johor', 1.5523827, 103.7749497, 'https://www.tiktok.com/@johorfoodie/video/7609554376239123733'),
  ('Chow Chow Stir Fry', 'Stir Fry', 'Modern Stir-fry Takeout in JB! Get up to 25% OFF TOTAL BILL with Grab Dine Out Deals💚with your first visit to Chow Chow Stir Fry or other participating restaurants 🤑 Chow Chow Stir Fry 📍Eco Nest Apartment, G-04, Residensi Eko, Jalan Eko Botani 3/5, Taman, Persiaran Eko Botani, 79100 Iskandar Puteri, Johor ⏰11AM - 10PM Find out more on the Grab App!', 1.4599636, 103.6294022, 'https://www.tiktok.com/@johorfoodie/video/7609504894776593680'),
  ('Penyet Express', 'Indonesian', 'Unlimited Sambal at Penyet Express! This spot serves really good Ayam Penyet and even greater sambal! 🤩 Plus it’s UNLIMITED! 🔥 Save up to 25%OFF total bill when you use Grab Dine Out Deals 💚 Penyet Express - JBCS 📍 MB03, 04 & 05, Level B1, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 10:30AM - 10PM Find out more on the Grab App!', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7609292434408754449')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('AHBOY BANANA LEAF', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r61-p0-ahboy-banana-leaf.png'),
  ('Fella Quesillo', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r62-p0-fella-quesillo.jpg'),
  ('Lucky Cup', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r63-p0-lucky-cup.jpg'),
  ('NASI LEMAK ANGGERIK TAMAN MOLEK', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r64-p0-nasi-lemak-anggerik-taman-molek.png'),
  ('Naug Just Plants', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r65-p0-naug-just-plants.jpg'),
  ('Zao Cha', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r66-p0-zao-cha.png'),
  ('Nooduo by Kioku', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r67-p0-nooduo-by-kioku.png'),
  ('Pdafu by pbaking', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r68-p0-pdafu-by-pbaking.jpg'),
  ('KOMÉ Café', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r69-p0-kom-caf.jpg'),
  ('Akak Kuih Vadai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r70-p0-akak-kuih-vadai.png'),
  ('Starhill Seafood Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r71-p0-starhill-seafood-restaurant.jpg'),
  ('Kok Ki Curry Noodle', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r72-p0-kok-ki-curry-noodle.png'),
  ('Redfloor Bar & Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r73-p0-redfloor-bar-dessert.png'),
  ('Shüü Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r74-p0-sh-cafe.png'),
  ('Suka & Co', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r75-p0-suka-co.jpg'),
  ('Lemang Poksu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r76-p0-lemang-poksu.jpg'),
  ('RuRu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r77-p0-ruru.png'),
  ('Annie Sammies', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r78-p0-annie-sammies.jpg'),
  ('JIN Gastrobar', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r79-p0-jin-gastrobar.jpg'),
  ('Bubur Maneh Station', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r80-p0-bubur-maneh-station.png'),
  ('Gula Cakery', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r81-p0-gula-cakery.jpg'),
  ('Kopi Malaya', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r82-p0-kopi-malaya.png'),
  ('Nasi Ambang Wan Mahdam', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r83-p0-nasi-ambang-wan-mahdam.jpg'),
  ('Warung Bunda by OMB', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r84-p0-warung-bunda-by-omb.jpg'),
  ('Restoran Arzhad Baru', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r85-p0-restoran-arzhad-baru.png'),
  ('Dachshund & Friends', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r86-p0-dachshund-friends.png'),
  ('Warong Tacos', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r87-p0-warong-tacos.png'),
  ('KFC Seri Gelam', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r88-p0-kfc-seri-gelam.png'),
  ('The Starter Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r89-p0-the-starter-cafe.png'),
  ('Ya Xiang Herbal Roast Duck', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r90-p0-ya-xiang-herbal-roast-duck.png'),
  ('LEGOLAND Malaysia Resort', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r91-p0-legoland-malaysia-resort.jpg'),
  ('ZUS Signature', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r92-p0-zus-signature.jpg'),
  ('Beard Brothers BBQ', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r93-p0-beard-brothers-bbq.jpg'),
  ('Hey Yi Dessert', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r94-p0-hey-yi-dessert.png'),
  ('Vine Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r95-p0-vine-cafe.jpg'),
  ('Anjung Selera Hutan Bandar', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r96-p0-anjung-selera-hutan-bandar.png'),
  ('Restoran Nasi Briyani & Ambang', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r97-p0-restoran-nasi-briyani-ambang.png'),
  ('Attic by RAW', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r98-p0-attic-by-raw.png'),
  ('Chow Chow Stir Fry', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r99-p0-chow-chow-stir-fry.png'),
  ('Penyet Express', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r100-p0-penyet-express.png')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Nasi Malaya', 'Malay', 'Johor’s Authentic Heritage Cuisine This spot in JB serves authentic Johorean cuisine cooked by nenek since she was 10! 🤩 Save up to 25%OFF total bill when you use Grab Dine Out Deals 💚 Nasi Malaya 📍 547, Jln Persisiran Perling 1, Taman Perling, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 7AM - 6PM (Closed on Friday) Find out more on the Grab App!', 1.4969498, 103.6826965, 'https://www.tiktok.com/@johorfoodie/video/7609168179604081921'),
  ('IKAN BAKARNO 1JB', 'Seafood', 'Massive Grilled Seafood 🔥 📍@IKAN BAKARNO 1JB @ Bazaar Ramadan Taman Suria, JB', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7609170369332677909'),
  ('Warung Penyet Presto', 'Indonesian', 'Popular Ayam Penyet and Geprek spot in JB! This spot serves amazing home cooked Ayam Penyet and Ayam Geprek with traditional sambal! 🔥 Save up to 25%OFF total bill when you use Grab Dine Out Deals 💚 Warung Penyet Presto - The G Place 📍 NO13A, Jalan Dato Abdullah Tahir, Taman Abad, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 12PM - 9PM (Closed on Sunday)', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7608856025583684880'),
  ('Da Napoli Cafe', 'Italian', 'Authentic Italian Restaurant with freshly made WoodFire Pizza in JB 🔥 Must-try menu here including: 🍕Four Cheese Pizza 🍝 Vongole Pasta 🍰 Tiramisu Don’t miss out their latest promo: 🍗 Roast Chicken for RM41 🍕Salmon Pizza for RM39 Da Napoli Cafe 📍26, Jln Austin Height 7/10, Taman Mount Austin, 81100 Johor Bahru, Johor ⏰ 12pm - 10pm (Daily)', 1.5452652, 103.7585042, 'https://www.tiktok.com/@johorfoodie/video/7608780098896006421'),
  ('Hungry Habibi', 'Middle Eastern', 'Looking for Ramadan buffet in Senai? 🌙 This Middle Eastern restaurant offers more than 20 menus from ONLY RM58 per pax! 🤩 Hungry Habibi 📍No 496, Jln Persiaran Scientex Utama 1, Taman Scientex Utama, 81400 Senai, Johor', 1.601092, 103.642908, 'https://www.tiktok.com/@johorfoodie/video/7607782111151508757'),
  ('Abang Spud', 'Snacks', 'Spud Big Mac 📍Abang Spud, TIC Kota Tinggi', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7606305226206743828'),
  ('Domino''s Pizza', 'Pizza', 'Domino''s Pizza for only RM5 😱 Best part is - there’s NO LIMIT on how many you can get🔥 👉 All you need to do is key in the promo code: 314069 on your Domino''s Pizza app 🔴 Valid for Pick-Up only 📍 Available at ALL Domino’s Pizza outlets ⏰ Limited time only Tag your makan kaki, stack those pizzas, and thank us later 😏🍕', 1.5696961, 103.7434138, 'https://www.tiktok.com/@johorfoodie/video/7605600680287440148'),
  ('Cik Peah Fried Chicken', 'Fried Chicken', 'Cendol Ramen 📍@Cik Peah Fried Chicken , Taman Adda Height', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7605212746329623828'),
  ('Dayang''s Kitchen', 'Malay', 'Lauk Raya for Breakfast 📍Dayang’s Kitchen, Pasar Tani Kekal Permas Jaya', 1.4989032, 103.8185063, 'https://www.tiktok.com/@johorfoodie/video/7604810070467022101'),
  ('Yakumo Ramen', 'Japanese', 'Yakumo Ramen has officially opened in Taman Sentosa, Johor Bahru, marking the brand’s first overseas outlet. A Michelin Bib Gourmand favourite for eight consecutive years, the Tokyo-born ramen house has earned a loyal following among critics and everyday diners 🍜 📍191, Jalan Sutera, Taman Sentosa, 80150 Johor Bahru, Johor ⏰ 11am - 8:30pm (Daily) 📸 Yakumo Ramen', 1.4938246, 103.7753893, 'https://www.tiktok.com/@johorfoodie/video/7604760701428567303'),
  ('Burger Bae', 'Burger', 'Rainbow Burger Bun 📍Burger Bae, opposite Residensi Panorama, Bakar Batu', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7602948658467818773'),
  ('Cinta Rasa Coffee', 'Cafe', 'New York-Style Halal Beef Pastrami Sandwich in Johor 🔥 @Cinta Rasa Coffee 📍2, Lorong Haji Kaprawi, Jalan Kluang, Batu 13, 1/2, 86400 Parit Raja, Johor ⏰ 3pm - 11pm (Daily)', 1.8585385, 103.0852742, 'https://www.tiktok.com/@johorfoodie/video/7602933140646333716'),
  ('Teh O Ice 50 cent & Boat Noodle', 'Thai', 'Must-try buka puasa spot in Johor 😍 Serving Nasi Kerabu, Nasi Khao Mok & a variety of Thai dishes 🇹🇭 Teh O Ice 50 cent & Boat Noodle 📍No 58, Jalan Nusaria 11/4, Taman Nusantara, 81550 Gelang Patah, Johor', 1.4592388, 103.5831712, 'https://www.tiktok.com/@johorfoodie/video/7602576312724704513'),
  ('Restoran Pekin KK', 'Chinese', 'This Chinese New Year, make your reunion meals extra special at Restoran Pekin KK Desa Cemerlang 🧧✨ Enjoy chef-crafted festive dishes perfect for sharing. Plus, don’t miss out on their newly available frozen Beggar’s Chicken, now you can bring the goodness home too! 📍Restoran Pekin KK Desa Cemerlang ⏰ 11am – 10.30pm', 1.5631123, 103.813461, 'https://www.tiktok.com/@johorfoodie/video/7598757617351150869'),
  ('Shabu-Yo', 'Japanese', 'Japanese Shabu-Shabu for only RM 39.90?! You get to enjoy unlimited pork, chicken and Tsukune, even free flow of buffet items, desserts and drinks! 😍 Better still, for RM 49.90 you get to enjoy unlimited beef, even wagyu! 🤤✨ 📍 Shabu-Yo @ AEON Mall Tebrau City Lot G137, AEON Tebrau City Mall, No.1 ,Jalan Desa Tebrau, Taman Desa Tebrau, 81100 Johor Bahru, Johor ⏰11am - 10pm', 1.552645, 103.7919763, 'https://www.tiktok.com/@johorfoodie/video/7596938930809851154'),
  ('Cendol Mak Peah', 'Dessert', '20 Years Old Legendary Cendol Mak Peah 📍Jalan Mata Kucing, Kampung Pasir', 1.4961129, 103.7006405, 'https://www.tiktok.com/@johorfoodie/video/7596867955124620564'),
  ('WOW', 'Cafe', 'Rustic Vintage Cafe in Johor 📍WOW, Jalan Kluang, Ayer Hitam, Johor', 1.9094046, 103.1728101, 'https://www.tiktok.com/@johorfoodie/video/7595935238216502548'),
  ('Durian Toksu', 'Durian', 'RM89 Durian Kampung Guni 📍Durian Toksu', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7594833636965289236'),
  ('Kluang Rail Coffee', 'Cafe', 'Malaysia’s Oldest Railway Kopitiam is now in JB! 🚆✨ You can enjoy exclusive dishes that are only available at this outlet, including: 🍗 Famous Ayam Penyet 🍜 Curry Noodles 🍤 Char Kuey Teow 🍲 Laksa Johor 🧆 Hainanese Chicken Chop …and more! 😋 Of course, they still serve their classic kopitiam favourites too! Like butter kaya toast, kopi, and all the nostalgic comfort you love ☕🍞 Plus, this outlet also carries Visit Johor 2026 official merchandise which is perfect for souvenirs! 🤩 Kluang Rail Coffee @Bandar Seri Alam 📍8 Jalan Suria, Bandar Baru Seri Alam Seri Alam, 81750 Masai, Johor Darul Ta''zim ⏰ 7am - 10pm (close on Wednesday)', 1.4938014, 103.8814926, 'https://www.tiktok.com/@johorfoodie/video/7594692272671788306'),
  ('Ticco', 'Dessert', 'Viral Tiramisu and Matcha Swiss Roll in JB! 🤤 100% freshly baked on the spot, limited batches with each flavour that rotates every hour⏱️ You can get them at a reasonable price from RM28 to RM38 and it’s travel-friendly! (Comes with a cooler box, cutleries and paper plate) Enjoy their Buy 1 Free 1 Promo only on the 10th - 11th Jan, 1pm onwards for the first 100 pax! 🔥 And Weekday Promo Buy 1 and get 50% OFF Golden Roll, 1pm onwards for the first 50 pax! 🤩 Ticco @Johor Bahru City Square 📍MK3-09, Level 3, Johor Bahru City Square, 106-108, Jalan Wong Ah Fook, Bandar Johor Bahru, 80888 Johor Bahru, Johor Darul Ta''zim ⏰10am - 10pm (Daily)', 1.4655433, 103.7594338, 'https://www.tiktok.com/@johorfoodie/video/7593650946643660039'),
  ('The FOUNDERS Cafe', 'Cafe', 'The FOUNDERS Cafe is now @Mid Valley Southkey The FOUNDERS Cafe 📍G050, Mid Valley Southkey, 1, Persiaran Southkey 1, Southkey, 80150 Johor Bahru, Johor Darul Ta''zim ⏰ 9am - 10pm (Daily)', 1.493603, 103.7757797, 'https://www.tiktok.com/@johorfoodie/video/7592544772716301576'),
  ('Cookie Crumbs', 'Dessert', 'KL’s popular Cookie Crumbs is opening its FIRST outlet in Johor 🔥 Cookie Crumbs 📍Larkin, Johor Bahru 📆 Opening on 28 January 2026 ✅ Halal-ingredients', 1.4966383, 103.7414091, 'https://www.tiktok.com/@johorfoodie/video/7592494884976708871'),
  ('All Heart Recipe', 'Chinese', 'This restaurant serves Famous Curry Fish head and Dai Chao in JB!🔥 All Heart Recipe 📍62&63, Bandar Indahpura, 81000 johor, Johor Darul Ta''zim ⏰Monday - Friday: 11.30am - 2.30pm | Saturday - Sunday 11.30am - 10.30pm', 1.6354254, 103.6023852, 'https://www.tiktok.com/@johorfoodie/video/7589495732072189191'),
  ('Restoran Asam Pedas & BBQ', 'Seafood', 'Famous Asam Pedas & Seafood BBQ in JB! 🔥🐟 Choose from up to 10 types of fresh seafood, cooked just the way you like it! They even have an outdoor BBQ area, perfect for gathering with family and friends!😋 Restoran Asam Pedas & BBQ 📍 93 & 94, Jalan Pendidikan 5, Taman Universiti, 81300 Skudai, Johor Darul Ta''zim ⏰ 10am - 10pm (Daily)', 1.5458788, 103.6287488, 'https://www.tiktok.com/@johorfoodie/video/7589226792897023250'),
  ('Midnight Wagyu', 'Steakhouse', 'RM28 Wagyu Spots open till 3am in JB 🥩 Seatings on second floor available too! 📍Midnight Wagyu 深夜和牛 in Mount Austin ⏰Opens Daily (5pm - 3am)', 1.5506537, 103.7860148, 'https://www.tiktok.com/@johorfoodie/video/7587705108167658772'),
  ('Gerai ABC Tembikai', 'Dessert', 'Massive ABC Tembikai 📍Gerai ABC Tembikai Parit Ismail, Pontian', 1.4765472, 103.4198788, 'https://www.tiktok.com/@johorfoodie/video/7587362440942456085'),
  ('Restoran Abu & Co', 'Western', 'RM9.90 Chicken Chop in JB! 🍗 Looking for a spot that serves affordable western & asian cuisine ? Abu & Co gotchu covered! They serve RM9.90 chicken chop as well as other local asian delights! Plus they are open 24 hours! 🤤 Save up to 25% OFF total bill when you use Grab Dine Out Deals 💚 📍 Restoran Abu & Co @Taman Bukit Alif 47, Persiaran Tanjung Susur 1, Taman Bukit Alif, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 24 hours', 1.5048156, 103.7158165, 'https://www.tiktok.com/@johorfoodie/video/7586928060193148167'),
  ('Restoran Xiang Mann', 'Chinese', 'Must-try Spicy Chili Crab spot in JB Restoran Xiang Mann 📍1, Jln Bunga Mawar 1, Taman Sri Kulai Baru, 81000 Kulai, Johor Darul Ta''zim ⏰ 11am - 11:30pm | 3pm - 11:30pm (Tuesday)', 1.6438791, 103.6066531, 'https://www.tiktok.com/@johorfoodie/video/7586906194271407367'),
  ('Mr Tuk Tuk', 'Thai', 'Spotted KL’s popular Thai Food Restaurant ,Mr Tuk Tuk opening its FIRST outlet in Johor 😍 📍Level 4, Paradigm Mall Johor Bahru 📆 Opening in January 2026', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7586894406708497672'),
  ('Warung Senget', 'Malay', 'RM5 Nasi Campur with Free Drinks 📍Warung Senget JB', 1.4581986, 103.7649059, 'https://www.tiktok.com/@johorfoodie/video/7585146451202690325'),
  ('Zhu Guang Yu Hotpot', 'Chinese', 'Famous Chong Qing Mala Hotpot is now in JB! 🤩 Zhu Guang Yu Hotpot 📍 G02-G03B, 15, Jalan Dato Abdullah Tahir, Taman Abad, 80300 Johor Bahru, Johor Darul Ta''zim ⏰ 4:30pm - 2am (Daily)', 1.4716106, 103.7670306, 'https://www.tiktok.com/@johorfoodie/video/7584006416428469512'),
  ('Penang Ais Tingkap', 'Dessert', 'Penang Famous Ais Tingkap is Now in Johor 📍B5 Johor Street Market', 1.4957667, 103.7035624, 'https://www.tiktok.com/@johorfoodie/video/7581433354923412756'),
  ('Mr Yogurt', 'Dessert', 'Ice Cream Yogurt Air Balang 😍 Mr Yogurt @ Havoc Food Festival Johor Bahru 📍Angsana Mall Johor Bahru 📆 Now until 30 Nov 2025', 1.4955601, 103.705928, 'https://www.tiktok.com/@johorfoodie/video/7577738861271321877'),
  ('Kedai Mee Celup Ayam Kopeh', 'Malay', 'Whole Chicken Mee Celup 📍Kedai Mee Celup Ayam Kopeh, Taman Seri Orkid', 1.508691, 103.6376224, 'https://www.tiktok.com/@johorfoodie/video/7576602542780517653'),
  ('Kacang Pool Haji', 'Dessert', 'Kacang Pool Haji since 2009 📍 12, Jalan Dato Jaafar, Taman Dato Onn, 80350 Johor Bahru, Johor Darul Ta''zim ⏰ 7am - 12am', 1.4917936, 103.7514261, 'https://www.tiktok.com/@johorfoodie/video/7576509052457372949'),
  ('Betto''s Burger', 'Burger', 'RM30 A5 Wagyu Burger 🍔 📍Betto’s Burger', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7576245459690229012'),
  ('Yakiniku Tora', 'Japanese', 'FIRST Japanese solo BBQ in JB! 😍 Other must-try menu: 🥓Japanese A5 Wagyu Yakiniku Set 🥩Rosu Set Meat 🦐Seafood Platter Set 🍖Frenched Lamb Set 🍛Unagi Don @Yakiniku Tora 📍First Floor, Lot F66 @ AEON Mall Tebrau City, Johor Bahru ⏰11am - 10pm (Opens Daily) [In process of applying for Halal certification]', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7575492845113511189'),
  ('Tiong Hua Restaurant', 'Chinese', 'Family-friendly Chinese Cuisine in JB! 🤤 Tiong Hua Restaurant 📍18 & 20, Jalan Serampang, Taman Pelangi, 80400 Johor Bahru, Johor Darul Ta''zim ⏰10AM - 11PM (Open Daily)', 1.4784256, 103.7758243, 'https://www.tiktok.com/@johorfoodie/video/7575014478031359253'),
  ('All About Chew', 'Beverage', 'Spotted KL’s popular artisanal cookie store, All About Chew opening its FIRST outlet in Johor 😍🍪 📍Level 1, AEON Tebrau City (in front of Boost Juice) 📆 Opening in January 2026', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7574664346152881416'),
  ('Banana Pudding Cedok', 'Bakery', 'Banana Pudding Cedok 🍌 📍Tasik Bandar Seri Alam', 1.5167421, 103.8681941, 'https://www.tiktok.com/@johorfoodie/video/7574386628249029908')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Nasi Malaya', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r101-p0-nasi-malaya.png'),
  ('IKAN BAKARNO 1JB', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r102-p0-ikan-bakarno-1jb.jpg'),
  ('Warung Penyet Presto', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r103-p0-warung-penyet-presto.png'),
  ('Da Napoli Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r104-p0-da-napoli-cafe.jpg'),
  ('Hungry Habibi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r105-p0-hungry-habibi.jpg'),
  ('Abang Spud', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r106-p0-abang-spud.jpg'),
  ('Domino''s Pizza', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r107-p0-domino-s-pizza.jpg'),
  ('Cik Peah Fried Chicken', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r108-p0-cik-peah-fried-chicken.jpg'),
  ('Dayang''s Kitchen', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r109-p0-dayang-s-kitchen.jpg'),
  ('Yakumo Ramen', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r110-p0-yakumo-ramen.jpg'),
  ('Burger Bae', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r111-p0-burger-bae.jpg'),
  ('Cinta Rasa Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r112-p0-cinta-rasa-coffee.jpg'),
  ('Teh O Ice 50 cent & Boat Noodle', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r113-p0-teh-o-ice-50-cent-boat-noodle.png'),
  ('Restoran Pekin KK', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r114-p0-restoran-pekin-kk.jpg'),
  ('Shabu-Yo', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r115-p0-shabu-yo.jpg'),
  ('Cendol Mak Peah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r116-p0-cendol-mak-peah.jpg'),
  ('WOW', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r117-p0-wow.jpg'),
  ('Durian Toksu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r118-p0-durian-toksu.jpg'),
  ('Kluang Rail Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r119-p0-kluang-rail-coffee.jpg'),
  ('Ticco', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r120-p0-ticco.jpg'),
  ('The FOUNDERS Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r121-p0-the-founders-cafe.jpg'),
  ('Cookie Crumbs', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r122-p0-cookie-crumbs.jpg'),
  ('All Heart Recipe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r123-p0-all-heart-recipe.png'),
  ('Restoran Asam Pedas & BBQ', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r124-p0-restoran-asam-pedas-bbq.png'),
  ('Midnight Wagyu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r125-p0-midnight-wagyu.jpg'),
  ('Gerai ABC Tembikai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r126-p0-gerai-abc-tembikai.jpg'),
  ('Restoran Abu & Co', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r127-p0-restoran-abu-co.png'),
  ('Restoran Xiang Mann', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r128-p0-restoran-xiang-mann.png'),
  ('Mr Tuk Tuk', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r129-p0-mr-tuk-tuk.jpg'),
  ('Warung Senget', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r130-p0-warung-senget.jpg'),
  ('Zhu Guang Yu Hotpot', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r131-p0-zhu-guang-yu-hotpot.png'),
  ('Penang Ais Tingkap', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r132-p0-penang-ais-tingkap.jpg'),
  ('Mr Yogurt', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r133-p0-mr-yogurt.jpg'),
  ('Kedai Mee Celup Ayam Kopeh', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r134-p0-kedai-mee-celup-ayam-kopeh.jpg'),
  ('Kacang Pool Haji', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r135-p0-kacang-pool-haji.png'),
  ('Betto''s Burger', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r136-p0-betto-s-burger.jpg'),
  ('Yakiniku Tora', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r137-p0-yakiniku-tora.jpg'),
  ('Tiong Hua Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r138-p0-tiong-hua-restaurant.png'),
  ('All About Chew', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r139-p0-all-about-chew.jpg'),
  ('Banana Pudding Cedok', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r140-p0-banana-pudding-cedok.jpg')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('2AM Nasi Lemak Atok Nenek', 'Malay', '2AM Nasi Lemak Atok Nenek 📍Jalan Cendana, Taman Cendana, Pasir Gudang', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7574004607332945173'),
  ('Hand Pressed Juice', 'Beverage', 'Freshly hand pressed juice 🧃 📍Bandar Seri Alam, Johor', 1.5110638, 103.87704, 'https://www.tiktok.com/@johorfoodie/video/7573640416902270229'),
  ('Quesillo', 'Food', 'Viral Venezuelans Quesillo 🇻🇪 📍Tebing Bandar Dato’ Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7572897666783317268'),
  ('Crab Restaurant', 'Seafood', 'Snow Crab & King Crab in Johor 🦀 📍Tasik Jalan Lembah, Bandar Seri Alam, Masai, Johor', 1.5086785, 103.8763429, 'https://www.tiktok.com/@johorfoodie/video/7572555598219218197'),
  ('Tai Zhi 81 Kopitiam', 'Cafe', 'RM3.50 Chicken Rice 📍Tai Zhi 81 Kopitiam ⏰ 7am - 2pm (Closed on Thursday)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7572435958579154194'),
  ('Tim Hortons', 'Cafe', 'Spotted Canadian coffee chain Tim Hortons opening its FIRST outlet in Johor 😍☕️ Known for its classic coffee, donuts, "Timbits," along with several locally inspired menu items and more 🔥 📍GF, Main Atrium, Paradigm Mall JB (beside Parkson) 📆 Opening in December 2025 Photo: Johor Foodie', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7572424709187325202'),
  ('Feca Kopi', 'Malay', 'RM11.90 Ayam Goreng Set in JB! 🍗 This spot in JB serve up many local Malaysian cuisines and a place that will suits everyone’s taste buds 🤤 Save up to 20%OFF total bill when you use Grab Dine Out Deals 💚 📍 Feca Kopi @Taman Pelangi 44, Jalan Perang, Taman Pelangi, 80400 Johor Bahru, Johor Darul Ta''zim, Malaysia ⏰ 7:30AM - 5PM (Daily) [Pork-free]', 1.4812739, 103.7730314, 'https://www.tiktok.com/@johorfoodie/video/7571389480620264711'),
  ('Restoran Hua Mui', 'Chinese', 'First Hua Mui Restaurant in the mall 🔥 Restoran Hua Mui 📍Lot F65, First Floor (Level 1), Aeon Tebrau City, Taman Desa Tebrau, Johor Bahru ⏰ 10am - 10pm (Daily)', 1.457367, 103.7642817, 'https://www.tiktok.com/@johorfoodie/video/7569937514933275925'),
  ('HEYTEA', 'Malay', 'FREE HEYTEA for ONE DAY ONLY! 🧋💥 HEYTEA is officially Halal-certified! To celebrate, everyone gets to enjoy any drink on the menu for FREE this Friday! 😍 📍 All HEYTEA outlets in Malaysia 📅 7 Nov 2025 (Friday) ✨ Plus, from 8–13 Nov, get 1,000 FREE DRINKS daily on the HEYTEA app! (One coupon per user, valid for 7 days 😉)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7569461016321379601'),
  ('Nasi Gulai Khopeh', 'Malay', 'Nasi Gulai Khopeh with Perut Air Asam 📍@Nasi Gulai Khopeh , Kota Tinggi', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7569183116070358293'),
  ('Tauhu Crispy Dapur Yumi', 'Food', 'Flavoured Crispy Tahu with Sambal Kicap 📍@Tauhu Crispy Dapur Yumi', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7568811260389723413'),
  ('TOKSU CHICKEN', 'Food', 'Spicy Ayam Gunting with Shaker Fries 📍@TOKSU CHICKEN , Jalan Perjiranan 2, Bandar Dato’ Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7568478341196483860'),
  ('Singgah Tapaw Peserai', 'Food', 'Viral kuih vendor in Batu Pahat 📍Singgah Tapaw Peserai', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7566960778700442900'),
  ('Baryani Kari Kambing Wak Gondan', 'Food', 'Briyani Talam Wak Gondan 📍Baryani Kari Kambing Wak Gondan', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7566615092180176149'),
  ('The Burger Spot', 'Western', 'Roadside Burger Pattaya 📍The Burger Spot 87, Jalan Kota 2, Cahaya Kota Puteri, 81750 Masai, Johor Darul Ta''zim ⏰ 5.30pm - 1pm (Monday - Wednesday), 5.30pm - 2am (Friday - Saturday), 6pm - 2am (Sunday) Closed on Thursday', 1.4781741, 103.8959861, 'https://www.tiktok.com/@johorfoodie/video/7565842686024977684'),
  ('Pasar Tani Kekal Datin Halimah', 'Malay', 'Nasi Itik Gepuk Pasar Tani 📍Pasar Tani Kekal Datin Halimah', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7564733424716614933'),
  ('Kirin Coffee', 'Cafe', 'NEW Dopamine Cafe in JB 📍Kirin Coffee, Austin Perdana', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7563973508955409684'),
  ('Kafe Poh Kee', 'Noodles', 'Signature Cripsy Prawn Mee in Johor 📍Kafe Poh Kee @ Taman Abad 75, Jalan Dato Sulaiman, Taman Abad, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 5.30pm - 3.30am', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7563612943858928914'),
  ('Gubok Pawon', 'Malay', 'This Eldery Couple keeping Johor’s food heritage alive the traditional way 😍 At Gubok Pawon, owner Cik Jue and husband still serves the classic Nasi Ambang Johor with a whole chicken in a shared tray just like how it’s enjoyed back in the Kampung! 🌾 Dine in and experience the authentic Kampung vibes while sharing this hearty feast with your friends and family 🤍 ‼️Advance booking is required as they’re currently not accepting walk-ins. Gubok Pawon (Pondok Musafir) 📍Parit Yaani, Yong Peng, Johor Source & Photo: Johor Foodie', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7563557080360160532'),
  ('Ayam Penyet 3 Abdul', 'Western', 'RM18.90 Ayam Gepuk Chicken Chop 📍Ayam Penyet 3 Abdul', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7562129793374768405'),
  ('The OG! Quesadilla', 'Food', 'Known for brunch menu like The OG! Quesadilla 🌮, selections of bagels like Aussie Beef Bagel 🥯, cinnamon rolls 🧁 and more! 📍 Mid Valley Southkey JB 📆 Official opening date to be confirmed', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7561738992459336968'),
  ('Sup Gearbox Tulang Merah', 'Soup', 'Roadside Sup Gearbox Tulang Merah 📍@semaneesmu.my , Lake Garden, Bandar Seri Alam', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7561047006416866580'),
  ('Nasi Ayam Kee Chup', 'Malay', 'Nasi Ayam Kee Chup 📍24A, Jalan Dato Dalam, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 11am - 4pm (Close on Tuesday)', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7560906775206186258'),
  ('Laksa Utara', 'Noodles', 'RM6 Laksa Utara 📍 Dataran Niaga Taman Perling', 1.4714839, 103.7365473, 'https://www.tiktok.com/@johorfoodie/video/7560646747425377556'),
  ('Kopistry', 'Cafe', 'Dengdeng Nyet Sourdough Pizza 📍 Kopistry, Bandar Baru Uda', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7559535548491205908'),
  ('Rumah Kayu 1953', 'Malay', 'Rumah Kayu 1953 is a traditional eatery in Batu Pahat, Johor, that serves breakfast and lunch in a nostalgic Kampung setting. Located on Jalan Peserai Lama, it offers a variety of dishes such as nasi lemak, lontong, soto, and nasi beriani. Rumah Kayu 1953 📍JF 11, Jalan Peserai Lama, 83000 Batu Pahat, Johor ⏰ 7am - 11am (Closed on Tuesday)', 1.846123, 102.9506741, 'https://www.tiktok.com/@johorfoodie/video/7559123252283559175'),
  ('Ikan Bakar Medan', 'Malay', 'Ikan Bakar Medan 🇮🇩 This spot in JB serves the most authentic Indonesian-style Ikan Bakar and many more! 🤤 📍21, Jalan Permas 9/1, Bandar Baru Permas Jaya, 81750 Masai, Johor Darul Ta''zim, Malaysia ⏰ 5:30PM - 2AM (Closed on Monday)', 1.4781741, 103.8959861, 'https://www.tiktok.com/@johorfoodie/video/7558789648579923207'),
  ('Keropok Gemuk', 'Food', 'Keropok Gemuk Johor Bahru 📍Dataran Niaga, Taman Perling, 81200 Johor Bahru, Johor Darul Ta''zim', 1.5048156, 103.7158165, 'https://www.tiktok.com/@johorfoodie/video/7557956852487671048'),
  ('Mahgoub @ Nong Chik', 'Malay', 'One of JB’s most popular makan spots serving juicy shawarma and local favourites like nasi lemak and burgers! 🌯🔥 Mahgoub @ Nong Chik 📍 41, Jalan Kolam Air, Taman Nong Chik, 80100 Johor Bahru, Johor Darul Ta''zim ⏰ 9am – 12am', 1.4688389, 103.7445967, 'https://www.tiktok.com/@johorfoodie/video/7556172843520757012'),
  ('Cendol Akbar', 'Bakery', '5 Local Must-Try Dessert Spots in JB! 🍧 Head over to Batu Pahat for this local approved desserts spots: 📍Cendol Akbar 📍Rojak Tasek-Y 📍Famous Fruit Rojak 📍Wooden Box 📍Lulu Yogurt 📣Get up to 20% OFF total bill with Grab Dine Out Deals at selected eateries 🔥 Grab these deals now on the Grab app!', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7554305476129869063'),
  ('Arabic Shawarma', 'Malay', 'Arabic Shawarma 📍Kampung Melayu Kangkar Pulai', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7553980665524489492'),
  ('The Taste of Chao', 'Soup', 'Bold flavours, nostalgic comfort. At Taste of CHAO in JB, every bowl of soup is brewed with Spritzer natural mineral water — bringing out a cleaner, purer taste in every sip. 🍜 The Taste of Chao 📍25, Jalan Balau, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 8AM - 10PM (Close on Wednesdays)', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7553538146550549778'),
  ('Ruby''s Ice Cream Boutique', 'Food', 'Matcha Slushie at JB Bazar Karat 📍@rubysicecreamboutique , Pasar Karat JB ⏰ Thursday - Sunday (8PM-1AM)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7552853357212323080'),
  ('Nasi Lemak Bunjut Cik Ta', 'Malay', 'Nasi Lemak Bunjut Cik Ta 📍Taman Nusantara, Gelang Patah', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7551742863424490772'),
  ('Pal Litt', 'Dessert', 'Langkawi’s Famous Ice Cream Since 1991 🔥 📍Pal Litt, Tebing BDO', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7550998733312232722'),
  ('Mayoh Nasi Kabu', 'Malay', 'Nasi kerabu bedak sejuk 📍Mayoh Nasi Kabu, Taman Bukit Mutiara', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7549141359353990420'),
  ('Jeruk Campoq', 'Food', 'Jeruk Campoq namplawan 📍Tebing Bandar Dato’ Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7548770143526997269'),
  ('Cheesecake Yogurt Mochi', 'Bakery', 'Cheesecake Yogurt Mochi 📍Jalan Indah 13/3, Taman Bukit Indah, 79100 Iskandar Puteri, Johor ⏰ 7pm until finish 📆13/9 & 14/9 (Saturday & Sunday)', 1.475999, 103.6576651, 'https://www.tiktok.com/@johorfoodie/video/7548708873276820743'),
  ('Hotteok', 'Food', 'Beef Cheese Hotteok 📍Amphitheatre Tebing Bandar Dato’ Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7548683160196812039'),
  ('Rojak Hj Padil', 'Local', 'Located at Bandar Baru Uda, Rojak Hj Padil is a popular Rojak spot managed by an elderly couple ❤️ Here, they''re selling assorted Rojak like Rojak Buah, Rojak Petis, Rojak Tahu, Rojak Keropok Lekor and Tahu Bakar 😋 Rojak Petis & Rojak Tahu is priced at only RM6, while Rojak Buah is priced at RM7 Rojak Hj Padil 📍Jalan Padi Mahsuri 12, Bandar Baru Uda, Johor Bahru, Johor ⏰3pm - 6:30pm (Closed on Friday & Saturday) ✅Muslim-owned', 1.4954332, 103.7187948, 'https://www.tiktok.com/@johorfoodie/video/7547974021380443410')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('2AM Nasi Lemak Atok Nenek', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r141-p0-2am-nasi-lemak-atok-nenek.jpg'),
  ('Hand Pressed Juice', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r142-p0-hand-pressed-juice.jpg'),
  ('Quesillo', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r143-p0-quesillo.jpg'),
  ('Crab Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r144-p0-crab-restaurant.jpg'),
  ('Tai Zhi 81 Kopitiam', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r145-p0-tai-zhi-81-kopitiam.jpg'),
  ('Tim Hortons', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r146-p0-tim-hortons.jpg'),
  ('Feca Kopi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r147-p0-feca-kopi.png'),
  ('Restoran Hua Mui', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r148-p0-restoran-hua-mui.jpg'),
  ('HEYTEA', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r149-p0-heytea.png'),
  ('Nasi Gulai Khopeh', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r150-p0-nasi-gulai-khopeh.jpg'),
  ('Tauhu Crispy Dapur Yumi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r151-p0-tauhu-crispy-dapur-yumi.jpg'),
  ('TOKSU CHICKEN', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r152-p0-toksu-chicken.jpg'),
  ('Singgah Tapaw Peserai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r153-p0-singgah-tapaw-peserai.jpg'),
  ('Baryani Kari Kambing Wak Gondan', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r154-p0-baryani-kari-kambing-wak-gondan.jpg'),
  ('The Burger Spot', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r155-p0-the-burger-spot.jpg'),
  ('Pasar Tani Kekal Datin Halimah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r156-p0-pasar-tani-kekal-datin-halimah.jpg'),
  ('Kirin Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r157-p0-kirin-coffee.jpg'),
  ('Kafe Poh Kee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r158-p0-kafe-poh-kee.jpg'),
  ('Gubok Pawon', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r159-p0-gubok-pawon.jpg'),
  ('Ayam Penyet 3 Abdul', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r160-p0-ayam-penyet-3-abdul.jpg'),
  ('The OG! Quesadilla', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r161-p0-the-og-quesadilla.jpg'),
  ('Sup Gearbox Tulang Merah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r162-p0-sup-gearbox-tulang-merah.jpg'),
  ('Nasi Ayam Kee Chup', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r163-p0-nasi-ayam-kee-chup.jpg'),
  ('Laksa Utara', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r164-p0-laksa-utara.jpg'),
  ('Kopistry', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r165-p0-kopistry.jpg'),
  ('Rumah Kayu 1953', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r166-p0-rumah-kayu-1953.jpg'),
  ('Ikan Bakar Medan', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r167-p0-ikan-bakar-medan.jpg'),
  ('Keropok Gemuk', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r168-p0-keropok-gemuk.png'),
  ('Mahgoub @ Nong Chik', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r169-p0-mahgoub-nong-chik.png'),
  ('Cendol Akbar', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r170-p0-cendol-akbar.jpg'),
  ('Arabic Shawarma', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r171-p0-arabic-shawarma.jpg'),
  ('The Taste of Chao', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r172-p0-the-taste-of-chao.png'),
  ('Ruby''s Ice Cream Boutique', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r173-p0-ruby-s-ice-cream-boutique.jpg'),
  ('Nasi Lemak Bunjut Cik Ta', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r174-p0-nasi-lemak-bunjut-cik-ta.jpg'),
  ('Pal Litt', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r175-p0-pal-litt.jpg'),
  ('Mayoh Nasi Kabu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r176-p0-mayoh-nasi-kabu.jpg'),
  ('Jeruk Campoq', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r177-p0-jeruk-campoq.jpg'),
  ('Cheesecake Yogurt Mochi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r178-p0-cheesecake-yogurt-mochi.jpg'),
  ('Hotteok', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r179-p0-hotteok.jpg'),
  ('Rojak Hj Padil', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r180-p0-rojak-hj-padil.jpg')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Frenché Roast Café', 'Malay', 'Spotted New Cloud Drinks Series in JB! 🥤 The New Cloud Drinks series comes with 6 different unique flavours, and also checkout their limited time only Malaysian pastries! 🥐🇲🇾 Frenché Roast Café 📍Molek, Lot B3 No.7 Molek Pine 3 Apartment, Jalan Molek 1/27, Taman Molek, 81100 Johor Bahru, Johor Darul Ta''zim, Malaysia ⏰9AM - 7PM (Daily) 📍Kulai, 185A, Jalan Kenanga 29/4, Bandar Indahpura, 81000 Kulai, Johor Darul Ta''zim, Malaysia ⏰8AM - 9PM (Weekdays) | 8AM - 10PM (Weekends)', 1.6419232, 103.6188821, 'https://www.tiktok.com/@johorfoodie/video/7546575022559743239'),
  ('Gogirou Korean BBQ', 'Korean', 'Ala-Carte Korean BBQ buffet in JB from only RM57🔥 📍@Gogirou Korean BBQ @ Toppen JB*no pork no lard', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7545786923349052692'),
  ('The Kiosk', 'Beverage', 'Cute jelly drinks 📍The Kiosk @ Toppen', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7545728947703631124'),
  ('Safiah Tulisman Bakery', 'Bakery', 'RM1.80 Dessert Café in Johor 🤩 Safiah Tulisman Bakery 📍 4, Jalan Bertam 14, Taman Daya, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 12pm - 9pm (Closed on Thursday)', 1.5395883, 103.765641, 'https://www.tiktok.com/@johorfoodie/video/7545360880238611713'),
  ('Fufootea', 'Malay', 'Spotted unique Nasi Lemak Smoothie 😮 🌟 Merdeka Special BUY 2 FREE 1 Purchase any 2 items from the menu & get 1 FREE drink from the Malaysia Series! @Fufootea 📍Taman Mount Austin ⏰12pm-12am 📍Paradigm Mall JB ⏰10am-10pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7544660684471110930'),
  ('Siblings Gelato Lab', 'Cafe', 'New cafe in JB serving homemade gelato, drinks, mains, and more! 🍨 You can even make your own gelato here 😍 @siblingsgelato Lab 📍17-02, Jalan Austin Heights 8/3, Taman Mount Austin, 81100 Johor Bahru, Johor ⏰12pm - 10pm (Closed on Tuesday)', 1.5526558, 103.775114, 'https://www.tiktok.com/@johorfoodie/video/7544317801624800532'),
  ('365 Bakery', 'Malay', 'One of the best Swiss Rolls in Malaysia?👀 Comes in 6 irresistible flavours: 💚 Tropical Breeze 🍫 Nama Chocolate 🍊 Japanese Yuzu Cream Cheese 🍠 Taro Seaweed Chicken Floss 👑 King of Malaysia (Musang King) ⚫ Silky Black Sesame Kinako 🎉 Merdeka Bonus — 31% OFF (1 Day Only, 31 Aug) 🎉 ✅ King of Malaysia Mochi Brioche ✅ King of Malaysia Swiss Roll ✅ Musang King Cream Puff 📍@365 Bakery MY , Austin Crest [no pork, no alcohol] ⏰ 10am - 9pm (daily)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7544224204124622088'),
  ('Roti Baghdad', 'Bread', 'Roti Baghdad 📍Wisma BBU', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7543947302013062420'),
  ('Samyang Omelette', 'Food', 'Spicy Samyang Omelette @juan.shangyin 📍70, Jalan Jaya Putra 7/2, Bandar Jaya Putra, 81100 Johor Bahru, Johor Darul Ta''zim (Opposite Panda Market, Austin Crest) ⏰ 9pm - 12am', 1.57706, 103.7682979, 'https://www.tiktok.com/@johorfoodie/video/7543602926476938514'),
  ('Din Cakoi', 'Food', 'Freshly made pau goreng, cakoi and kuih 📍Din Cakoi, BBU', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7542839766849473809'),
  ('Yang Guo Fu Malatang', 'Malay', 'Yang Guo Fu Malatang serves up the famous Sichuan-style Malatang hotpot, where you can pick your favorite ingredients and enjoy them in their signature spicy, numbing broth 🍲 With fresh meats, seafood, veggies, and noodles, it’s a flavorful feast you can customize your way! Yang Guo Fu Malaysia 📍AEON Mall Bandar Dato'' Onn, Johor Bahru, Johor ⏰ 10am - 10pm (Daily) no pork no lard', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7542395699812371720'),
  ('Ah Sheng Lok Lok', 'Lok Lok', '100 Types of Lok Lok in JB! Ah Sheng Lok Lok 📍 36, Jln Permas 10/6, Bandar Baru Permas Jaya, 81750 Masai, Johor Darul Ta''zim ⏰ 4pm - 3am', 1.4781741, 103.8959861, 'https://www.tiktok.com/@johorfoodie/video/7540513821346073864'),
  ('Saburo Ramen', 'Japanese', 'Lakeside Ramen Stall in JB 🍜 📍@saburoramen66 [non-halal] ⏰ 6:30PM - 10:30PM Closed on Wednesdays', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7540252773535812872'),
  ('Bostun Steam Lala', 'Noodles', 'RM11 Lala Mee Hoon Bostun Steam Lala 📍 Jalan Setia 3/6, Taman Setia Indah, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 12pm - 9pm', 1.5715514, 103.7577952, 'https://www.tiktok.com/@johorfoodie/video/7539863479566552328'),
  ('Johara Coffee & Matcha', 'Cafe', 'First JDM themed cafe in JB 📍Johara Coffee & Matcha, Masai', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7538794286918290689'),
  ('Tokiwa Osaka', 'Malay', 'First Irori Style Japanese Restaurant in Johor! 🍢 This newly opened semi-fine dining spot in JB, called Tokiwa Osaka, serves authentic Osaka-style Irori dishes! 😍 Highlights menu: 🍜Flavorful Oden 🥩Premium A5 Wagyu Beef 🍲Delicious Unagi Claypot Rice and much more! Perfect for a cozy dinner or a special night out. Come experience the taste of Japan right here in Johor! 🎌 Tokiwa Osaka 📍 47A, Jalan Eko Botani 3/4, Taman Eko Botani, 79100 Iskandar Puteri, Johor, Malaysia, Johor Darul Ta''zim ⏰ 3pm - 11pm (Daily)', 1.4396539, 103.6203292, 'https://www.tiktok.com/@johorfoodie/video/7538736962774011144'),
  ('Oiso Korean Restaurant', 'Korean', 'This restaurant has been serving authentic Korean flavours for over 10 years — 🇰🇷 Oiso Korean Restaurant has just opened at AEON Mall Bandar Dato’ Onn! 🎉 Oiso Korean Restaurant 📍 Lot GB 1, Aeon Mall, Jln Dato'' Onn 3, Bandar Dato Onn, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 10AM - 10PM (Daily)', 1.5452652, 103.7585042, 'https://www.tiktok.com/@johorfoodie/video/7538641886374808840'),
  ('SHUYI Grass Jelly & Tea', 'Malay', 'ShuYi has finally arrived in JB! And yes… half your cup is ALL toppings 😍✨ 🎉 Grand Opening Specials 📅 Aug 15–17 → Buy 1, Get 1 FREE (perfect excuse to bring a buddy!) 💰 From Aug 10 → Spend RM20 in a single receipt + follow @shuyi_my & @shuyi_jb to join our Lucky Draw. 🎥 Winners revealed live on FB: Aug 23, 24, 30, 31 So… who’s up for a boba date? 🧋💚 SHUYI Grass Jelly & Tea @ Austin Crest 📍39 Jalan Jaya Putra 7/9, Taman JP Perdana, 81100 Johor Bahru, Johor ⏰ 11am - 11pm Other outlet: Pavilion Kuala Lumpur, Pavilion Bukit Jalil, TRX, Sunway Pyramid, KK Imago', 1.5785835, 103.771463, 'https://www.tiktok.com/@johorfoodie/video/7538418461228240146'),
  ('QQ Mee', 'Noodles', '🍜 Springy noodles, rich flavours. At QQ Mee, every bowl is made with care — and their secret? They use Spritzer natural mineral water to make the broth smoother, clearer, and more flavourful. One taste and you’ll know why it’s called QQ! 😋 QQ Mee 📍4, Jalan Nakhoda 7, Taman Ungku Tun Aminah, 81300 Johor Bahru, Johor Darul Ta''zim ⏰ 8:30AM - 10PM (Close on Wednesdays)', 1.5223166, 103.6579011, 'https://www.tiktok.com/@johorfoodie/video/7538287891668045074'),
  ('Loco Boys', 'Food', 'Birria Mozza 📍Loco Boys, Nasa City', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7537638358932131079'),
  ('Restoran Kam Long Ah Zai', 'Seafood', 'Famous Curry Fish Head in JB! Restoran Kam Long Ah Zai 📍74, Jalan Wong Ah Fook, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta’zim ⏰ 8am - 4pm (close on Monday)', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7537629448380714258'),
  ('Wah Cai', 'Chinese', 'Must-try Fried Nian Gao (Kuih Bakul) Wah Cai 3-in-1 Chinese Cake 📍 86, Jalan Pahlawan 2, Taman Ungku Tun Aminah, 81300 Skudai, Johor Darul Ta''zim ⏰ 9:30am - 4:30pm (Closed on Wed & Fri)', 1.5224052, 103.664554, 'https://www.tiktok.com/@johorfoodie/video/7537269139937840391'),
  ('Burnt Cheese Coffee', 'Cafe', 'Burnt Cheese Coffee 📍Jalan Pelanduk, Taman Scientex', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7536208452511665426'),
  ('Kampung Heritage', 'Malay', 'Traditional Malay Cuisine in Johor Bahru 😍 Kampung Heritage 📍54, Jln Beringin, Taman Melodies, 80250 Johor Bahru, Johor ⏰11:30am - 10pm (Daily)', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7536156079340784914'),
  ('Renaissance Hotel JB', 'Malay', 'Kickstart your weekend with a feast! 🍽️✨ Renaissance Hotel Johor Bahru is serving up an indulgent buffet dinner every Friday & Saturday, now till September! From flavourful Asian-Malaysian delights to juicy Western-style grills, there’s something for everyone — and every bite is worth coming back for. 😍🔥 Tag your makan gang — it’s time to plan your next dinner outing! 👨‍👩‍👧‍👦🍴 📍 Renaissance Hotel JB 🗓️ Every Friday & Saturday (till Sept) ⏰ 6:30PM onwards 💰 RM188 per pax', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7535673693280750856'),
  ('Fried Rice', 'Seafood', 'Crab meat fried rice 📍Taman Scientex Pasir Gudang', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7535410510984908039'),
  ('Chicken Burger', 'Western', 'RM3.99 Crispy Chicken Burger 📍Jalan Layang 16, Taman Perling', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7535042903857466642'),
  ('Niko Niko Onigiri', 'Cafe', 'New Aquarium Japanese Cafe serving handmade onigiri in Johor 🍙 📍Niko Niko Onigiri 28, Jalan Dedap 7, Taman Johor Jaya, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 8.30am - 8.30pm (close on Tuesday)', 1.5416153, 103.8043558, 'https://www.tiktok.com/@johorfoodie/video/7534947354089180434'),
  ('Mana Mart', 'Malay', 'Known for 20+ flavours of tanghulu 🍓🍇! Mana Mart also offers snacks, ready-to-eat meals, desserts, and everyday essentials all in one place 🤩 And yes, all Mana Mart products are halal-certified! ✅ @manamartmalaysia 📍T-045, Third Floor @ Mid Valley Southkey, Johor Bahru (inside Mix Store) ⏰ 10am - 10pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7534658598685740306'),
  ('The Warung Kita', 'Warung', 'All-You-Can-Eat Local Breakfast Buffet for RM24+ 📍The Warung Kita', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7533546999791078674'),
  ('Nasi Kandar Melayu', 'Malay', 'Roadside Nasi Kandar Melayu 📍Persisiran Perling, Taman Perling', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7533185268665339143'),
  ('Krispy Kreme', 'Bakery', 'Spotted world-famous Krispy Kreme doughnut opening its FIRST outlet in Johor 😍🍩 Known for its hot, freshly glazed doughnuts, Krispy Kreme offers a variety of flavours including Original Glazed, Chocolate Iced Glazed, Strawberry Sprinkles, and more! 📍Mid Valley Southkey (opposite Family Mart) 📆 Official opening date to be confirmed', 1.5009732, 103.7777493, 'https://www.tiktok.com/@johorfoodie/video/7532093407997496583'),
  ('Kek Batik Cedok', 'Bakery', 'Kek Batik Cedok 📍Nearby Masjid Taman Perling', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7532079361734823175'),
  ('Rumah Makan Haji Sendut', 'Malay', 'Malay cuisine in a 108 years old Rumah Melayu 😍 📍Rumah Makan Haji Sendut @ Kampung Nong Chik, Johor Bahru', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7530978241402670343'),
  ('Briyani', 'Food', 'Briyani with Brinjal Tokku 📍Jalan Susur 4, Larkin', 1.472639, 103.6710854, 'https://www.tiktok.com/@johorfoodie/video/7530594806842576135'),
  ('Miyakori Coffee', 'Cafe', 'Kyoto-style Japanese Cafe ☕🇯🇵 📍 @Miyakori_Coffee_Official', 1.3966246, 103.6272432, 'https://www.tiktok.com/@johorfoodie/video/7530478250703801618'),
  ('Warung Bini Saya', 'Malay', 'RM12 Nasi Ayam Khao Mok 📍Warung Bini Saya, Jalan Sena 9, Taman Rinting', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7530217191552339207'),
  ('Dubai Chocolate', 'Food', 'Dubai Chocolate Strawberry 📍Tebing Bandar Dato Onn', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7528375551296507154'),
  ('Pisang', 'Food', 'Pisang Ungu & Pisang Raja 📍Tebing Bandar Dato Onn', 1.4976943, 103.6965747, 'https://www.tiktok.com/@johorfoodie/video/7528009014513339666'),
  ('Nasi Lemak', 'Malay', 'Midnight Nasi Lemak Berlauk 📍Menara Kastam Larkin', 1.545441, 103.8039909, 'https://www.tiktok.com/@johorfoodie/video/7527632596788972808')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Frenché Roast Café', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r181-p0-french-roast-caf.jpg'),
  ('Gogirou Korean BBQ', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r182-p0-gogirou-korean-bbq.jpg'),
  ('The Kiosk', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r183-p0-the-kiosk.jpg'),
  ('Safiah Tulisman Bakery', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r184-p0-safiah-tulisman-bakery.png'),
  ('Fufootea', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r185-p0-fufootea.jpg'),
  ('Siblings Gelato Lab', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r186-p0-siblings-gelato-lab.jpg'),
  ('365 Bakery', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r187-p0-365-bakery.jpg'),
  ('Roti Baghdad', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r188-p0-roti-baghdad.jpg'),
  ('Samyang Omelette', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r189-p0-samyang-omelette.jpg'),
  ('Din Cakoi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r190-p0-din-cakoi.jpg'),
  ('Yang Guo Fu Malatang', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r191-p0-yang-guo-fu-malatang.jpg'),
  ('Ah Sheng Lok Lok', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r192-p0-ah-sheng-lok-lok.png'),
  ('Saburo Ramen', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r193-p0-saburo-ramen.jpg'),
  ('Bostun Steam Lala', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r194-p0-bostun-steam-lala.png'),
  ('Johara Coffee & Matcha', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r195-p0-johara-coffee-matcha.jpg'),
  ('Tokiwa Osaka', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r196-p0-tokiwa-osaka.jpg'),
  ('Oiso Korean Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r197-p0-oiso-korean-restaurant.jpg'),
  ('SHUYI Grass Jelly & Tea', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r198-p0-shuyi-grass-jelly-tea.jpg'),
  ('QQ Mee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r199-p0-qq-mee.jpg'),
  ('Loco Boys', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r200-p0-loco-boys.jpg'),
  ('Restoran Kam Long Ah Zai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r201-p0-restoran-kam-long-ah-zai.jpg'),
  ('Wah Cai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r202-p0-wah-cai.jpg'),
  ('Burnt Cheese Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r203-p0-burnt-cheese-coffee.jpg'),
  ('Kampung Heritage', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r204-p0-kampung-heritage.jpg'),
  ('Renaissance Hotel JB', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r205-p0-renaissance-hotel-jb.jpg'),
  ('Fried Rice', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r206-p0-fried-rice.jpg'),
  ('Chicken Burger', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r207-p0-chicken-burger.jpg'),
  ('Niko Niko Onigiri', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r208-p0-niko-niko-onigiri.jpg'),
  ('Mana Mart', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r209-p0-mana-mart.jpg'),
  ('The Warung Kita', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r210-p0-the-warung-kita.jpg'),
  ('Nasi Kandar Melayu', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r211-p0-nasi-kandar-melayu.jpg'),
  ('Krispy Kreme', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r212-p0-krispy-kreme.jpg'),
  ('Kek Batik Cedok', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r213-p0-kek-batik-cedok.jpg'),
  ('Rumah Makan Haji Sendut', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r214-p0-rumah-makan-haji-sendut.jpg'),
  ('Briyani', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r215-p0-briyani.jpg'),
  ('Miyakori Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r216-p0-miyakori-coffee.jpg'),
  ('Warung Bini Saya', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r217-p0-warung-bini-saya.jpg'),
  ('Dubai Chocolate', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r218-p0-dubai-chocolate.jpg'),
  ('Pisang', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r219-p0-pisang.jpg'),
  ('Nasi Lemak', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r220-p0-nasi-lemak.jpg')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Sang Seafood', 'Seafood', 'SANG Seafood is now Halal certified ✅ Known for serves seafood menu like Chilli Crab, Fried Seabass with Nyonya Sauce and many more 🔥 SANG Seafood 📍29, Business Boulevard Central Park, Jalan Aliff 6, Taman Damansara Aliff, 81200 Johor Bahru ⏰ 11am - 11pm (Daily)', 1.5104836, 103.7183694, 'https://www.tiktok.com/@johorfoodie/video/7527247765353663751'),
  ('1975 Toast & Coffee', 'Cafe', 'RM10 Tiramisu & Cromboloni in Johor 😍🍰 @1975Toast&Coffee 📍52, Jln Beringin, Taman Melodies, 80250 Johor Bahru, Johor ⏰ 9am - 12pm (Daily)', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7527240381084339463'),
  ('MSK Trading', 'Durian', 'Durian Buffet for ONLY RM88?! 🤯💥 Enjoy 1 full hour of unlimited durians indoors with air-con! Just add RM35 and you can get Musang King! 😍 You can also order online and enjoy the king of fruits delivered to your doorstep! 👑📦 WhatsApp 📞 012-374 7304 MSK Trading 📍 61, Jalan Kebudayaan 4, Taman Universiti Skudai, 81300 Johor Bahru, Johor Darul Ta''zim ⏰ 11am - 10:30pm (Daily)', 1.5412101, 103.6291347, 'https://www.tiktok.com/@johorfoodie/video/7527223868138720520'),
  ('The Tiny Lake', 'Dessert', 'Hidden Panda Theme Dessert spot in Senai 📍The Tiny Lake Jalan Senai 10, Kampung Baru Senai, 81400 Senai, Johor Darul Ta''zim ⏰ 3-11pm', 1.6024627, 103.6455687, 'https://www.tiktok.com/@johorfoodie/video/7527127271501614344'),
  ('Gather Pizza', 'Pizza', 'This cafe in Johor serves homemade sourdough pizza, pasta and more 😍 Gather Pizza 📍G08-01 ECO NEST APARTMENTS JALAN EKO BOTANIC 3/5, TAMAN, Persiaran Eko Botani, 79100 Iskandar Puteri, Johor ⏰6pm - 9:30pm (Mon - Thursday); 12pm - 3pm; 6pm - 9:30pm (Fri - Sun)', 1.4599636, 103.6294022, 'https://www.tiktok.com/@johorfoodie/video/7526876973327518994'),
  ('Mofad Durian', 'Durian', 'Durian Premium Timbang Isi 😍 📍@Mofad Durian , Jalan Padi Makmur, Bandar Baru Uda, 85200 Johor Bahru, Johor Darul Ta''zim', 1.4865888, 103.7201167, 'https://www.tiktok.com/@johorfoodie/video/7526767409613573384'),
  ('Epok Epok OKU', 'Snack', 'Epok Epok OKU 📍Jalan Setia 4/12, Taman Setia Indah, Johor Bahru', 1.5742132, 103.7491173, 'https://www.tiktok.com/@johorfoodie/video/7526505244600061202'),
  ('BreakRoom', 'Cafe', 'Spotted NEW cafe inside a warehouse in JB 😍 📍@BreakRoomJB', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7525429334572649746'),
  ('House89 Steak Mansion', 'Steakhouse', 'Beef Wellington for only RM149 in JB!? 🤩 House89 Steakhouse in JB serves HUGE Tomahawk and more than 100+ menu from breakfast, lunch to dinner!😍 House89 Steak Mansion Cawangan Alor Setar, Kedah 📍 No 180-G, Kompleks Darulaman, Lebuhraya Darulaman, Bandar Alor Setar, 05150 Alor Setar Kedah. ⏰ 3.00 p.m - 11.00 p.m (everyday) 📞 https://wa.me/+60122293189 House89 Steak Mansion Cawangan Mydin Tunjong, Kota Bharu 📍 No.S-10,S-11, LOT PT666 Mydin Tunjung Hypermarket, Bandar Baru Tunjung, 16010 Kota Bharu, Kelantan. ⏰ 10.00 a.m - 10.00p.m (everyday) 📞 https://wa.me/+601156688989 Cawangan Bandar Dato Onn, Johor Bahru 📌 No 42, Jln Perjiranan 4/2,Bandar Dato Onn Johor Bahru Johor 81100 Johor Darul Takzim Monday - Sunday ⏰12.00 p.m - 11.00 p.m 📞 https://wa.me/+60174018989 House89 Steak Mansion Cawangan BANGI 📍 House89 Steak Mansion Outlet 5 : 32 & 33, Jalan Seri Putra 1/2, Bandar Seri Putra, 43000 Kajang, Selangor ⏰12.00 p.m - 11.00 p.m (everyday) 📞 https://wa.me/+60133099989 HOUSE89 STEAK MANSION BANGI SSM NO : 202101039970 ✅ Muslim-owned ✅ Using Halal ingredients only', 1.5620979, 103.7341714, 'https://www.tiktok.com/@johorfoodie/video/7524962690851261704'),
  ('Layer Bakehouse', 'Bakery', 'All-things Sourdough Neighbourhood Cafe in JB! 🍞 Layer Bakehouse 📍 24, Jalan Bakti 65, Mutiara Rini, 81300 Skudai, Johor Darul Ta''zim ⏰ 9am - 6:30pm (Closed on Monday)', 1.5214852, 103.6270394, 'https://www.tiktok.com/@johorfoodie/video/7524921094520835346'),
  ('Frenché Roast', 'Cafe', 'Frenché Roast is now brewing in Kulai! ☕️ Their second outlet is officially open — serving up buttery croissants, fragrant coffee, and even hearty lunch & dinner options 🍽️ Whether you’re here for a quick coffee break or a full-on meal, Frenché Roast’s got you covered 💛 Come have a taste of their signature pastries and chill vibes today! Frenché Roast @Kulai 📍185A, Jalan Kenanga 29/4, Bandar Indahpura, 81000 Kulai, Johor ⏰ Mon–Thurs: 8AM–9PM | Fri–Sun: 8AM–10PM', 1.6428606, 103.6176831, 'https://www.tiktok.com/@johorfoodie/video/7524589624069491986'),
  ('Kafe Saliha', 'Malay', 'RM10 OFF when you use foodpanda’s SYOK10 voucher for this classic Malaysian food near JDT Stadium! Kafe Saliha 📍 Jalan Prisma 1, 81550 Gelang Patah, Johor Darul Ta''zim ⏰ 6:30am - 5pm (Daily)', 1.4348188, 103.5909832, 'https://www.tiktok.com/@johorfoodie/video/7522760067674983698'),
  ('Waffle Delight', 'Dessert', 'This hidden spot in JB serve unique home based charcoal waffle and waffle with up to 6 flavours! 🤩 You can even mix them! Do try this new Durian flavour waffle! 🤤 Waffle Delight 📍 71, Jalan Sri Pelangi, Taman Pelangi, 80400 Johor Bahru, Johor Darul Ta''zim ⏰ 2pm - 6pm | 8:30pm - 10:30pm *Walk-in available*', 1.4782445, 103.777516, 'https://www.tiktok.com/@johorfoodie/video/7522733568150228231'),
  ('Soto Warisan Hj Patoni', 'Malay', 'Famous Soto Warisan Hj Patoni 📍Terminal Larkin', 1.4957257, 103.7425347, 'https://www.tiktok.com/@johorfoodie/video/7522435358324280594'),
  ('Gobok Budak Johor 1', 'Durian', 'Cheap Premium Durian. Promo changes daily 📍@Gobok Budak Johor 1 , Taman Dahlia, Johor Bahru', 1.5115682, 103.6984336, 'https://www.tiktok.com/@johorfoodie/video/7520570090689924359'),
  ('Jungle House', 'Beverage', 'Sweet news, Johor! Jungle House is now open at Mid Valley Southkey! 🐝✨ Drop by their brand new outlet and enjoy our Buy 1 Free 1 drinks — a limited-time, in-store exclusive you won’t want to miss! 🍹💛 Explore over 20 types of raw honey, from floral to bitter, sweet to sour! Try their bestseller, Jungle’s Heart, made by bees that collect nectar from strawberry flower blossoms 🍓 Check out their stunning beehive-inspired ceiling art, crafted from reusable shoelaces — it’s as beautiful as it is eco-friendly 🌿 Looking for healthy, natural sweetness? Jungle House got you covered! Come visit Jungle House Mid Valley Southkey today — your honey adventure awaits! 📍LG-017, Mid Valley Southkey, JB ⏰ 10am - 10pm (Daily)', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7520201787891010823'),
  ('MKe Harmony Cafe', 'Cafe', 'Homey Chinese-Western Cafe in Kulai 🤩 MKe Harmony Cafe 📍 5457A, Jalan Kenari 20, Bandar Putra Kulai, 81000 Kulai, Johor Darul Ta''zim ⏰ 11am - 9pm (Daily)', 1.6586412, 103.6282935, 'https://www.tiktok.com/@johorfoodie/video/7520108347320765714'),
  ('Nasi Lemak Abang Sudin', 'Malay', 'Nasi Lemak Asam Pedas 📍Nasi Lemak Abang Sudin, Taman Scientex,PG', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7519834803752013074'),
  ('FirePitz', 'Steakhouse', 'Open Flame Dining Steakhouse in JB!🥩🔥 This spot in JB has a unique way to cook their steaks on an open flame griller and a chef that used to work at Gordon Ramsey Singapore! 😱 So you know it''s good! 🤩 Come check out their exclusive menu where you can try out all their different steaks! 🤤 FirePitz 📍 2A, PTD 195458, Jalan Horizon Perdana 6, Horizon Hills, 79100 Iskandar Puteri, Johor Darul Ta''zim ⏰ 12pm - 2:30pm | 5:30pm - 10pm (Daily)', 1.4614417, 103.6230874, 'https://www.tiktok.com/@johorfoodie/video/7519084225128074514'),
  ('Talam Durian', 'Durian', 'Talam Durian 📍Medan Selera RHD Kota Tinggi', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7519059148567317768'),
  ('Sunday Morning Coffee Shop', 'Cafe', 'Japanese Inspired Coffee Shop a film lab in JB! 📍Sunday Morning Coffee Shop 124, Jalan Trus, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 9am - 5pm (close on Wednesdays)', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7519046547955305736'),
  ('Pink Matcha & Coffee Cart', 'Cafe', 'Pink Matcha & Coffee Cart 📍Bandar Dato’ Onn', 1.5606008, 103.7371091, 'https://www.tiktok.com/@johorfoodie/video/7517626613303954695'),
  ('Noodles Ice Cream', 'Dessert', 'Noodles Ice Cream 📍 Penjaja Jalan Pelanduk', 1.4870765, 103.7607211, 'https://www.tiktok.com/@johorfoodie/video/7516500161254673671'),
  ('Lan Xi', 'Fried Chicken', 'Taiwan Style Cheesy Stuffed Fried Chicken LAN XI 📍234, Jln Kenanga 29/8, Taman Indahpura, 81000 Kulai, Johor ⏰ 11AM - 11PM', 1.6438791, 103.6066531, 'https://www.tiktok.com/@johorfoodie/video/7516394606460800274'),
  ('Panggungkopi', 'Cafe', 'New Cosy Coffee Spot in JB Town ☕️ N0. 1438 Panggungkopi 📍47atas, Jalan Tan Hiok Nee, Bandar Johor Bahru, 80000 Johor Bahru, Johor Darul Ta''zim ⏰ 10AM - 7PM (Closed on Monday)', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7515374484753255698'),
  ('Bob Rojak', 'Rojak', 'Famous Bob Rojak 📍Taman Suria, Nearby Giant Southern City', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7515004078984875271'),
  ('Wildbird', 'Fried Chicken', 'Malaysia’s First Fried Chicken Blind Box 🍗😍 Join the Name the Flavour contest and stand a chance to win a year’s supply of fried chicken! 😱 Dare to taste the mystery? 🔥 @WILDBIRD 📍15, Jalan Perjiranan 4/6, Bandar Dato Onn 81100 Johor Bahru, Johor', 1.5624516, 103.7329078, 'https://www.tiktok.com/@johorfoodie/video/7514632493627280648'),
  ('Bakeman', 'Cafe', 'A Hidden Weekend-Only Cafe in JB’s Old House! Serving up all things homemade — and yes, it’s super cosy inside✨ 📍 Bakeman 14a, Jalan Datuk Kadi, Kampung Bahru, 80100 Johor Bahru, Johor ⏰ Open weekends only | 12PM – 7PM', 1.4688389, 103.7445967, 'https://www.tiktok.com/@johorfoodie/video/7514546245814324487'),
  ('Mochi Bomb', 'Dessert', 'Mochi Bomb 📍 Tebing Bandar Dato Onn', 1.5521497, 103.7367564, 'https://www.tiktok.com/@johorfoodie/video/7513890651675643143'),
  ('Restoran Jit Seng', 'Chinese', 'Classic Malaysian Chinese Cuisine with Big Flavours in JB!🤤 Restoran Jit Seng 📍 2, Jalan Permas 9/3, Bandar Baru Permas Jaya, 81750 Masai, Johor Darul Ta''zim ⏰ 2PM - 11PM (Daily)', 1.4781741, 103.8959861, 'https://www.tiktok.com/@johorfoodie/video/7512681587209768200'),
  ('Machi Ice Cream', 'Dessert', 'Unique Burger Ice Cream in JB! 🍦 Machi Ice Cream 📍 Gravity Green (Next to Family Mart GL1, Jln Suria, Bandar Seri Alam, 81750 Masai, Johor Darul Ta''zim ⏰ 4PM - 11PM (Mon - Fri) | 3PM - 12AM (Sat - Sun)', 1.4781741, 103.8959861, 'https://www.tiktok.com/@johorfoodie/video/7511993960764591368'),
  ('Oc''Daka Malaysia', 'Taiwanese', 'Spotted this Hidden Gem Taiwanese Food spot in JB! 🇹🇼🤤 Oc’Daka Malaysia 📍 28, Jalan Austin Heights 8/9, Taman Mount Austin, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 9AM - 10PM', 1.5555381, 103.7770672, 'https://www.tiktok.com/@johorfoodie/video/7511599696318614792'),
  ('Hard Rock Cafe', 'Western', 'Hard Rock Cafe Puteri Harbour Lunch Set at only RM19.90+! 🤩 Enjoy their daily dish highlights, with different dish every day like: ✨Sizzling Salmon Bites with White Rice ✨Creamy Shrimp Lemon Garlic Pasta ✨Crispy Chicken with Mushroom Sauce & Pineapple Rice ✨Beef Bolognese Pasta ✨Rending Beef with Pineapple Rice ✨Fish & Chips Get a FREE Hot Fudge Brownie with your meal on every Saturdays and Sundays 🍰 Hard Rock Cafe Puteri Harbour 📍Lot 2-B2 Lot2-B2 Residensi & Hotel Marina Resort Persiaran Tanjung, Pengkalan Puteri Puteri Harbour, 79100 Iskandar Puteri, Johor Darul Ta''zim (Behind Frasers Place) ⏰ 12pm - 3pm', 1.4599636, 103.6294022, 'https://www.tiktok.com/@johorfoodie/video/7511208328878411026'),
  ('Kanbe Ramen', 'Ramen', 'KL’s Famous Ramen is Finally in JB! 🎉 Craving authentic ramen? 🍜 Kanbe Ramen brings their signature 7 pork bone soup bases to town — each one rich, bold, and full of umami goodness. 🤤 There’s a bowl for every kind of ramen lover! 📍 Kanbe Ramen AEON Mall, Tebrau City ⏰ 11am - 10pm', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7510071691586931986'),
  ('Nasi Ambang AB Rahmat', 'Malay', 'RM8 Nasi Ambang in Johor 📍Nasi Ambang AB Rahmat, Sri Tebrau Hawker Centre', 1.4866483, 103.7680418, 'https://www.tiktok.com/@johorfoodie/video/7509436884037258503'),
  ('Woodfire', 'Burger', 'Woodfire’s got new heat on the menu, and a challenge just for you! 🔥 Sink your teeth into their crispy smoked chicken burger 🍔 or go big with their Angus steak platter 🥩 📍@woodfireburger ✅ Muslim-owned', 1.5883699, 103.7612729, 'https://www.tiktok.com/@johorfoodie/video/7509099130522766610'),
  ('An Viet', 'Vietnamese', 'New Vietnamese Spot in JB that’s 🇻🇳✨ Check out An Viet, a cozy new restaurant in JB serving up all the classics — from Phở to Cơm, and everything in between! 🥢 What we love: 🍜 You can choose your portion size — 100g, 150g, or 200g of noodles or rice. ♻ Ordered too little? No worries — top-ups are FREE! 💚 That means less waste, more satisfaction. It’s all part of their mission to make every meal 📍 An Viet Lot G111, Aeon Tebrau City, Jalan Desa Tebrau, Taman Desa Tebrau, 81100 JB ⏰ 11am – 9.30pm (Daily) *Non-Halal', 1.5727188, 103.78302, 'https://www.tiktok.com/@johorfoodie/video/7508656563276582160'),
  ('Local House', 'Malaysian', 'Nasi Lemak Jumbo with Sotong, Udang, Chicken Wing & Satay 😍 After serving the people of Mount Austin for a good 5 years, they have decided to spread their wings and open a new branch in Eco Botanic. Local House has been an all-time favourite for breakfast, lunch and dinner 😋 with their Hainan Toasted Bread, Char Kuey Teow, Asam Laksa, Hainan Chicken Rice, Curry Laksa and many more! Local House 📍Eco Botanic 📍Mount Austin ⏰8am - 8pm (Opens Daily)', 1.552459, 103.7855398, 'https://www.tiktok.com/@johorfoodie/video/7507601963182345479'),
  ('Muiz Hot Chicken Malaysia', 'Fried Chicken', 'Buy Fried Chicken, Win a Motorcycle? 🛵😱 Good news for Batu Pahat folks 📣 @Muiz Hot Chicken Malaysia has just opened with an exciting lucky draw where you could win a motorcycle, Kids Meals, and much more!😍 *Kids Meals will be available starting next month 📍Muiz Hot Chicken1 & 1A, Jalan Universiti 6, 86400 Parit Raja, Batu Pahat, Johor ⏰10AM-12AM', 1.8585385, 103.0852742, 'https://www.tiktok.com/@johorfoodie/video/7507551880441040135'),
  ('Burger King', 'Burger', 'NEW Angus Beef Burgers at Burger King! 🔥 Get up close with the juiciest launch yet, The Angus Signature Burger and Angus Mushroom Burger! 👑Both are juicy, loaded, and made to satisfy Sink your teeth into flame-grilled Angus beef, paired with crispy chicken strips and drenched in bold black pepper sauce. Craving something extra? Go for the Angus Mushroom Burger, it’s stacked with sautéed mushrooms, melty cheese, and that same peppery kick. And don’t sleep on the Kaya Pandan Pie for dessert 🥧 📍Try it now at you nearest Burger King.', 1.3971444, 103.6306555, 'https://www.tiktok.com/@johorfoodie/video/7504502920885456129')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Sang Seafood', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r221-p0-sang-seafood.jpg'),
  ('1975 Toast & Coffee', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r222-p0-1975-toast-coffee.jpg'),
  ('MSK Trading', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r223-p0-msk-trading.jpg'),
  ('The Tiny Lake', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r224-p0-the-tiny-lake.jpg'),
  ('Gather Pizza', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r225-p0-gather-pizza.jpg'),
  ('Mofad Durian', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r226-p0-mofad-durian.jpg'),
  ('Epok Epok OKU', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r227-p0-epok-epok-oku.jpg'),
  ('BreakRoom', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r228-p0-breakroom.jpg'),
  ('House89 Steak Mansion', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r229-p0-house89-steak-mansion.jpg'),
  ('Layer Bakehouse', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r230-p0-layer-bakehouse.jpg'),
  ('Frenché Roast', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r231-p0-french-roast.jpg'),
  ('Kafe Saliha', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r232-p0-kafe-saliha.png'),
  ('Waffle Delight', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r233-p0-waffle-delight.jpg'),
  ('Soto Warisan Hj Patoni', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r234-p0-soto-warisan-hj-patoni.jpg'),
  ('Gobok Budak Johor 1', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r235-p0-gobok-budak-johor-1.jpg'),
  ('Jungle House', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r236-p0-jungle-house.jpg'),
  ('MKe Harmony Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r237-p0-mke-harmony-cafe.jpg'),
  ('Nasi Lemak Abang Sudin', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r238-p0-nasi-lemak-abang-sudin.jpg'),
  ('FirePitz', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r239-p0-firepitz.jpg'),
  ('Talam Durian', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r240-p0-talam-durian.jpg'),
  ('Sunday Morning Coffee Shop', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r241-p0-sunday-morning-coffee-shop.jpg'),
  ('Pink Matcha & Coffee Cart', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r242-p0-pink-matcha-coffee-cart.jpg'),
  ('Noodles Ice Cream', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r243-p0-noodles-ice-cream.jpg'),
  ('Lan Xi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r244-p0-lan-xi.jpg'),
  ('Panggungkopi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r245-p0-panggungkopi.jpg'),
  ('Bob Rojak', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r246-p0-bob-rojak.jpg'),
  ('Wildbird', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r247-p0-wildbird.jpg'),
  ('Bakeman', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r248-p0-bakeman.jpg'),
  ('Mochi Bomb', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r249-p0-mochi-bomb.jpg'),
  ('Restoran Jit Seng', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r250-p0-restoran-jit-seng.jpg'),
  ('Machi Ice Cream', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r251-p0-machi-ice-cream.png'),
  ('Oc''Daka Malaysia', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r252-p0-oc-daka-malaysia.jpg'),
  ('Hard Rock Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r253-p0-hard-rock-cafe.jpg'),
  ('Kanbe Ramen', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r254-p0-kanbe-ramen.jpg'),
  ('Nasi Ambang AB Rahmat', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r255-p0-nasi-ambang-ab-rahmat.jpg'),
  ('Woodfire', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r256-p0-woodfire.jpg'),
  ('An Viet', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r257-p0-an-viet.png'),
  ('Local House', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r258-p0-local-house.jpg'),
  ('Muiz Hot Chicken Malaysia', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r259-p0-muiz-hot-chicken-malaysia.jpg'),
  ('Burger King', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r260-p0-burger-king.png')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;

insert into public.restaurants (name, tag, details, latitude, longitude, video_url)
values
  ('Belly Good Cafe', 'Vietnamese', 'Malaysian Vietnamese Classic Food in JB! Belly Good Cafe 📍 82, Jalan Tanjong 2, Taman Desa Cemerlang, 81800 Ulu Tiram, Johor Darul Ta''zim ⏰ 8AM - 8:30PM', 1.5993646, 103.820877, 'https://www.tiktok.com/@johorfoodie/video/7504147553559104769'),
  ('Botok-Botok Ibunda', 'Malay', 'How Botok-Botok Johor is made! 🤩 Botok-Botok Ibunda 📍2, Jalan Orkid Utama, Taman Orkid, 81200 Johor Bahru, Johor ⏰8AM - 7:30PM', 1.5022381, 103.7104236, 'https://www.tiktok.com/@johorfoodie/video/7503533820096924946'),
  ('Along Burger', 'Burger', 'Soft Shell Crab Burger 🦀🍔 📍Along Burger, Jalan Bestari 22/2, Taman Bestari Indah', 1.598874, 103.7898903, 'https://www.tiktok.com/@johorfoodie/video/7499043502630849800'),
  ('Cat Soffle Cafe', 'Cafe', 'NEW Cat Cafe with Amazingly Soft Souffle! 😻🥞 This cafe serves one of the softest souffle in town!🤤 As well as up to 20 over cats for you to play with for FREE!🐈 Cat Soffle Cafe 📍 87-01 Jalan Bestari 1/5 Taman Nusa Bestari Iskandar Puteri, 79150 Johor Bahru, Johor Darul Ta''zim ⏰ 12PM - 10PM (Close on Tuesday)', 1.4971754, 103.6561376, 'https://www.tiktok.com/@johorfoodie/video/7498677280110087431'),
  ('Firedough', 'Pizza', 'RM79 street wagyu pizza 📍@firedough.jb , Jalan Perjiranan 2, Bandar Dato’ Onn', 1.5575524, 103.738067, 'https://www.tiktok.com/@johorfoodie/video/7498303452376747272'),
  ('Restoran Ikan Bakar Hantu Air Asam', 'Seafood', 'Ikan Bakar Air Asam 📍Restoran Ikan Bakar Hantu Air Asam', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7496447065954798855'),
  ('Muar Collector Space', 'Cafe', 'Unique Antique Cafe in Muar! Muar Collector Space 📍44, Jalan Abdullah, Pekan Muar, 84000 Muar, Johor Darul Ta''zim ⏰2PM - 11PM (Close on Mon - Tue)', 2.0439338, 102.5873825, 'https://www.tiktok.com/@johorfoodie/video/7496078849231408391'),
  ('Kanuo', 'Asian', 'Extra Large Glutinous Rice Roll in JB! 📍Kanuo @ Cultural Street, JB Tan Hiok Nee, 66, Jalan Tan Hiok Nee, Bandar Johor Bahru, 80000 Johor Bahru, Johor ⏰ 9am untill sold out. (Every saturday) 🚗 On weekdays, they sell out of their car at different spots around JB too! Follow them on IG to catch their next location! @kanuoo_', 1.4277678, 103.6294754, 'https://www.tiktok.com/@johorfoodie/video/7494892019874123016'),
  ('Mekraa Bukit Aliff', 'Malay', 'Asam Picit 🔥 📍Mekraa Bukit Aliff @ Taman Bukit Aliff, Johor Bahru', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7494243287889448210'),
  ('Modern Fishing Restaurant', 'Seafood', 'Stulang''s Famous Seafood Fried Rice Modern Fishing Restaurant 📍 Jalan Stulang Laut 1, Taman Stulang Laut, 80300 Johor Bahru, Johor Darul Ta''zim ⏰ 12:30PM - 12AM (Closed on Tuesday)', 1.4716106, 103.7670306, 'https://www.tiktok.com/@johorfoodie/video/7494116781355781384'),
  ('Dapo Khaleeda', 'Malay', 'Delicious Basmati Nasi Lemak after dark! 🔥 Dapo Khaleeda 📍 102, Jalan Dato Sulaiman, Taman Abad, 80250 Johor Bahru ⏰ 6:30PM - 10:30PM', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7493854699032956161'),
  ('1061 KONA', 'Cafe', 'This cafe in JB serves BuTian Desserts! 1061 KONA 📍106-01, Jln Pertama 1, Taman Tampoi Indah 2, 81200 Johor Bahru, Johor ⏰ 11am - 6pm (Close on Mondays)', 1.5048156, 103.7158165, 'https://www.tiktok.com/@johorfoodie/video/7493167920512584981'),
  ('Nasi Sumatera Kelate Kulai', 'Malay', 'Nasi Sumatera 🔥 📍Nasi Sumatera Kelate Kulai @ Kawasan Perindustrian Kulai, Johor', 1.6296979, 103.6532805, 'https://www.tiktok.com/@johorfoodie/video/7493115387844775186'),
  ('Moogle Desserts', 'Dessert', 'Spotted Banana Pudding Matcha Latte in Johor 😍 📍Moogle Desserts @ Bandar Dato’ Onn, Johor Bahru', 1.5606008, 103.7371091, 'https://www.tiktok.com/@johorfoodie/video/7492280970398207250'),
  ('Xiaoyao Ke Zha Zha Hotpot', 'Hotpot', 'Johor’s FIRST Zha Zha Hotpot is finally here! 🔥😍🍲 The best way to enjoy it? Toss in their signature Zha Zha beef and celery, let it soak up the flavour, then pair it with rice.🤤🍚 @xiaoyaokezhazhahotpot 逍遥客渣渣锅 📍 70 (Ground Floor), Jalan Sutera Tanjung 8/4, Taman Sutera Utama, 81300 Skudai, Johor Bahru ⏰ Mon-Thurs 4pm-12am｜Fri-Sun 12pm-12am', 1.5164614, 103.6685694, 'https://www.tiktok.com/@johorfoodie/video/7491987694982040850'),
  ('Bora Bora', 'Western', 'New Nature Theme Event Hall by the lake! ✨🌊 Tucked away in Sunway Emerald Lake, this hidden gem also serves up both Western and Malaysian cuisine. Their fish & chips might just be the BIGGEST in town! 🐟🍟 What’s more? 🤩 They’ve got a spacious event hall that’s perfect for: ✨Weddings & Corporate events ✨Penrose Stairs, Great for ROM ceremonies up to 120 pax ✨Petite Island, Ideal for proposals & intimate gatherings up to 40 pax ✨Alfresco Balcony, Cozy spot for café dining & private events up to 80 pax With their event hall that can cater up to 350 pax!😱 Starting from RM15,888‼️ They also provide Weekend Buffet Breakfast: Sat & Sun, 9AM–11AM 🤤 Bora Bora, Sunway Emerald Lake 📍 9JRQ+C6 Emerald, Lake View, 81550 Iskandar Puteri, Johor ⏰ 9AM -9PM', 1.4271624, 103.5849243, 'https://www.tiktok.com/@johorfoodie/video/7491912138739567880'),
  ('Restoran Baba', 'Nyonya', '50+ Years Baba Nyonya Chicken Rice in Muar! Restoran Baba 📍 131, Jalan Khalidi, Taman Sri Tanjung, 84000 Muar, Johor Darul Ta''zim ⏰ 11AM - 6:30PM (Closed on Sunday)', 2.0439338, 102.5873825, 'https://www.tiktok.com/@johorfoodie/video/7491905456143633671'),
  ('Nasi Goreng Kampung Basmathi', 'Malay', 'Dried Chilli Fried Rice 🔥 📍Nasi Goreng Kampung Basmathi @ Tapak Penjaja Jalan Pelanduk, Taman Scientex, Pasir Gudang', 1.5072077, 103.9147387, 'https://www.tiktok.com/@johorfoodie/video/7490923516276133138'),
  ('Kedai Kopi See Hui', 'Kopitiam', '53-year-old kopitiam still toasting bread over charcoal and making their own kaya! 🥖🔥 Kedai Kopi See Hui 📍 129-4, Jalan Temenggong Ahmad, Jalan Parit Perupok, 84000 Muar, Johor ⏰ 7:30 AM - 5:30 PM (Closed on Sundays)', 2.0439338, 102.5873825, 'https://www.tiktok.com/@johorfoodie/video/7489024280760438034'),
  ('Ayam Penyet Sarang Lebah', 'Malay', 'Ayam Penyet Sarang Lebah 📍 Bazaar Perling Mall', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7485685785631411474'),
  ('Abang Manis', 'Asian', 'Pau Premium @ABANGMANIS 📍B5 Johor Street Market', 1.4957667, 103.7035624, 'https://www.tiktok.com/@johorfoodie/video/7485670730181463303'),
  ('Artscape Cafe by Sorella.C', 'Cafe', 'Hidden cafe above a nursery in JB! 🌿☕ Artscape Cafe by Sorella.C has newly opened in Taman Molek, offering unique pastries and desserts that you won’t want to miss! 😍 Artscape Cafe by Sorella.C 📍 3, Jalan Ponderosa 2/2, 81100 Johor Bahru, Johor ⏰ 10am - 8pm', 1.5115339, 103.7874469, 'https://www.tiktok.com/@johorfoodie/video/7485331155407883538'),
  ('Dapo Mak Kiah', 'Malay', 'RM154.80 Nasi Ayam 📍Dapo Mak Kiah', 0.0, 0.0, 'https://www.tiktok.com/@johorfoodie/video/7484904243095276818'),
  ('Top Ten Ikan Bakar', 'Seafood', 'Ikan Bakar Bazaar Perling Top Ten Ikan Bakar 📍 Perling Mall, Jalan Persisiran 1, Taman Perling, 81200 Johor Bahru, Johor Darul Ta''zim', 1.5019247, 103.6882629, 'https://www.tiktok.com/@johorfoodie/video/7483746086583094536'),
  ('Q Bistro', 'Bistro', 'Lamb Shank Nasi Briyani at Q Bistro!🤩 Q Bistro 📍 28, Jalan Ekoperniagaan 1, Taman Kota Masai, 81700 Pasir Gudang, Johor Darul Ta''zim, Malaysia ⏰ 24 hours', 1.4835876, 103.93767, 'https://www.tiktok.com/@johorfoodie/video/7483339354195217671'),
  ('Ayam Gepuk Station', 'Malay', 'Special Ayam Gepuk in Muar!🤤 Ayam Gepuk Station, Muar 📍 15, Jalan Sulaiman, Pusat Perniagaan Sulaiman, 84000 Muar, Johor Darul Ta''zim, Malaysia ⏰ 11:30am - 9pm ( Closed on Sun) Available on @foodpanda_my', 2.0439338, 102.5873825, 'https://www.tiktok.com/@johorfoodie/video/7483048796721564946'),
  ('Restoran Kok Ki', 'Curry', '83 year old Famous Curry Noodle in JB! Restoran Kok Ki 📍 Jalan Tun Teja, Taman Ungku Tun Aminah, 81300 Skudai, Johor Darul Ta''zim, Malaysia ⏰ 4PM - 11:30PM (Closed on Sun)', 1.5290259, 103.6644193, 'https://www.tiktok.com/@johorfoodie/video/7483005979286654215'),
  ('The Blue Door Cafe', 'Cafe', 'Trying this Viral Kunafa Pistachio Crossiant The Blue Door Cafe 📍 36A, Jalan Austin Height 7/8, Taman Mount Austin, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 11.30 am - 10pm (Monday - Wednesday) 11am - 12am (Thursday - Sunday)', 1.5578522, 103.7756939, 'https://www.tiktok.com/@johorfoodie/video/7482627522534968583'),
  ('Frenche Roast', 'Cafe', 'New Ramadan Menu at Frenche Roast!🌙 Enjoy a unique Ramadan menu serving a combination of western and malay flavours🤤 Satisfied your sweet tooth with their wide range of desserts and pastries as well! Happy Berpuka Puasa Foodies! Frenche Roast Cafe 📍 Lot B3 No.7 Molek Pine 3 Apartment, Jalan Molek 1/27, Taman Molek, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 8:30AM - 9PM (Daily)', 1.5268363, 103.7860651, 'https://www.tiktok.com/@johorfoodie/video/7481122537880046855'),
  ('Nimmies Pastry Cafe', 'Cafe', 'NEW Ramadan Menu Set at @nimmies.pastry.cafe!🌙 For just RM69,90++ You''ll get to pick from 1 starters, 1 main course, and 1 drinks with unlimited refills!😍 And if you add on RM5, you can pick from any 1 of their pastries from the counter! 🥐 Nimmies Pastry Cafe 📍 171, Jln Beringin, Taman Melodies, 80250 Johor Bahru, Johor Darul Ta''zim ⏰ 8am - 11pm', 1.4883784, 103.7614777, 'https://www.tiktok.com/@johorfoodie/video/7480026561006030088'),
  ('TW Foodcourt', 'Malay', 'RM1.60 Pork Satay in JB! TW Foodcourt 📍 LOT 744, JALAN SKUDAI BT 6 1, 2, Kampung Seri Jaya, 81200 Johor Bahru, Johor Darul Ta''zim ⏰ 6am - 12am (Opens daily)', 1.5048156, 103.7158165, 'https://www.tiktok.com/@johorfoodie/video/7478921453208128775'),
  ('Muiz Hot Chicken', 'Fried Chicken', 'The perfect Buka Puasa set this Ramadan at @muizhotchicken 🔥 Set Mak Ngah Steady for 4-5 pax under RM57 comes with: 🍗 5x Ayam goreng 🍔 1x Zappy Hot Burger 🥤 4x Hausboom 🐥 6x Nugget 🍚 1x Nasi lemak kosong 🆓 Free Raya Packet 📍 Muiz Hot Chicken 82-48, Jalan Bakri 2, Taman Tun Dr Ismail, 84000 Muar, Johor Darul Ta''zim ⏰ 24 Jam ☎️ 06 959 4900', 2.0439338, 102.5873825, 'https://www.tiktok.com/@johorfoodie/video/7478535708714568967'),
  ('Restoran Kwang Hoi', 'Chinese', 'Famous Braised Duck Rice in JB! 🦆 Restoran Kwang Hoi 📍 33, Jalan Ros Merah 2/2, Taman Johor Jaya, 81100 Johor Bahru, Johor Darul Ta''zim ⏰ 8:30am - 3pm (Closed on Wed)', 1.5328993, 103.7999361, 'https://www.tiktok.com/@johorfoodie/video/7478176868986801416')
on conflict (name) do nothing;

insert into public.restaurant_images (restaurant_id, url, position)
select r.id, v.url, 0
from (values
  ('Belly Good Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r261-p0-belly-good-cafe.jpg'),
  ('Botok-Botok Ibunda', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r262-p0-botok-botok-ibunda.jpg'),
  ('Along Burger', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r263-p0-along-burger.jpg'),
  ('Cat Soffle Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r264-p0-cat-soffle-cafe.jpg'),
  ('Firedough', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r265-p0-firedough.jpg'),
  ('Restoran Ikan Bakar Hantu Air Asam', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r266-p0-restoran-ikan-bakar-hantu-air-asam.jpg'),
  ('Muar Collector Space', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r267-p0-muar-collector-space.jpg'),
  ('Kanuo', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r268-p0-kanuo.jpg'),
  ('Mekraa Bukit Aliff', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r269-p0-mekraa-bukit-aliff.jpg'),
  ('Modern Fishing Restaurant', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r270-p0-modern-fishing-restaurant.png'),
  ('Dapo Khaleeda', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r271-p0-dapo-khaleeda.png'),
  ('1061 KONA', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r272-p0-1061-kona.png'),
  ('Nasi Sumatera Kelate Kulai', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r273-p0-nasi-sumatera-kelate-kulai.jpg'),
  ('Moogle Desserts', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r274-p0-moogle-desserts.jpg'),
  ('Xiaoyao Ke Zha Zha Hotpot', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r275-p0-xiaoyao-ke-zha-zha-hotpot.png'),
  ('Bora Bora', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r276-p0-bora-bora.jpg'),
  ('Restoran Baba', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r277-p0-restoran-baba.jpg'),
  ('Nasi Goreng Kampung Basmathi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r278-p0-nasi-goreng-kampung-basmathi.jpg'),
  ('Kedai Kopi See Hui', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r279-p0-kedai-kopi-see-hui.jpg'),
  ('Ayam Penyet Sarang Lebah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r280-p0-ayam-penyet-sarang-lebah.jpg'),
  ('Abang Manis', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r281-p0-abang-manis.jpg'),
  ('Artscape Cafe by Sorella.C', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r282-p0-artscape-cafe-by-sorella-c.jpg'),
  ('Dapo Mak Kiah', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r283-p0-dapo-mak-kiah.jpg'),
  ('Top Ten Ikan Bakar', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r284-p0-top-ten-ikan-bakar.png'),
  ('Q Bistro', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r285-p0-q-bistro.png'),
  ('Ayam Gepuk Station', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r286-p0-ayam-gepuk-station.jpg'),
  ('Restoran Kok Ki', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r287-p0-restoran-kok-ki.jpg'),
  ('The Blue Door Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r288-p0-the-blue-door-cafe.jpg'),
  ('Frenche Roast', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r289-p0-frenche-roast.jpg'),
  ('Nimmies Pastry Cafe', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r290-p0-nimmies-pastry-cafe.jpg'),
  ('TW Foodcourt', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r291-p0-tw-foodcourt.jpg'),
  ('Muiz Hot Chicken', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r292-p0-muiz-hot-chicken.png'),
  ('Restoran Kwang Hoi', 'https://vpcldlhqpvunnuexecgn.supabase.co/storage/v1/object/public/restaurant-images/r293-p0-restoran-kwang-hoi.jpg')
) as v(restaurant_name, url)
join public.restaurants r on r.name = v.restaurant_name
on conflict (restaurant_id, position) do nothing;


-- The image URLs above point at permanent Supabase Storage objects (hosted on
-- the production project; a fresh environment serves images from prod's
-- public bucket until it runs its own scrape). Mark them cached so the
-- refresh cron does not re-download all of them into the local bucket.
update public.restaurant_images
set metadata_status = 'cached',
    source_url = coalesce(source_url, url)
where url like '%/storage/v1/object/public/restaurant-images/%';
