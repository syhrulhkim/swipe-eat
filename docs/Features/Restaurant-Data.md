Status: ACTIVE
Owner: Swipe Eat team
Last updated: 2026-09-05
Cross-references: [General/PLAN.md](../General/PLAN.md), [General/RUNBOOK.md](../General/RUNBOOK.md), [Backend-Schema.md](Backend-Schema.md), [TikTok-Video.md](TikTok-Video.md), [Explore-Search.md](Explore-Search.md)

# Restaurant Data Pipeline

Where the 1,607 restaurants come from. Malaysian food creators post TikToks in a
house caption format; this pipeline turns those captions into catalogue rows.

Files: `scripts/scrape_tiktok.py`, `extract_restaurants.py`,
`restaurants_to_sql.py`, `geocode_free.py`, `geocode_places.py`,
`test_scrape_tiktok.py`.

## 1. The five stages

```
TikTok creator
     │  scrape_tiktok.py          (yt-dlp + curl_cffi)
     ▼
videos.json  ── raw yt-dlp entries
     │  extract_restaurants.py    (caption → candidate + confidence)
     ▼
candidates.json
     │  ◀── HUMAN / MODEL REVIEW PASS  → keep.jsonl
     │  restaurants_to_sql.py
     ▼
rows.sql  ── INSERTs, coordinates written as 0/0
     │  geocode_free.py  (Overture, then Nominatim)
     ▼
UPDATE batches  ── lat/lon filled in, ~70% of rows
```

**Only the last two stages touch Supabase, and only ever with SQL the operator
runs.** `scrape_tiktok.py` has an `--upsert` mode, but by default every script
in the chain produces a *file*. That is the safety property of the design: a
bad extractor run costs a file, not a catalogue.

### Why scraping and parsing are separate

TikTok listing is slow and rate-limited. A caption is fetched **once** and
re-parsed as often as the extractor improves. `--raw` writes yt-dlp's entries
untouched, which is what the extractor reads.

`yt-dlp` needs `curl_cffi` for `--impersonate`; without it TikTok answers every
request with an anti-bot page.

## 2. What the caption format gives, and what it doesn't

Creators write to a house format:

```
Matcha Mochi Brioche in JB 😍 ... Little Bun Cafe
📍 G-08, Eco Nest Apartment, Jalan Eko Botanic 3/5, 79100, Johor
⏰ 9:30am - 9:30pm (Daily)
```

**Deterministic**, so it lives in the extractor: the pin emoji anchors the
address, the clock ends it, and a Malaysian postcode inside it names the state.

**Not deterministic**: the restaurant's *name*. Creators put it before the pin,
after the pin, or nowhere at all. So every candidate carries a `confidence` and
the caption it came from, and the uncertain ones are meant to be read by a
human — or a model — before anything reaches the database.

That review pass is where advertisements, listicles and mall events leave the
pipeline: **a candidate with no line in `keep.jsonl` is dropped.**

### 2a. Facts parsed from the caption — added 2026-09-05 (D91)

The redesign's card, detail screen and map need an opening span, a price, a
halal flag and a neighbourhood. All four were already in the captions; the
migration `restaurant_facts_hours_price_halal_dishes` parsed them once, in SQL,
into columns on `restaurants`:

| Column | From | Rule | Rows |
|---|---|---|---|
| `hours_text` | the text after ⏰ | kept verbatim, so a bad parse can be redone | 194 |
| `opens_at`, `closes_at` | `9.30am - 8pm`, `11am – 10.30pm`, `5:30PM - 2AM` | `.` or `:` minutes, missing minutes, a missing opening am/pm inferred (5–11 → am), `24 hours`/`24 Jam` → 00:00–00:00 | 181 (30 past midnight, 3 all day) |
| `closed_dow` | `(Closed on Monday)`, `Tutup Isnin` | ISO weekdays after *closed / tutup / off day / rest day*; English and Malay names | 37 |
| `price_from` | the lowest `RM n` in the caption | a **dish** price, not a per-person band — the UI says "From RM 19" | 186 |
| `is_halal` | `halal` / `non-halal` | true, false, or **null** when the caption does not say; not a certification check | 27 / 3 |
| `neighbourhood` | the town after the 5-digit postcode | up to three capitalised words, state names and street prefixes stripped | 159 |

"until sold out", "6pm (Thurs to Sat)" and the like keep their `hours_text` and
get no span — the client shows nothing rather than a guess. `is_open_at(opens,
closes, closed_dow, at)` evaluates in Asia/Kuala_Lumpur; a closing time earlier
than the opening time runs past midnight and its post-midnight part belongs to
the previous day's opening (D92). The `dishes` table ("What people bite") exists
and is empty until menus are curated; every one of these fields is nullable and
the UI hides what it does not know.

### The review file

JSONL, one object per kept candidate, keyed by index into the candidates file:

```json
{"i": 1, "n": "Kerala B&B Restaurant", "t": "Indian"}
{"i": 2, "n": "SOLENE", "t": "Fine Dining", "g": "Johor"}
```

`n` name, `t` category badge, `g` optional state, `gn` optional country. `g`
and `gn` override what the extractor read from the caption, because **Malaysian
street names carry state names** — "Terengganu Road" is in George Town, Penang
— and the caption's own guess is wrong often enough to be worth correcting by
hand. This is exactly the bug that put 195 Penang restaurants in Johor.

## 3. Geocoding

Rows are inserted with `latitude = 0, longitude = 0`, because a caption gives a
human-readable address, not a fix. The app already treats `0/0` as "no map fix"
and hides the directions button for it, so an ungeocoded row is safe — just
limited.

`geocode_free.py` fills them in from two free sources, cheapest first (D10):

| Source | How | Licence |
|---|---|---|
| **Overture Maps places** | Open POI dataset (Meta + Microsoft + OSM). Pulled once into a local ~85MB parquet, then matched **offline** — no key, no rate limit, no per-row cost | ODbL / CDLA — coordinates may be stored in our own DB |
| **OSM Nominatim** | Whatever Overture missed. Public instance, so **one request per second** | ODbL |

Two guards that matter more than the sources:

- **Results coarser than a suburb are thrown away rather than written.** A
  state centroid is worse than no fix at all: the app hides directions on
  `0/0` but will happily route someone to a wrong one.
- **Matching is confined to the bounding box of the row's `negeri`.** This is
  what stops a chain like Nasi Kandar Pelita resolving to an outlet in the
  wrong state.

Rows are read from PostgREST with the publishable key, filtered to those still
at `0/0`, so the script is **safe to re-run after every batch of inserts**.
Output is batched `UPDATE ... FROM (VALUES ...)` joined on `video_url`, plus a
TSV report of what matched and how.

### The paid alternative

`geocode_places.py` uses Google Places Text Search (New). It is the only path
that also returns **ratings** — asking for `rating` moves the call into a more
expensive SKU, which is precisely the trade-off D10 declined.

## 4. Current coverage

| Metric | Count | Of 1,607 |
|---|---|---|
| Active | 1,605 | 99.9% |
| With a TikTok video | 1,606 | 99.9% |
| With coordinates | 1,133 | **70.5%** |
| With a rating | **2** | **0.1%** |
| With any image | 287 | 17.9% |
| With any review | 6 | 0.4% |
| Mapped to a cuisine | 1,607 | 100% |
| With an opening span | 181 | 11.3% |
| With a price | 186 | 11.6% |
| With a halal statement | 30 | 1.9% |
| With a neighbourhood | 159 | 9.9% |
| With a dish | 0 | 0% |

Geography follows the creators scraped: concentrated in **Johor and Penang**.

## 5. Cuisine mapping

`restaurants.tag` is free text from the review pass ("Indian", "Fine Dining").
The `sync_restaurant_cuisines` trigger maps it through `cuisine_aliases` into
`restaurant_cuisines`, recording `source = 'tag'` so a human override is
distinguishable from an inferred one.

All 1,607 rows are mapped across 23 cuisines, which is why Explore's grid works
even though ratings and images do not.

## 6. Known issues

- **Ratings are the biggest gap in the product.** 2 rows. It kills the ranker's
  quality signal, the rating chip, the Liked tab's rating sort, and the
  `filter_min_rating` discovery filter. Fixing it needs a paid Places pass or a
  different source — there is no free source with ratings.
- **474 rows have no coordinates.** They are invisible to Explore's radius rule
  and unrankable by distance. The deck's offline ranker grants them neutral
  half-credit; the server-side radius filter does not.
- **Precision is uneven on the free path.** Around 474 of the Nominatim
  batch came back coarse, and ~225 rows had state mismatches — 195 of them
  Penang restaurants tagged Johor, since corrected via `negeri` and the
  bounding-box guard.
- **Systematic coordinate duplication.** Several batches resolved multiple
  distinct restaurants to identical coordinates, i.e. matched to a shared
  nearby feature rather than each address.
- **Images and reviews were never a pipeline stage.** 287 and 6 respectively,
  mostly from the original hand-written seed.

## 7. Out of scope

- **Automated writes from the extractor.** The review pass is deliberate; a
  caption parser confident enough to write unattended does not exist.
- **A second video source.** The catalogue is defined by TikTok posts.
- **Scraping opening hours and price.** The clock line is parsed only to
  *terminate* the address; `restaurants` has no column for either, so the
  filters they would enable are not buildable.
- **Re-scraping for ratings.** TikTok captions do not carry them.

## 8. Decision log

| ID | Decision | Status |
|---|---|---|
| D10 | Free geocoding (Overture + Nominatim) over paid Google Places, accepting lower precision and no ratings, to keep API spend at zero. | locked 2026-08-31 |
| D44 | Scraping and parsing are separate stages — a caption is fetched once and re-parsed as the extractor improves. | locked 2026-08-29 |
| D45 | Every script writes a file by default; nothing in the chain writes to Supabase unattended. | locked 2026-08-29 |
| D46 | Uncertain candidates carry a confidence and their caption, and require a human/model review pass. No line in `keep.jsonl` means dropped. | locked 2026-08-29 |
| D47 | Geocode results coarser than a suburb are discarded — a wrong fix is worse than none, because `0/0` hides the directions button and a bad fix routes people. | locked 2026-08-31 |
| D48 | Geocode matching is confined to the row's `negeri` bounding box, so chains cannot resolve across states. | locked 2026-08-31 |
| D49 | `negeri` / `negara` are overridable by hand in the review file, because Malaysian street names contain state names. | locked 2026-08-31 |
| D91 | Hours, price, halal and neighbourhood are parsed once from the caption into nullable columns; `hours_text` is kept verbatim; `price_from` is a dish price, never a band; unknown is null and the UI hides it. | locked 2026-09-05 |
