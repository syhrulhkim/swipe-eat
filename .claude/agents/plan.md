# Swipe Eat — TikTok Restaurant Review Integration Plan

## 1. Goal

Implement a TikTok review aggregation feature for Swipe Eat where:

- Swipe Eat stores restaurant information in its own database.
- Admins or content curators can add public TikTok review URLs.
- Each TikTok review can be linked to one restaurant.
- Swipe Eat does **not** download or re-host TikTok video files.
- TikTok video metadata is fetched once during ingestion and cached in Swipe Eat.
- App users browse restaurant review content from Swipe Eat's API.
- TikTok embeds are lazy-loaded only when needed.
- Normal feed browsing should not repeatedly call TikTok APIs.
- The architecture should minimize exposure to TikTok API/oEmbed rate limits.
- Support for creator-authorized TikTok Display API integration can be added later as Phase 2.

---

## 2. Product Concept

Swipe Eat should treat TikTok as a content source, while the actual restaurant discovery data belongs to Swipe Eat.

Relationship:

```text
Restaurant
    |
    +-- Review Video A (@creator_a)
    +-- Review Video B (@creator_b)
    +-- Review Video C (@creator_c)
```

Example:

```text
Woodfire Burger
Johor Bahru

Reviews:
- @jbfoodie TikTok review
- @makanmana TikTok review
- @foodhunter TikTok review
```

Swipe Eat owns and manages:

- Restaurant name
- Restaurant address
- Latitude
- Longitude
- Cuisine/category
- Price range
- Opening hours
- Tags
- Search data
- Restaurant-review relationships

TikTok remains responsible for:

- Video hosting
- Video playback
- Creator account
- TikTok embed availability

---

## 3. Important Technical Rules

Claude must follow these rules when implementing the feature.

### Do

- Store the original public TikTok video URL.
- Extract and store the TikTok video ID where possible.
- Fetch TikTok oEmbed metadata during ingestion.
- Cache TikTok metadata in the database.
- Serve cached metadata from Swipe Eat's own backend.
- Lazy-load TikTok embeds in the mobile app.
- Gracefully handle deleted/private/unavailable TikTok videos.
- Add retry/backoff logic for TikTok metadata requests.
- Keep TikTok requests server-side wherever possible.
- Keep the implementation provider-specific enough for TikTok but structured so other video platforms can be added later.

### Do Not

- Public profile URL discovery may be used through the dedicated Python discovery service described in this plan.
- Do not depend on TikTok Research API.
- Do not download TikTok MP4 files.
- Do not re-host TikTok videos.
- Do not call TikTok oEmbed/API every time a user opens the feed.
- Do not expose TikTok access tokens in the mobile app.
- Do not make feed availability depend directly on a live TikTok metadata request.

---

# 4. Recommended Architecture

```text
                  CONTENT INGESTION

Admin
  |
  | Paste TikTok URL
  v
Swipe Eat Backend
  |
  | Validate URL
  | Extract TikTok video ID
  v
TikTok oEmbed
  |
  | title
  | author
  | thumbnail
  | embed data
  v
Swipe Eat Database
  |
  | Store metadata + restaurant relationship
  v
Review Published


                  USER FEED

Mobile App
  |
  | GET /api/feed
  v
Swipe Eat Backend
  |
  | Return cached data
  v
Mobile App
  |
  | thumbnail/card
  | restaurant details
  |
  | user swipes onto active review
  v
Lazy-load TikTok Embed
  |
  v
TikTok Player
```

---

# 5. Data Model

Use migrations and proper foreign keys.

## restaurants

Suggested fields:

```text
id
uuid
name
slug
description
address
city
state
postcode
country
latitude
longitude
google_place_id nullable
price_range nullable
phone nullable
website nullable
status
created_at
updated_at
```

Existing restaurant fields should be reused if this table already exists.

---

## creators

Create a generic creator table.

```text
id
uuid
platform
platform_user_id nullable
username
display_name nullable
profile_url nullable
avatar_url nullable
is_connected boolean default false
metadata json nullable
created_at
updated_at
```

Example:

```text
platform = tiktok
username = jbfoodie
```

Add a unique index where appropriate:

```text
platform + username
```

---

## restaurant_review_videos

Create a dedicated review-video table.

Suggested fields:

```text
id
uuid

restaurant_id
creator_id nullable

platform
external_video_id nullable
external_url

title nullable
caption nullable
thumbnail_url nullable

embed_url nullable
embed_html nullable

published_at nullable
duration_seconds nullable

status
metadata_status

last_metadata_sync_at nullable
metadata_error nullable

sort_order nullable
is_featured boolean default false
is_active boolean default true

raw_metadata json nullable

created_at
updated_at
```

Recommended statuses:

```text
status:
- draft
- published
- unavailable
- archived

metadata_status:
- pending
- fetched
- failed
- stale
```

Add indexes:

```text
restaurant_id
creator_id
platform
external_video_id
status
is_active
published_at
```

Prevent duplicate TikTok videos:

```text
unique(platform, external_video_id)
```

If a video ID cannot be extracted, use a normalized URL uniqueness strategy.

---

# 6. TikTok URL Handling

Support common TikTok URLs such as:

```text
https://www.tiktok.com/@username/video/1234567890123456789
https://vm.tiktok.com/...
https://vt.tiktok.com/...
```

Create a service:

```text
TikTokUrlService
```

Responsibilities:

1. Validate URL host.
2. Resolve short TikTok links if required.
3. Normalize the URL.
4. Extract:
   - username
   - video ID
5. Reject unsupported URLs.
6. Return a normalized data object.

Example output:

```json
{
  "platform": "tiktok",
  "username": "jbfoodie",
  "video_id": "1234567890123456789",
  "canonical_url": "https://www.tiktok.com/@jbfoodie/video/1234567890123456789"
}
```

Do not blindly follow arbitrary redirects.

Restrict redirects to trusted TikTok domains.

---



# 6A. Public TikTok Profile Video URL Discovery (No Login)

Swipe Eat also needs an optional discovery layer that can collect public TikTok video URLs from one or many public creator accounts without requiring the creator to log in to Swipe Eat.

This component is for discovering public video URLs only.

It must NOT:

- log into TikTok on behalf of a user
- bypass CAPTCHA
- bypass authentication
- use stolen cookies/session tokens
- attempt anti-bot evasion
- download/re-host the TikTok MP4 files

The discovered URLs are then passed into the normal ingestion pipeline described in this plan.

Target workflow:

```text
Admin enters:
@creator_a
@creator_b
@creator_c

        |
        v

Python TikTok Discovery Worker
        |
        | collect public video URLs
        v

Discovered URLs
        |
        +-- https://www.tiktok.com/@creator_a/video/...
        +-- https://www.tiktok.com/@creator_a/video/...
        +-- https://www.tiktok.com/@creator_b/video/...
        |
        v

Swipe Eat Ingestion Queue
        |
        v

TikTok oEmbed metadata
        |
        v

Restaurant matching / admin curation
```

The scraper/discovery component should be treated as a best-effort integration because public TikTok web markup and anti-automation behavior may change.

---

# 6B. Python Discovery Service

Create a small standalone Python service or worker.

Recommended directory:

```text
services/
└── tiktok_discovery/
    ├── app/
    │   ├── main.py
    │   ├── discovery.py
    │   ├── parser.py
    │   ├── models.py
    │   └── config.py
    ├── tests/
    ├── requirements.txt
    └── README.md
```

Preferred implementation order:

1. Plain HTTP/public page parsing if sufficient.
2. Playwright browser automation if JavaScript rendering is required.
3. Do not use login cookies.
4. Do not implement CAPTCHA bypass.
5. Stop and mark the job blocked if TikTok requires interactive verification.

Possible Python dependencies:

```text
httpx
beautifulsoup4
pydantic
tenacity
playwright
```

Do not add unofficial libraries that require private TikTok APIs unless explicitly approved.

---

# 6C. Discovery Input

Support one username:

```json
{
  "username": "jbfoodie"
}
```

and many usernames:

```json
{
  "usernames": [
    "jbfoodie",
    "makanmana",
    "foodhunter"
  ]
}
```

Normalize usernames by:

- trimming whitespace
- removing leading `@`
- converting profile URLs to usernames
- rejecting invalid characters
- deduplicating input

Examples accepted:

```text
@jbfoodie
jbfoodie
https://www.tiktok.com/@jbfoodie
```

Normalized:

```text
jbfoodie
```

---

# 6D. Discovery Output

The Python service should return normalized video URL records.

Example:

```json
{
  "username": "jbfoodie",
  "videos": [
    {
      "video_id": "1234567890123456789",
      "video_url": "https://www.tiktok.com/@jbfoodie/video/1234567890123456789"
    },
    {
      "video_id": "2234567890123456789",
      "video_url": "https://www.tiktok.com/@jbfoodie/video/2234567890123456789"
    }
  ],
  "has_more": false,
  "status": "completed"
}
```

If the scraper cannot continue:

```json
{
  "username": "jbfoodie",
  "videos": [],
  "status": "blocked",
  "reason": "interactive_verification_required"
}
```

Do not attempt to bypass the verification.

---

# 6E. Discovery Strategy

Claude should implement discovery as a strategy interface.

Example:

```text
TikTokDiscoveryProvider
```

Methods:

```text
discoverProfileVideos(username)
```

Possible implementations:

```text
TikTokPublicWebDiscoveryProvider
TikTokOfficialApiDiscoveryProvider
```

This keeps the rest of Swipe Eat independent from the discovery mechanism.

The application should be able to disable scraping completely via configuration.

Example:

```env
TIKTOK_DISCOVERY_ENABLED=true
TIKTOK_DISCOVERY_PROVIDER=public_web
```

---

# 6F. Public Web Discovery

For the public-web provider:

1. Open:

```text
https://www.tiktok.com/@{username}
```

2. Collect only publicly visible video URLs/IDs.
3. Support scrolling/pagination where possible.
4. Stop when:
   - no more video items appear
   - configured maximum is reached
   - profile is unavailable/private
   - interactive verification appears
   - network/request budget is exceeded

Configuration:

```env
TIKTOK_DISCOVERY_MAX_VIDEOS_PER_PROFILE=500
TIKTOK_DISCOVERY_PAGE_TIMEOUT_SECONDS=30
TIKTOK_DISCOVERY_MAX_RUNTIME_SECONDS=120
```

These are application safety limits, not TikTok platform limits.

---

# 6G. Browser Automation Rules

If Playwright is required:

- run headless by default
- use a normal supported Chromium runtime
- use reasonable timeouts
- wait for public video links to appear
- scroll gradually to load additional public items
- deduplicate video IDs
- stop after repeated scrolls produce no new videos

Do NOT implement:

```text
CAPTCHA solving
browser fingerprint spoofing
rotating residential proxies for evasion
stolen session cookies
login automation
```

If TikTok blocks the public request:

```text
status = blocked
```

and let the admin retry later or use another approved discovery provider.

---

# 6H. Discovery Database Tables

Add a discovery job table if the project does not already have a generic job/import table.

Suggested:

```text
tiktok_discovery_jobs
```

Fields:

```text
id
uuid

requested_by nullable

username
status

videos_found integer default 0
videos_new integer default 0
videos_existing integer default 0

started_at nullable
completed_at nullable

error_code nullable
error_message nullable

metadata json nullable

created_at
updated_at
```

Statuses:

```text
queued
running
completed
partial
blocked
failed
```

Optional table:

```text
tiktok_discovered_videos
```

Fields:

```text
id
discovery_job_id
username
video_id
video_url
ingestion_status
restaurant_review_video_id nullable
created_at
updated_at
```

If this duplicates the existing review-video table unnecessarily, use an import staging table instead.

---

# 6I. Discovery API

Laravel/backend endpoint:

```http
POST /api/admin/tiktok/discover
```

Request:

```json
{
  "usernames": [
    "jbfoodie",
    "makanmana"
  ]
}
```

Response:

```json
{
  "job_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

The Laravel API should queue discovery work rather than perform a long scrape inside the HTTP request.

---

# 6J. Laravel to Python Communication

Preferred options:

### Option A — HTTP microservice

Laravel:

```text
POST http://tiktok-discovery:8000/discover
```

Python service:

```text
FastAPI
```

Advantages:

```text
clear separation
easy scaling
Python/Playwright isolated from Laravel
```

### Option B — Queue worker

Laravel inserts discovery jobs.

Python worker consumes jobs from:

```text
Redis
```

and writes results back through:

```text
internal API
```

Preferred for production if discovery jobs may run for a long time.

Do not execute arbitrary shell commands built from usernames.

---

# 6K. Import Discovered Videos

Each discovered URL should go through the same existing ingestion path.

```text
Discovery Result
      |
      v
Normalize TikTok URL
      |
      v
Check duplicate video ID
      |
      +-- exists -> mark existing
      |
      +-- new
             |
             v
      create draft review record
             |
             v
      FetchTikTokMetadataJob
             |
             v
      Admin restaurant matching
```

Do not create separate metadata logic for scraped URLs.

Reuse:

```text
TikTokUrlService
TikTokMetadataService
FetchTikTokMetadataJob
```

---

# 6L. Restaurant Matching After Discovery

A discovered creator may have:

```text
food reviews
personal videos
advertisements
travel videos
non-restaurant content
```

Therefore discovery must NOT automatically treat every TikTok as a restaurant review.

Default:

```text
discovered
    |
    v
metadata fetched
    |
    v
pending restaurant match
```

Admin interface:

```text
Creator: @jbfoodie

Discovered Videos: 67

[thumbnail] Best nasi lemak in JB
Restaurant: [ Search restaurant... ]
[ Approve ]

[thumbnail] My morning routine
[ Ignore ]

[thumbnail] New cafe at Mount Austin
Restaurant: [ Search restaurant... ]
[ Approve ]
```

Possible statuses:

```text
discovered
pending_review
approved
ignored
duplicate
```

---

# 6M. Multi-Creator Discovery

Support batch discovery.

Example admin input:

```text
@creator_a
@creator_b
@creator_c
@creator_d
```

Backend creates one discovery job per creator.

Process with controlled concurrency.

Example configuration:

```env
TIKTOK_DISCOVERY_MAX_CONCURRENT_PROFILES=2
```

Do not launch dozens/hundreds of browsers simultaneously.

Use queue throttling.

---

# 6N. Incremental Sync

After a creator has been discovered once, future runs should attempt incremental sync.

Store:

```text
last_discovered_video_id
last_discovery_at
known video IDs
```

On next run:

```text
profile
  |
  v
newest videos first
  |
  +-- new
  +-- new
  +-- known video ID
        |
        v
stop after configured known-item threshold
```

Example:

```env
TIKTOK_DISCOVERY_STOP_AFTER_KNOWN_VIDEOS=10
```

This avoids scanning an entire profile on every synchronization.

---

# 6O. Discovery Scheduling

Allow optional scheduled synchronization.

Example:

```text
Creator A -> once daily
Creator B -> once daily
Creator C -> manual only
```

Recommended default:

```text
manual
```

Do not automatically schedule all creators unless required.

If scheduling is enabled:

```text
once every 24 hours
```

is a reasonable starting point.

---

# 6P. Discovery Rate Protection

The public web scraper does not have a guaranteed published API quota.

Therefore implement conservative application limits.

Example:

```env
TIKTOK_DISCOVERY_DELAY_BETWEEN_PROFILES_SECONDS=10
TIKTOK_DISCOVERY_MAX_CONCURRENT_PROFILES=2
TIKTOK_DISCOVERY_MAX_VIDEOS_PER_PROFILE=500
```

Use:

- queue throttling
- request timeouts
- retries with backoff
- circuit breaker after repeated failures

If repeated blocking occurs:

```text
pause discovery provider
```

Do not escalate into anti-bot evasion.

---

# 6Q. Optional Official API Provider

Keep the discovery interface flexible enough that an official TikTok API provider can be added later if TikTok exposes a commercial endpoint suitable for arbitrary public profile discovery.

Do not make the application architecture dependent on scraping.

Example:

```text
TikTokDiscoveryProvider

public_web
official_api
approved_third_party
```

The same normalized output must be returned by every provider:

```text
username
video_id
video_url
```

---

# 6R. Discovery Tests

Add Python tests for:

```text
username normalization
profile URL normalization
video ID extraction
duplicate video detection
multiple usernames
empty profile
private/unavailable profile
network timeout
HTML markup change
browser verification detected
maximum video limit
incremental synchronization
```

Use recorded/mock HTML fixtures where possible.

Do not hit TikTok from automated CI tests.

For Playwright integration tests, use local HTML fixtures that simulate:

```text
profile video grid
lazy-loaded additional videos
empty profile
verification page
```

---

# 6S. Discovery Acceptance Criteria

The discovery feature is complete when:

- [ ] Admin can enter one TikTok username.
- [ ] Admin can enter multiple TikTok usernames.
- [ ] Leading `@` is normalized correctly.
- [ ] TikTok profile URLs are accepted as input.
- [ ] Python worker can collect public video URLs without login when TikTok exposes them publicly.
- [ ] Video IDs are extracted and deduplicated.
- [ ] Results are persisted.
- [ ] Existing videos are not duplicated.
- [ ] New URLs enter the existing metadata ingestion pipeline.
- [ ] Scraped/discovered videos remain pending until mapped to a restaurant.
- [ ] Incremental re-sync is supported.
- [ ] Blocking/verification is detected and reported.
- [ ] No CAPTCHA bypass is implemented.
- [ ] No login/session-cookie dependency exists.
- [ ] CI tests do not scrape the live TikTok website.
- [ ] Discovery can be disabled by configuration.


# 7. TikTok Metadata Service

Create:

```text
TikTokMetadataService
```

Primary responsibility:

Fetch metadata from TikTok oEmbed.

Example endpoint:

```text
https://www.tiktok.com/oembed?url=<encoded TikTok URL>
```

Possible metadata:

```text
title
author_name
author_url
thumbnail_url
html
```

Store the response in:

```text
restaurant_review_videos.raw_metadata
```

Map the useful values to normalized columns.

Example:

```text
title -> title
author_name -> creator.display_name
author_url -> creator.profile_url
thumbnail_url -> thumbnail_url
html -> embed_html
```

Do not make the application depend on fields that TikTok does not guarantee.

---

# 8. TikTok Metadata Caching Strategy

This is critical.

Do NOT fetch TikTok metadata every time the app requests a feed.

Metadata fetch should happen:

```text
TikTok URL inserted
        |
        v
Queue metadata fetch
        |
        v
Store result in DB
        |
        v
Users read cached DB data
```

Recommended behavior:

### Initial ingestion

Immediately queue:

```text
FetchTikTokMetadataJob
```

### Refresh

Refresh only when:

- admin manually requests refresh
- cached metadata becomes stale
- video has not been checked for a configured period
- a playback/unavailable event indicates possible status change

Suggested initial stale interval:

```text
7 days
```

Make this configurable:

```env
TIKTOK_METADATA_REFRESH_DAYS=7
```

---

# 9. Queue Jobs

Use background jobs for external TikTok metadata fetching.

Create:

```text
FetchTikTokMetadataJob
RefreshTikTokMetadataJob
```

Requirements:

- queueable
- retries
- exponential backoff
- exception handling
- logging
- no infinite retries

Suggested retry configuration:

```text
tries = 3
backoff:
- 30 seconds
- 120 seconds
- 600 seconds
```

On final failure:

```text
metadata_status = failed
metadata_error = sanitized error message
```

Do not delete the review automatically.

---

# 10. Rate-Limit Protection

Even though feed requests should not hit TikTok directly, add defensive limits.

Implement:

```text
TikTokRequestLimiter
```

Possible strategy:

```text
Redis/cache lock
+
application rate limiter
+
queue throttling
```

For example:

```text
Maximum N oEmbed requests/minute per worker/application
```

Make limit configurable rather than hard-coded.

Example:

```env
TIKTOK_OEMBED_MAX_REQUESTS_PER_MINUTE=100
```

Important:

This value is an internal safety limit and is not a claim about TikTok's actual oEmbed quota.

If throttled internally:

- reschedule the job
- do not fail permanently

---

# 11. Admin / Filament Workflow

If the backend uses Filament, create a resource or relation manager for TikTok restaurant reviews.

Possible UI:

```text
Restaurant
└── Review Videos
```

Add Review form:

```text
TikTok URL
[________________________________]

Restaurant
[ Search restaurant            v ]

Featured
[ ]

Status
[ Draft / Published ]

[ Fetch Preview ]
```

After the URL is entered:

```text
TikTok Preview

Thumbnail
Creator: @jbfoodie
Title: Best burger in JB
Platform: TikTok

[ Save Review ]
```

Admin actions:

```text
Refresh TikTok Metadata
Open Original TikTok
Mark Unavailable
Archive
Feature / Unfeature
Move to another Restaurant
```

Display metadata status badge:

```text
Fetched
Pending
Failed
Stale
```

---

# 12. API Endpoints

Keep mobile clients completely independent from TikTok metadata fetching.

## Restaurant reviews

```http
GET /api/restaurants/{restaurant}/reviews
```

Possible response:

```json
{
  "data": [
    {
      "id": "uuid",
      "platform": "tiktok",
      "creator": {
        "username": "jbfoodie",
        "display_name": "JB Foodie",
        "avatar_url": null
      },
      "video": {
        "external_id": "1234567890",
        "url": "https://www.tiktok.com/@jbfoodie/video/1234567890",
        "title": "Best burger in JB",
        "thumbnail_url": "https://...",
        "embed_url": "..."
      },
      "restaurant": {
        "id": "uuid",
        "name": "Woodfire Burger"
      }
    }
  ]
}
```

---

## Swipe feed

```http
GET /api/feed
```

Support pagination.

Recommended:

```text
cursor-based pagination
```

Feed filters can later include:

```text
latitude
longitude
radius
category
halal
price range
creator
restaurant
```

Example:

```http
GET /api/feed?lat=1.4927&lng=103.7414&radius=20
```

Backend should return cached data only.

---

# 13. Feed Ranking

Start simple.

Possible ranking:

```text
featured reviews
+
nearby restaurants
+
recently added reviews
+
randomization
```

Do not over-engineer recommendation ML initially.

Suggested V1:

```text
score =
    location_score
    + freshness_score
    + featured_score
```

Prevent the same restaurant from appearing excessively.

Example rule:

```text
maximum 2 consecutive videos from same restaurant
```

---

# 14. Mobile App UI

Build the feed as a vertical swipe experience.

Concept:

```text
--------------------------------
|                              |
|       TikTok Review          |
|                              |
|                              |
| @jbfoodie                    |
| Best burger in JB!           |
|                              |
| Woodfire Burger              |
| Johor Bahru                  |
|                              |
| [ View Restaurant ]          |
--------------------------------
```

Suggested behavior:

Current item:

```text
TikTok embed loaded
```

Next item:

```text
thumbnail/prepared
```

Previous/far-away items:

```text
embed disposed/unloaded
```

Do not initialize every TikTok embed in the feed.

---

# 15. Lazy Loading Strategy

For a feed such as:

```text
Video 1
Video 2
Video 3
Video 4
Video 5
```

When user views Video 3:

```text
Video 1 -> disposed
Video 2 -> optional cached
Video 3 -> active TikTok embed
Video 4 -> preload thumbnail only
Video 5 -> thumbnail only
```

Only keep the smallest reasonable number of active WebViews/players.

If using Flutter:

- avoid creating a WebView for every feed item
- dispose the inactive WebView
- consider maintaining only current + adjacent player
- preserve swipe position separately from player state

---

# 16. TikTok Embed Component

Create a reusable component.

Example:

```text
TikTokEmbedPlayer
```

Inputs:

```text
videoUrl
videoId
autoplay
isActive
```

Responsibilities:

- render TikTok embed
- start/load only when active
- stop/dispose when inactive
- show loading state
- show unavailable state
- provide "Open in TikTok" fallback

Fallback:

```text
Video unavailable

[ Open on TikTok ]
```

Do not block the rest of the Swipe Eat feed if one TikTok video fails.

---

# 17. Restaurant Detail Page

Restaurant page should aggregate all associated TikTok reviews.

Example:

```text
Woodfire Burger

Johor Bahru
Burger · RM20-RM40

[ Directions ]

Reviews from creators

@jbfoodie
[TikTok review]

@makanmana
[TikTok review]

@foodhunter
[TikTok review]
```

Allow multiple creators to review the same restaurant.

Allow one creator to review multiple restaurants.

---

# 18. Duplicate Detection

When adding a TikTok URL:

1. Normalize URL.
2. Extract video ID.
3. Search:

```text
platform = tiktok
external_video_id = <video id>
```

If found:

```text
This TikTok video already exists.
```

Provide admin with existing record link instead of creating duplicate.

---

# 19. Deleted / Private TikTok Videos

TikTok content may later become:

- private
- deleted
- restricted
- removed
- unavailable

Swipe Eat must handle this gracefully.

Possible state:

```text
status = unavailable
```

Do not delete historical records immediately.

Admin should still see:

```text
creator
original URL
restaurant association
last successful metadata
last checked date
```

Mobile API should normally exclude unavailable videos.

---

# 20. Security

External URL handling must be secure.

Requirements:

- whitelist TikTok domains
- validate redirect destinations
- block localhost URLs
- block private IP ranges
- prevent SSRF
- set outbound HTTP timeout
- limit response body size
- sanitize stored embed HTML
- do not trust arbitrary HTML returned by external services

If possible, avoid returning raw `embed_html` directly to the mobile client.

Prefer building embed URLs/components from known TikTok IDs.

---

# 21. Observability

Log external TikTok operations.

Useful events:

```text
tiktok.metadata.fetch.started
tiktok.metadata.fetch.success
tiktok.metadata.fetch.failed
tiktok.video.marked_unavailable
```

Metrics worth tracking:

```text
TikTok metadata requests/day
success percentage
failure percentage
429 responses
average response time
pending jobs
unavailable video count
```

---

# 22. API Resilience

TikTok outage must NOT cause Swipe Eat outage.

Example:

```text
TikTok temporarily unavailable

Swipe Eat:
- restaurant search works
- restaurant detail works
- cached thumbnails/details work
- feed can continue
- individual player may show unavailable/retry
```

External TikTok requests should never happen synchronously inside:

```text
GET /api/feed
```

or:

```text
GET /api/restaurants/{id}
```

---

# 23. Suggested Service Structure

For Laravel:

```text
app/
├── Models/
│   ├── Restaurant.php
│   ├── Creator.php
│   └── RestaurantReviewVideo.php
│
├── Services/
│   └── TikTok/
│       ├── TikTokUrlService.php
│       ├── TikTokMetadataService.php
│       └── TikTokRequestLimiter.php
│
├── Jobs/
│   ├── FetchTikTokMetadataJob.php
│   └── RefreshTikTokMetadataJob.php
│
├── Http/
│   ├── Controllers/
│   │   ├── FeedController.php
│   │   └── RestaurantReviewController.php
│   └── Resources/
│       ├── RestaurantReviewResource.php
│       └── FeedItemResource.php
│
└── Filament/
    └── Resources/
        └── RestaurantReviewVideoResource.php
```

Adjust this structure to match the existing repository conventions.

Do not create duplicate layers if equivalent architecture already exists.

---

# 24. Phase 2 — TikTok Creator Connection

Do NOT make this part of the initial implementation unless the rest is complete.

Later, creators can connect their TikTok account using TikTok Login / Display API.

Possible flow:

```text
Creator
    |
    | Connect TikTok
    v
TikTok OAuth
    |
    | video.list
    v
Swipe Eat
    |
    | Retrieve creator's videos
    v
Creator selects which videos are restaurant reviews
```

Store tokens securely server-side.

Never store TikTok tokens in the mobile application.

Suggested future tables:

```text
social_connections
```

Fields:

```text
id
user_id
platform
platform_user_id
access_token_encrypted
refresh_token_encrypted
expires_at
scopes
metadata
```

---

# 25. Phase 3 — Semi-Automatic Restaurant Matching

Later enhancement:

When a TikTok review is ingested:

```text
caption
+
location
+
hashtags
+
creator input
```

can be used to suggest a restaurant.

Possible flow:

```text
TikTok:
"Best burger at Woodfire JB!"

        |
        v

Restaurant matching service

        |
        +-- Woodfire Burger 94%
        +-- Woodfire Eco Palladium 81%
        +-- Other 22%

Admin selects correct restaurant.
```

Do not automatically publish uncertain matches.

---



# TikTok Stable IDs, Expiring URLs, and Media Refresh Strategy

## Purpose

TikTok-derived URLs must not all be treated as permanent.

Swipe Eat must distinguish between:

### Stable references

Store these as the durable source of truth:

```text
external_video_id
canonical_url
creator username
restaurant_id
platform
```

Example:

```text
external_video_id = 7523456789123456789
canonical_url = https://www.tiktok.com/@jbfoodie/video/7523456789123456789
```

### Temporary references

Treat these only as disposable/cacheable metadata:

```text
thumbnail_url
cover_image_url
direct TikTok CDN video URL
signed CDN URL
temporary media URL
```

Never make the permanent restaurant-review relationship depend on one of these temporary URLs.

---

## Critical Rule

For TikTok records:

```text
external_video_id
```

is the primary external reference.

The application must be able to continue identifying a TikTok review even when:

```text
thumbnail_url
cover_image_url
embed metadata
CDN URL
```

has expired.

Do NOT use a TikTok CDN media URL as the unique identifier for a review.

---

## Database Changes

`restaurant_review_videos` should support:

```text
id
uuid

restaurant_id
creator_id nullable

platform

external_video_id
canonical_url

title nullable
caption nullable

thumbnail_url nullable
thumbnail_expires_at nullable

metadata_status
last_metadata_sync_at nullable
next_metadata_sync_at nullable
metadata_error nullable

status

is_featured boolean
is_active boolean

raw_metadata json nullable

created_at
updated_at
```

Recommended uniqueness:

```text
unique(platform, external_video_id)
```

For TikTok:

```text
platform = tiktok
external_video_id = TikTok post/video ID
```

---

## Never Persist Direct CDN URLs as Playback Source

Do not design playback around URLs such as:

```text
https://p16-sign-*.tiktokcdn.com/...
```

or any URL containing temporary signing/expiration parameters.

These may expire.

If the discovery process encounters a direct media/CDN URL:

1. Do not use it as the permanent video reference.
2. Extract/recover the canonical TikTok post URL/video ID where possible.
3. Store only the canonical identity as the durable reference.
4. Treat the CDN URL as temporary and optional.

---

## TikTok Player URL

When appropriate for the client implementation, derive the TikTok embed/player reference from the stable TikTok video ID rather than persisting a signed media URL.

Conceptually:

```text
DATABASE

external_video_id
        |
        v
derive TikTok player/embed reference
        |
        v
TikTok-hosted playback
```

For example:

```text
https://www.tiktok.com/player/v1/{VIDEO_ID}
```

Do not download and re-host the underlying TikTok MP4.

Keep player URL construction in a dedicated helper/service so TikTok-specific URL formats can be changed in one place.

Example:

```text
TikTokEmbedUrlService
```

Method:

```text
buildPlayerUrl(videoId)
```

---

## Thumbnail Expiration

TikTok thumbnails/cover-image URLs must be considered temporary.

Store:

```text
thumbnail_url
thumbnail_expires_at
```

If the provider does not give an exact expiration timestamp, use a conservative application-defined refresh time.

Configuration example:

```env
TIKTOK_THUMBNAIL_REFRESH_HOURS=5
```

The configured value is an internal cache policy, not a claim about a guaranteed TikTok TTL.

---

## Thumbnail Serving Flow

Do NOT do this:

```text
GET /api/feed
     |
     v
TikTok metadata request
     |
     v
wait
     |
     v
return feed
```

Instead:

```text
GET /api/feed
     |
     v
read Swipe Eat DB
     |
     v
return cached feed immediately
     |
     +---- thumbnail valid
     |          |
     |          v
     |       display
     |
     +---- thumbnail expired/missing
                |
                v
         queue metadata refresh
```

TikTok metadata requests must remain outside the critical feed request path.

---

## Expired Thumbnail UI

If a cached thumbnail no longer works:

```text
+------------------------+
|                        |
|     TikTok Review      |
|          Play          |
|                        |
|      @creator          |
+------------------------+
```

The mobile app should display a local/default TikTok review placeholder.

Do not repeatedly retry a broken thumbnail from every client.

---

## Metadata Refresh Job

Create or extend:

```text
RefreshTikTokMetadataJob
```

Responsibilities:

1. Load stable TikTok video ID/canonical URL.
2. Request refreshed metadata through the configured metadata provider.
3. Replace temporary thumbnail/cover URL.
4. Update:
   - `thumbnail_url`
   - `thumbnail_expires_at`
   - `last_metadata_sync_at`
   - `next_metadata_sync_at`
   - `metadata_status`
5. Preserve restaurant and creator relationships.
6. Never replace the stable video ID because a temporary URL expired.

---

## Refresh Scheduling

Use a scheduled backend process to identify records requiring refresh.

Concept:

```text
Scheduler
   |
   v
find TikTok records where:

thumbnail_expires_at <= refresh threshold

OR

metadata_status = stale

OR

next_metadata_sync_at <= now

   |
   v
dispatch RefreshTikTokMetadataJob
```

Batch jobs.

Do not dispatch thousands simultaneously.

Use queue throttling.

---

## Stale-While-Revalidate

Prefer a stale-while-revalidate model.

```text
cached metadata
       |
       +-- valid -> use normally
       |
       +-- stale but usable
       |       |
       |       +-- serve cached information
       |       +-- refresh asynchronously
       |
       +-- broken
               |
               +-- show placeholder
               +-- refresh asynchronously
```

Restaurant information must continue working regardless of TikTok metadata state.

---

## Video Availability

Stable video IDs do not mean the TikTok post will exist forever.

A creator may:

```text
delete the video
make the video private
restrict the video
change account visibility
lose the account
```

TikTok may also remove content.

Recommended video statuses:

```text
active
needs_check
unavailable
archived
```

Do not immediately delete unavailable records.

Preserve:

```text
external_video_id
canonical_url
creator
restaurant association
last known title
last known metadata
last successful sync
```

This allows administration/auditing and avoids losing restaurant-review relationships unexpectedly.

---

## Availability Check

If metadata refresh indicates that the original TikTok is unavailable:

```text
active
   |
   v
needs_check
   |
   +-- retry succeeds -> active
   |
   +-- repeated confirmed unavailable -> unavailable
```

Do not mark a video permanently unavailable after one transient timeout.

Use configurable retry/backoff.

---

## Mobile Playback Strategy

The mobile app should receive:

```json
{
  "platform": "tiktok",
  "external_video_id": "7523456789123456789",
  "canonical_url": "https://www.tiktok.com/@jbfoodie/video/7523456789123456789",
  "thumbnail_url": "...",
  "thumbnail_expires_at": "...",
  "status": "active"
}
```

The client should not require a direct TikTok MP4/CDN URL.

Playback should use the supported TikTok embed/player mechanism.

If playback fails:

```text
show fallback
       |
       +-- Retry
       |
       +-- Open on TikTok
```

and optionally report the failure to Swipe Eat so the backend can schedule a status check.

---

## Discovery Pipeline Update

The Python discovery worker must prioritize collecting:

```text
username
video_id
canonical_url
```

rather than direct media URLs.

Updated discovery:

```text
@creator
    |
    v
Python discovery
    |
    +-- video ID
    +-- canonical TikTok URL
    |
    v
deduplicate
    |
    v
Swipe Eat database
    |
    v
metadata enrichment
```

If temporary CDN URLs are found during scraping, they must not become the canonical stored reference.

---

## Example

Python discovers:

```text
https://www.tiktok.com/@jbfoodie/video/7523456789123456789
```

Store:

```json
{
  "platform": "tiktok",
  "username": "jbfoodie",
  "external_video_id": "7523456789123456789",
  "canonical_url": "https://www.tiktok.com/@jbfoodie/video/7523456789123456789"
}
```

Temporary metadata may later be:

```json
{
  "thumbnail_url": "https://temporary-tiktok-cdn/...",
  "thumbnail_expires_at": "..."
}
```

When the thumbnail expires:

```text
DO NOT rescrape the entire creator account.

video ID
   |
   v
metadata refresh
   |
   v
new thumbnail
```

The restaurant relationship remains untouched.

---

## Architecture

```text
              PERMANENT IDENTITY

                  TikTok
                    |
                    v
             canonical post
                    |
             +------+------+
             |             |
          video_id      username
             |
             v
        Swipe Eat DB
             |
             +--------------------------+
             |                          |
             v                          v
      Restaurant mapping         Creator mapping


              TEMPORARY MEDIA

            metadata provider
                  |
                  v
             thumbnail URL
                  |
                  v
                cache
                  |
            expires/stale
                  |
                  v
            background refresh
```

---

## Additional Acceptance Criteria

- [ ] TikTok `external_video_id` is treated as the durable external identifier.
- [ ] Canonical TikTok post URL is stored.
- [ ] Direct TikTok CDN URLs are never used as permanent identifiers.
- [ ] Direct MP4/CDN URLs are not required for mobile playback.
- [ ] Thumbnail URLs are explicitly treated as temporary.
- [ ] Thumbnail expiration/refresh state is persisted.
- [ ] Expired thumbnails do not break the feed.
- [ ] Metadata refresh happens asynchronously.
- [ ] Feed requests never wait for TikTok metadata refresh.
- [ ] Video metadata can be refreshed from stable identity.
- [ ] Temporary metadata expiration does not remove restaurant mappings.
- [ ] Deleted/private TikTok posts are handled separately from expired metadata.
- [ ] One transient failure does not permanently mark a TikTok unavailable.
- [ ] Python discovery prioritizes video ID + canonical URL.
- [ ] Existing CDN URL dependencies are removed/refactored.


# 26. Testing Requirements

Create automated tests.

## Unit tests

TikTok URL parser:

```text
valid long TikTok URL
valid short TikTok URL
invalid TikTok URL
non-TikTok URL
missing video ID
malicious redirect
duplicate URL
```

Metadata service:

```text
successful oEmbed
timeout
404
429
500
invalid JSON
missing optional fields
```

---

## Feature tests

```text
admin can add TikTok review
review is linked to restaurant
duplicate video rejected
metadata job dispatched
metadata stored
failed metadata request does not break record
unavailable videos excluded from public feed
feed returns cached metadata
feed does not trigger TikTok HTTP request
```

Mock all TikTok HTTP calls.

Tests must never depend on the real TikTok network.

---

# 27. Acceptance Criteria

The feature is considered complete when:

- [ ] Admin can paste a public TikTok video URL.
- [ ] System validates TikTok URL.
- [ ] System extracts TikTok video ID when possible.
- [ ] Admin can associate the video with a restaurant.
- [ ] Duplicate TikTok videos are prevented.
- [ ] TikTok metadata is fetched asynchronously.
- [ ] Metadata is cached in the database.
- [ ] Creator record is created/reused.
- [ ] Restaurant detail API returns associated TikTok reviews.
- [ ] Swipe feed API returns TikTok review cards.
- [ ] Feed API does not make direct TikTok requests.
- [ ] Mobile app lazy-loads TikTok embed/player.
- [ ] Inactive players are disposed.
- [ ] Deleted/private/unavailable videos are handled gracefully.
- [ ] Failed metadata fetches retry with backoff.
- [ ] TikTok failures do not break restaurant browsing.
- [ ] External URL fetching is protected against SSRF.
- [ ] Automated tests cover the main flows.

---

# 28. Implementation Order

Claude should implement this in the following order.

## Step 1 — Inspect Existing Project

Before changing anything:

1. Inspect repository structure.
2. Identify:
   - framework versions
   - current restaurant models
   - authentication
   - admin implementation
   - API conventions
   - queue configuration
   - mobile framework
3. Reuse existing architecture and naming conventions.

Do not immediately generate new duplicate models.

---

## Step 2 — Database

Implement:

```text
creators
restaurant_review_videos
```

and necessary model relationships.

---

## Step 2A — Python TikTok Discovery Service

Implement the optional no-login public-profile discovery layer:

```text
username(s)
    |
    v
Python discovery worker
    |
    v
public TikTok video URLs
    |
    v
existing ingestion pipeline
```

Requirements:

- no TikTok login
- no private API dependency
- no CAPTCHA bypass
- configurable limits
- batch usernames
- incremental synchronization
- persistent discovery job status

If public TikTok markup prevents discovery, record the job as blocked/partial instead of attempting evasion.

---

## Step 3 — TikTok URL Service

Implement:

```text
TikTokUrlService
```

with tests.

---

## Step 4 — TikTok Metadata Service

Implement:

```text
TikTokMetadataService
```

using the official TikTok oEmbed endpoint.

Use Laravel HTTP client if Laravel is used.

Add:

```text
timeouts
retry handling
safe redirects
error normalization
```

---

## Step 5 — Queue

Implement:

```text
FetchTikTokMetadataJob
```

Ensure ingestion does not block on TikTok.

---

## Step 6 — Admin UI

Implement TikTok review management.

Prefer integrating it into the Restaurant resource.

---

## Step 7 — Public APIs

Implement:

```text
GET /api/feed
GET /api/restaurants/{restaurant}/reviews
```

Use API resources/serializers.

---

## Step 8 — Mobile Feed

Implement:

```text
vertical swipe feed
cached thumbnail
lazy TikTok embed/player
restaurant overlay
creator information
```

---

## Step 9 — Failure States

Implement:

```text
loading
unavailable
deleted/private
network error
open-on-TikTok fallback
```

---

## Step 10 — Tests

Add complete unit and feature tests.

Run the existing test suite and fix regressions.

---

# 29. Claude Development Instructions

Claude should:

1. Read this entire plan before coding.
2. Inspect the existing repository first.
3. Create a task checklist from this plan.
4. Implement incrementally.
5. Do not rewrite unrelated parts of the application.
6. Follow existing project conventions.
7. Prefer small, testable services.
8. Add migrations instead of manually changing schemas.
9. Add tests with each backend feature.
10. Run formatting/linting/tests after implementation.
11. Report any architecture conflict with the existing repository.
12. Do not use unofficial TikTok scraping libraries.
13. Do not use TikTok Research API.
14. Do not download or re-host TikTok videos.
15. Do not make TikTok network requests from the feed API.
16. Treat cached Swipe Eat data as the source for normal browsing.
17. Implement the Python public-profile discovery service only as a best-effort public-data collector.
18. Do not implement TikTok login automation, CAPTCHA solving, session-cookie theft, browser fingerprint spoofing, or proxy rotation intended to bypass TikTok controls.
19. Route every discovered URL through the same normalization, deduplication, metadata, and restaurant-review pipeline.
20. Keep the discovery provider behind an interface so it can later be replaced with an official or approved provider.
21. Treat TikTok video IDs and canonical post URLs as stable identity; treat thumbnails/CDN URLs as temporary cache data.
22. Never make direct TikTok CDN/MP4 URLs the permanent playback or database identity.
23. Refresh expired TikTok metadata asynchronously and never from the critical feed request path.
24. Preserve restaurant-review relationships when TikTok temporary media URLs expire.



---

# 30. Final Desired Experience

Admin workflow:

```text
Admin
  |
  | paste TikTok review
  v
Swipe Eat
  |
  +-- identifies creator
  +-- stores thumbnail/title
  +-- associates restaurant
  +-- publishes review
```

User workflow:

```text
Open Swipe Eat
    |
    v
Swipe Food Reviews
    |
    +-- TikTok review
    +-- Restaurant name
    +-- Distance
    +-- Location
    |
    v
Tap Restaurant
    |
    v
Restaurant Detail
    |
    +-- Restaurant information
    +-- Map / directions
    +-- Reviews from multiple TikTok creators
```

Core principle:

> TikTok provides the review content. Swipe Eat provides the restaurant intelligence, organization, discovery, and user experience.
