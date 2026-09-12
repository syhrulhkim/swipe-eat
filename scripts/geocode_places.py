#!/usr/bin/env python3
"""Fill in rating/latitude/longitude for scraped restaurants via Google Places.

The scraper writes rows with rating/latitude/longitude all set to 0, because a
TikTok caption gives a human-readable address, not a fix, and no rating at all.
This is the pass that resolves them. It is the fourth stage of the pipeline:

    scrape_tiktok.py -> extract_restaurants.py -> restaurants_to_sql.py -> here

Rows are read straight from PostgREST with the publishable key (RLS makes that
safe, and it keeps the row list out of the agent transcript). Only rows still
sitting at latitude = 0 and longitude = 0 are looked up, so the script can be
re-run after every insert batch and will pick up exactly the new rows.

Lookups go through Places Text Search (New). Asking for `rating` puts the call
in the Enterprise SKU (as of 2026-08: $35 per 1000 after 1000 free per month),
so every response is cached to a JSONL file keyed by video_url and never paid
for twice -- a crash or a Ctrl-C costs nothing on the next run.

The caption address is the query hint. It is noisy (it usually leads with the
business name and often trails notes like "[Non-Halal]" or an event date), so
`build_query` strips the notes and pairs the restaurant name with the address
tail. Failing that it falls back to "<name>, <negeri>, Malaysia" -- the state
matters, or a chain like Nasi Kandar Pelita resolves to the wrong outlet.

Writes are not applied directly: the script emits batched UPDATE ... FROM
(VALUES ...) statements joined on video_url, ~100 rows each, for execution
through whatever SQL path is available.

Usage:
    export GOOGLE_MAPS_API_KEY=...        # or write it to ~/.config/swipe-eat/places_api_key
    python3 scripts/geocode_places.py --out-dir /tmp/geo --addresses /tmp/url_address.json
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://vpcldlhqpvunnuexecgn.supabase.co"
)
SUPABASE_KEY = os.environ.get(
    "SUPABASE_KEY", "sb_publishable_1omniagj5KKjXdHafC28nQ_uvS28WMO"
)
KEY_FILE = pathlib.Path.home() / ".config" / "swipe-eat" / "places_api_key"

PLACES_ENDPOINT = "https://places.googleapis.com/v1/places:searchText"
FIELD_MASK = ",".join(
    [
        "places.id",
        "places.displayName",
        "places.formattedAddress",
        "places.location",
        "places.rating",
        "places.userRatingCount",
    ]
)

# Caption noise: bracketed dietary notes, "Status: ..." tails, opening dates.
BRACKET_NOTE = re.compile(r"\[[^\]]*\]")
STATUS_TAIL = re.compile(r"\bStatus:.*$", re.IGNORECASE | re.DOTALL)
DATE_TAIL = re.compile(
    r"\b\d{1,2}\s+(January|February|March|April|May|June|July|August|September"
    r"|October|November|December)\b.*$",
    re.IGNORECASE | re.DOTALL,
)


def read_api_key() -> str:
    key = os.environ.get("GOOGLE_MAPS_API_KEY", "").strip()
    if key:
        return key
    if KEY_FILE.exists():
        return KEY_FILE.read_text(encoding="utf-8").strip()
    sys.exit(
        "No Places API key. Set GOOGLE_MAPS_API_KEY or write the key to "
        f"{KEY_FILE}"
    )


def fetch_rows(page_size: int = 1000) -> list[dict]:
    """Every active row that still has no map fix, oldest id first."""
    rows: list[dict] = []
    offset = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "select": "id,name,negeri,negara,video_url",
                "latitude": "eq.0",
                "longitude": "eq.0",
                "order": "id.asc",
                "limit": page_size,
                "offset": offset,
            }
        )
        request = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/restaurants?{query}",
            headers={"apikey": SUPABASE_KEY, "Accept": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            page = json.load(response)
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size


def clean_address(address: str) -> str:
    address = BRACKET_NOTE.sub("", address)
    address = STATUS_TAIL.sub("", address)
    address = DATE_TAIL.sub("", address)
    return re.sub(r"\s+", " ", address).strip(" ,")


def build_query(row: dict, address: str | None) -> str:
    """Name first, then whatever geography we have. Places ranks on both."""
    name = row["name"]
    negeri = row.get("negeri") or ""
    if address:
        cleaned = clean_address(address)
        # The address usually repeats the name as its first component; keep it
        # only once so the query does not read as a duplicated phrase.
        parts = [p.strip() for p in cleaned.split(",") if p.strip()]
        if parts and parts[0].lower() == name.lower():
            parts = parts[1:]
        if parts:
            cleaned = ", ".join(parts)
            return f"{name}, {cleaned}, Malaysia"
    if negeri:
        return f"{name}, {negeri}, Malaysia"
    return f"{name}, Malaysia"


def search_text(api_key: str, query: str) -> dict | None:
    body = json.dumps(
        {
            "textQuery": query,
            "languageCode": "en",
            "regionCode": "MY",
            "maxResultCount": 1,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        PLACES_ENDPOINT,
        data=body,
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": FIELD_MASK,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:200]
        return {"error": f"HTTP {error.code}: {detail}"}
    except Exception as error:  # network flakiness; retried on the next run
        return {"error": str(error)}
    places = payload.get("places") or []
    return places[0] if places else None


def load_cache(path: pathlib.Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    cache: dict[str, dict] = {}
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            cache[record["video_url"]] = record
    return cache


def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def render_statements(records: list[dict], out_dir: pathlib.Path, chunk: int) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for index in range(0, len(records), chunk):
        batch = records[index : index + chunk]
        values = ",\n    ".join(
            "({}, {}, {}, {})".format(
                quote(record["video_url"]),
                repr(float(record["latitude"])),
                repr(float(record["longitude"])),
                repr(float(record["rating"])),
            )
            for record in batch
        )
        statement = (
            "update public.restaurants as r\n"
            "set latitude = v.latitude, longitude = v.longitude, rating = v.rating\n"
            "from (values\n"
            f"    {values}\n"
            ") as v(video_url, latitude, longitude, rating)\n"
            "where r.video_url = v.video_url;\n"
        )
        written += 1
        (out_dir / f"stmt_geo_{written:02d}.sql").write_text(
            statement, encoding="utf-8"
        )
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out-dir", required=True, help="where the UPDATE statements are written"
    )
    parser.add_argument(
        "--addresses",
        help="url -> {address} map built from the candidates files (optional)",
    )
    parser.add_argument(
        "--cache", help="JSONL response cache (default: <out-dir>/places_cache.jsonl)"
    )
    parser.add_argument("--limit", type=int, help="only look up the first N rows")
    parser.add_argument("--chunk", type=int, default=100, help="rows per statement")
    parser.add_argument("--workers", type=int, default=5)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the queries that would be sent and exit",
    )
    args = parser.parse_args()

    out_dir = pathlib.Path(args.out_dir)
    cache_path = (
        pathlib.Path(args.cache) if args.cache else out_dir / "places_cache.jsonl"
    )
    addresses: dict[str, dict] = {}
    if args.addresses:
        addresses = json.loads(
            pathlib.Path(args.addresses).read_text(encoding="utf-8")
        )

    rows = fetch_rows()
    if args.limit:
        rows = rows[: args.limit]
    print(f"{len(rows)} rows without a fix", file=sys.stderr)

    cache = load_cache(cache_path)
    pending = [row for row in rows if row["video_url"] not in cache]
    print(f"{len(cache)} cached, {len(pending)} to look up", file=sys.stderr)

    if args.dry_run:
        for row in pending[:20]:
            hint = (addresses.get(row["video_url"]) or {}).get("address")
            print(build_query(row, hint))
        return

    api_key = read_api_key()
    out_dir.mkdir(parents=True, exist_ok=True)

    def lookup(row: dict) -> dict:
        hint = (addresses.get(row["video_url"]) or {}).get("address")
        query = build_query(row, hint)
        place = search_text(api_key, query)
        return {
            "video_url": row["video_url"],
            "name": row["name"],
            "query": query,
            "place": place,
        }

    done = 0
    with cache_path.open("a", encoding="utf-8") as handle:
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            for record in pool.map(lookup, pending):
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
                handle.flush()
                cache[record["video_url"]] = record
                done += 1
                if done % 50 == 0:
                    print(f"  {done}/{len(pending)}", file=sys.stderr)

    resolved: list[dict] = []
    errors = 0
    misses = 0
    for row in rows:
        record = cache.get(row["video_url"])
        place = record and record.get("place")
        if not place:
            misses += 1
            continue
        if place.get("error"):
            errors += 1
            continue
        location = place.get("location") or {}
        if not location.get("latitude"):
            misses += 1
            continue
        resolved.append(
            {
                "video_url": row["video_url"],
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                # A place with no ratings keeps the 0 sentinel, which the app
                # renders as an em dash rather than "0.0".
                "rating": place.get("rating") or 0,
            }
        )

    files = render_statements(resolved, out_dir, args.chunk)
    print(
        f"resolved {len(resolved)}, no match {misses}, errors {errors} -> "
        f"{files} statement file(s) in {out_dir}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
