#!/usr/bin/env python3
"""Scrape a TikTok user's public videos.

`--out` writes the mapped fields (what a `tiktok_videos` table would hold);
`--raw` writes yt-dlp's entries untouched, which is what `extract_restaurants.py`
reads to build restaurant rows. Scraping and parsing are separate steps on
purpose: TikTok listing is slow and rate-limited, so a caption is fetched once
and re-parsed as often as the extractor improves.

Setup (yt-dlp needs curl_cffi for `--impersonate`; without it TikTok answers
every request with an anti-bot page):
    python3 -m venv .venv
    .venv/bin/pip install yt-dlp "curl_cffi>=0.10"

Usage:
    python3 scripts/scrape_tiktok.py johorfoodie --raw videos.json
    python3 scripts/scrape_tiktok.py johorfoodie kakifoodie --limit 20 --out out.json

Env (only needed by `--upsert`; otherwise this only ever writes files):
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


def fetch_videos(handle, limit, ytdlp="yt-dlp"):
    """Every public video on a profile, as yt-dlp's raw entries.

    A profile that has been fully scraped before still returns everything —
    TikTok has no "since" cursor — so the way to stop re-processing an
    exhausted account is to filter downstream on the clips already stored,
    not to ask for fewer here.
    """
    cmd = [
        ytdlp,
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

    entries = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        entries.append(json.loads(line))
    return entries


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
    """POST the mapped videos to a `tiktok_videos` table.

    Opt-in via `--upsert`, and no such table exists in the schema today: the
    catalogue keeps one clip per restaurant on `restaurants.video_url` instead.
    Kept for a future raw-clip archive; running it against the current
    database returns a 404 rather than writing anything.
    """
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
    parser.add_argument("--out", default=None, help="write mapped JSON here")
    parser.add_argument(
        "--raw",
        default=None,
        help="write yt-dlp's entries here, for extract_restaurants.py",
    )
    parser.add_argument(
        "--ytdlp",
        default="yt-dlp",
        help="path to yt-dlp, e.g. .venv/bin/yt-dlp",
    )
    parser.add_argument(
        "--upsert",
        action="store_true",
        help="POST the mapped videos to a `tiktok_videos` table (needs SUPABASE_* env)",
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="carry on to the next handle when one fails, instead of stopping",
    )
    args = parser.parse_args()

    raw_entries = []
    failures = []
    for handle in args.handles:
        print(f"scraping @{handle}...", file=sys.stderr)
        try:
            entries = fetch_videos(handle, args.limit, ytdlp=args.ytdlp)
        except RuntimeError as error:
            # A dead, renamed or private handle should not cost the run every
            # other handle behind it.
            if not args.keep_going:
                raise
            print(f"  failed: {error}", file=sys.stderr)
            failures.append(handle)
            continue
        print(f"  found {len(entries)} videos", file=sys.stderr)
        raw_entries.extend(entries)

    all_videos = [map_entry(entry) for entry in raw_entries]

    if args.raw:
        with open(args.raw, "w") as f:
            json.dump(raw_entries, f, ensure_ascii=False)
        print(f"wrote {args.raw}", file=sys.stderr)

    if args.out:
        with open(args.out, "w") as f:
            json.dump(all_videos, f, indent=2, ensure_ascii=False)
        print(f"wrote {args.out}", file=sys.stderr)

    if failures:
        print(f"handles that failed: {', '.join(failures)}", file=sys.stderr)

    if not args.upsert:
        return

    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_KEY")
    if supabase_url and service_key:
        status = upsert_to_supabase(all_videos, supabase_url, service_key)
        print(f"upserted {len(all_videos)} videos to supabase (status {status})", file=sys.stderr)
    else:
        print(
            "--upsert given but SUPABASE_URL / SUPABASE_SERVICE_KEY are not set; "
            "nothing was written to the database.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
