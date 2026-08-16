#!/usr/bin/env python3
"""Scrape a TikTok user's public videos and upsert them into Supabase.

Setup:
    python3 -m pip install --user yt-dlp "curl_cffi>=0.10"

Usage:
    python3 scripts/scrape_tiktok.py johorfoodie
    python3 scripts/scrape_tiktok.py johorfoodie --limit 20 --out out.json

Env (only needed to write to Supabase; otherwise just writes --out JSON):
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY=your-service-role-key
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone

# ponytail: TikTok's anti-bot check randomly rejects ~1/3 of requests even
# with --impersonate; retry a few times instead of a real backoff/proxy pool.
MAX_ATTEMPTS = 4


def fetch_videos(handle, limit):
    cmd = [
        "yt-dlp",
        "--impersonate", "chrome",
        "--flat-playlist",
        "-j",
    ]
    if limit:
        cmd += ["--playlist-end", str(limit)]
    cmd.append(f"https://www.tiktok.com/@{handle}")

    proc = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            break
        print(f"  attempt {attempt}/{MAX_ATTEMPTS} failed, retrying...", file=sys.stderr)
        time.sleep(2)
    else:
        raise RuntimeError(f"yt-dlp failed for @{handle}: {proc.stderr.strip()}")

    videos = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        videos.append(map_entry(json.loads(line)))
    return videos


def map_entry(entry):
    thumbnails = entry.get("thumbnails") or []
    thumbnail_url = thumbnails[0]["url"] if thumbnails else None
    timestamp = entry.get("timestamp")

    return {
        "tiktok_id": entry["id"],
        "uploader": entry.get("uploader"),
        "video_url": entry.get("webpage_url") or entry.get("url"),
        "description": entry.get("description"),
        "thumbnail_url": thumbnail_url,
        "duration_seconds": entry.get("duration"),
        "view_count": entry.get("view_count"),
        "like_count": entry.get("like_count"),
        "comment_count": entry.get("comment_count"),
        "repost_count": entry.get("repost_count"),
        "posted_at": (
            datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat()
            if timestamp
            else None
        ),
    }


def upsert_to_supabase(videos, supabase_url, service_key):
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/tiktok_videos?on_conflict=tiktok_id"
    body = json.dumps(videos).encode("utf-8")
    req = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return resp.status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handles", nargs="+", help="TikTok handles, no @")
    parser.add_argument("--limit", type=int, default=0, help="0 = all videos")
    parser.add_argument("--out", default=None, help="write scraped JSON here")
    args = parser.parse_args()

    all_videos = []
    for handle in args.handles:
        print(f"scraping @{handle}...", file=sys.stderr)
        videos = fetch_videos(handle, args.limit)
        print(f"  found {len(videos)} videos", file=sys.stderr)
        all_videos.extend(videos)

    if args.out:
        with open(args.out, "w") as f:
            json.dump(all_videos, f, indent=2)
        print(f"wrote {args.out}", file=sys.stderr)

    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_KEY")
    if supabase_url and service_key:
        status = upsert_to_supabase(all_videos, supabase_url, service_key)
        print(f"upserted {len(all_videos)} videos to supabase (status {status})", file=sys.stderr)
    else:
        print(
            "SUPABASE_URL / SUPABASE_SERVICE_KEY not set — skipped DB upsert, "
            "data only written to --out (if given).",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
