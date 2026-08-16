#!/usr/bin/env python3
"""Self-check for map_entry. Run: python3 scripts/test_scrape_tiktok.py"""

from scrape_tiktok import map_entry

FIXTURE = {
    "id": "7673868828258061589",
    "uploader": "johorfoodie",
    "webpage_url": "https://www.tiktok.com/@johorfoodie/video/7673868828258061589",
    "description": "Desaru Multisport Festival...",
    "thumbnails": [{"url": "https://example.com/cover.jpg"}],
    "duration": 85,
    "view_count": 4937,
    "like_count": 81,
    "comment_count": 1,
    "repost_count": 18,
    "timestamp": 1786711825,
}

result = map_entry(FIXTURE)
assert result["tiktok_id"] == "7673868828258061589"
assert result["video_url"].endswith("/7673868828258061589")
assert result["thumbnail_url"] == "https://example.com/cover.jpg"
assert result["posted_at"].startswith("2026-08-")
assert result["like_count"] == 81

no_thumb = map_entry({**FIXTURE, "thumbnails": [], "timestamp": None})
assert no_thumb["thumbnail_url"] is None
assert no_thumb["posted_at"] is None

print("ok")
