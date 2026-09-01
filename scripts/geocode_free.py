#!/usr/bin/env python3
"""Fill in latitude/longitude for scraped restaurants without a paid API.

Two free sources, cheapest first:

  1. Overture Maps places -- an open POI dataset (Meta + Microsoft + OSM) with
     names, addresses and coordinates. Pulled once into a local parquet file,
     then matched offline: no key, no rate limit, no per-row cost. Overture is
     ODbL/CDLA, so the coordinates can be stored in our own database.
  2. OSM Nominatim -- for whatever Overture could not match. Public instance,
     so one request per second, and results coarser than a suburb are thrown
     away rather than written: a state centroid is worse than no fix at all,
     because the app hides the directions button on 0/0 but happily routes to
     a wrong one.

Neither source has ratings. Rows keep rating = 0, which the app renders as an
em dash. Ratings need a paid Places API -- see scripts/geocode_places.py.

Rows come from PostgREST with the publishable key, filtered to the ones still
at latitude = 0 and longitude = 0, so this is safe to re-run after every batch
of inserts. Matching is confined to the bounding box of the row's `negeri`,
which is what stops a chain like Nasi Kandar Pelita resolving to an outlet in
the wrong state.

Output is batched UPDATE ... FROM (VALUES ...) statements joined on video_url,
plus a TSV report of what matched and how.

Usage:
    # once, ~85MB, takes a few minutes
    python3 scripts/geocode_free.py pull-overture --out-dir /tmp/geo
    # then, repeatable
    python3 scripts/geocode_free.py match --out-dir /tmp/geo \
        --addresses /tmp/geo/url_address.json
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

OVERTURE_RELEASE = os.environ.get("OVERTURE_RELEASE", "2026-08-19.0")
OVERTURE_GLOB = (
    f"s3://overturemaps-us-west-2/release/{OVERTURE_RELEASE}"
    "/theme=places/type=place/*.parquet"
)
# Malaysia plus a margin; the per-state boxes do the real filtering later.
MY_BBOX = {"west": 99.5, "east": 119.5, "south": 0.8, "north": 7.5}

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://vpcldlhqpvunnuexecgn.supabase.co"
)
SUPABASE_KEY = os.environ.get(
    "SUPABASE_KEY", "sb_publishable_1omniagj5KKjXdHafC28nQ_uvS28WMO"
)

NOMINATIM = "https://nominatim.openstreetmap.org/search"
USER_AGENT = "swipe-eat-geocode/1.0 (syahrul.hakim@ocglobaltech.com)"
# Anything at this level or coarser is a centroid, not a restaurant.
COARSE_TYPES = {"country", "state", "region", "county", "city", "province"}

BRACKET_NOTE = re.compile(r"\[[^\]]*\]")
STATUS_TAIL = re.compile(r"\bStatus:.*$", re.IGNORECASE | re.DOTALL)
DATE_TAIL = re.compile(
    r"\b\d{1,2}\s+(January|February|March|April|May|June|July|August|September"
    r"|October|November|December)\b.*$",
    re.IGNORECASE | re.DOTALL,
)

# Words that appear in half the names in the catalogue and carry no identity.
GENERIC = {
    "restoran",
    "restaurant",
    "restauran",
    "cafe",
    "kafe",
    "kedai",
    "warung",
    "warong",
    "gerai",
    "makan",
    "the",
    "sdn",
    "bhd",
    "enterprise",
    "trading",
    "food",
    "foods",
    "court",
    "stall",
    "by",
    "and",
    "dan",
    "at",
    "de",
}


def normalise(name: str) -> str:
    text = unicodedata.normalize("NFKD", name)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower().replace("&", " and ")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def core_tokens(name: str) -> str:
    """Normalised name with the filler words dropped, for fuzzy matching."""
    tokens = [t for t in normalise(name).split() if t not in GENERIC]
    return " ".join(tokens) if tokens else normalise(name)


def clean_address(address: str) -> str:
    address = BRACKET_NOTE.sub("", address)
    address = STATUS_TAIL.sub("", address)
    address = DATE_TAIL.sub("", address)
    return re.sub(r"\s+", " ", address).strip(" ,")


def fetch_rows(page_size: int = 1000) -> list[dict]:
    rows: list[dict] = []
    offset = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "select": "id,name,negeri,video_url",
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


def pull_overture(out_dir: pathlib.Path) -> None:
    import duckdb

    target = out_dir / "overture_my_places.parquet"
    connection = duckdb.connect()
    connection.execute("install httpfs; load httpfs; set s3_region='us-west-2';")
    connection.execute(
        f"""
        copy (
          select
            id,
            names.primary            as name,
            categories.primary       as category,
            addresses[1].freeform    as addr,
            addresses[1].locality    as locality,
            addresses[1].country     as country,
            confidence,
            (bbox.xmin + bbox.xmax) / 2 as lon,
            (bbox.ymin + bbox.ymax) / 2 as lat
          from read_parquet('{OVERTURE_GLOB}', hive_partitioning=1)
          where bbox.xmin between {MY_BBOX["west"]} and {MY_BBOX["east"]}
            and bbox.ymin between {MY_BBOX["south"]} and {MY_BBOX["north"]}
        ) to '{target}' (format parquet)
        """
    )
    count = connection.execute(f"select count(*) from '{target}'").fetchone()[0]
    print(f"{count} places -> {target}", file=sys.stderr)


def choose(candidates: list[dict]) -> tuple[dict | None, str]:
    """Pick one place for a target, or refuse when the choice is a coin flip.

    Chains are the problem case: a video about one Sushi King outlet matches
    every outlet in the state equally well. When the caption address breaks the
    tie we take the winner; when it does not and the candidates are spread over
    more than ~2km, no fix is better than a confidently wrong one -- the same
    call we make when rejecting Nominatim's city centroids.
    """
    if not candidates:
        return None, "none"
    ranked = sorted(
        candidates,
        key=lambda c: (
            c["overlap"],
            c["is_food"],
            c["confidence"] if c["confidence"] is not None else -1,
        ),
        reverse=True,
    )
    best = ranked[0]
    if len(ranked) > 1 and best["overlap"] == 0:
        spread = max(
            max(c["lat"] for c in ranked) - min(c["lat"] for c in ranked),
            max(c["lon"] for c in ranked) - min(c["lon"] for c in ranked),
        )
        if spread > 0.02:
            return None, "ambiguous"
    return best, "ok"


def match_overture(
    rows: list[dict],
    out_dir: pathlib.Path,
    bboxes: dict,
    threshold: float,
    addresses: dict,
) -> tuple[dict[str, dict], set[str]]:
    """Exact-then-fuzzy name match inside the row's state, offline."""
    import duckdb

    places = out_dir / "overture_my_places.parquet"
    if not places.exists():
        sys.exit(f"{places} missing -- run the pull-overture subcommand first")

    connection = duckdb.connect()
    connection.execute(
        """
        create table targets (
          video_url text, name text, negeri text, norm text, core text,
          hint text, west double, east double, south double, north double
        )
        """
    )
    payload = []
    for row in rows:
        box = bboxes.get(row.get("negeri") or "")
        if not box:
            continue
        hint = (addresses.get(row["video_url"]) or {}).get("address") or ""
        payload.append(
            (
                row["video_url"],
                row["name"],
                row["negeri"],
                normalise(row["name"]),
                core_tokens(row["name"]),
                normalise(clean_address(hint)) if hint else "",
                box["west"],
                box["east"],
                box["south"],
                box["north"],
            )
        )
    connection.executemany(
        "insert into targets values (?,?,?,?,?,?,?,?,?,?)", payload
    )
    print(f"{len(payload)} rows in a known state", file=sys.stderr)

    # The pull box reaches into Singapore, Indonesia, Thailand and Brunei, and
    # so do the state boxes: Johor's southern edge covers Singapore (132798
    # places), Sabah's and Sarawak's cover Kalimantan. Overture stamps a
    # country on all but 8 places in the box, so filtering on it is both cheap
    # and complete -- without it, "Ichigo by Tea Cottage" matches a Singapore
    # outlet 25km across the strait.
    connection.execute(
        f"""
        create table places as
        select
          name, category, addr, locality, country, confidence, lat, lon,
          lower(regexp_replace(strip_accents(name), '[^a-zA-Z0-9]+', ' ', 'g')) as norm_raw
        from '{places}'
        where name is not null and country = 'MY'
        """
    )
    # `core` strips the same filler words on the Overture side as core_tokens()
    # does on ours. Without it the two sides never line up: our "Ali Maju
    # Corner" (the caption drops "Restoran") cannot reach Overture's "Restoran
    # Ali Maju Corner", and "Warung Pak Su" cannot reach "Warong Pak Su".
    connection.execute(
        """
        create table normed as
        select *, trim(regexp_replace(norm_raw, '\\s+', ' ', 'g')) as norm
        from places
        """
    )
    connection.execute(
        """
        create table cleaned as
        select *,
               coalesce(
                 nullif(array_to_string(
                   list_filter(str_split(norm, ' '), x -> not list_contains(?::text[], x)),
                   ' '
                 ), ''),
                 norm
               ) as core,
               str_split(
                 trim(regexp_replace(
                   lower(regexp_replace(
                     strip_accents(coalesce(addr, '') || ' ' || coalesce(locality, '')),
                     '[^a-zA-Z0-9]+', ' ', 'g')),
                   '\\s+', ' ', 'g')),
                 ' '
               ) as ctx_tokens,
               (category is not null and (
                  category like '%restaurant%' or category like '%food%'
                  or category like '%cafe%' or category like '%coffee%'
                  or category like '%bakery%' or category like '%dessert%'
                  or category like '%bar%' or category like '%eat%'
                  or category like '%drink%' or category like '%tea%'
                  or category like '%juice%' or category like '%ice_cream%'
                  or category like '%steak%' or category like '%pizza%'
                  or category like '%noodle%' or category like '%seafood%'
                  or category like '%burger%' or category like '%dim_sum%'
                  or category like '%buffet%' or category like '%caterer%'
                  or category like '%deli%' or category like '%snack%'
               )) as is_food
        from normed
        """,
        [sorted(GENERIC)],
    )

    # Every candidate is scored the same way: how many words of the caption
    # address the place's own address and locality repeat. That is what tells
    # one outlet of a chain from another.
    overlap = "len(list_intersect(str_split(t.hint, ' '), p.ctx_tokens))"

    # Pass one: the names agree outright, either raw or with the filler words
    # dropped from both sides.
    exact_rows = connection.execute(
        f"""
        select t.video_url, p.name, p.lat, p.lon, p.category, p.confidence,
               p.is_food, {overlap} as overlap,
               case when p.norm = t.norm then 'name' else 'core' end as kind
        from targets t
        join cleaned p
          on (p.norm = t.norm
              or (p.core = t.core and p.is_food and len(str_split(t.core, ' ')) >= 2))
         and p.lon between t.west and t.east
         and p.lat between t.south and t.north
        """
    ).fetchall()

    # Pass two, for whatever pass one left. Plain string similarity is not safe
    # enough on its own: at 0.93 Jaro-Winkler it happily pairs "Burger Bae"
    # with "Burger Barn" and "Cendol Kamal" with "Cendol Maklom", which are
    # different stalls in the same town. So a match must clear all four of:
    #   - one name's word set contains the other's (spelling variants and a
    #     trailing branch word are fine, a swapped word is not),
    #   - the same digits on both sides ("No.5" is not "No.71"),
    #   - a food category, which kills "Antipodean JB" -> a clothing store,
    #   - and the similarity floor, as a backstop.
    resolved_urls = {row[0] for row in exact_rows}
    connection.execute(
        "create table done as select unnest(?::text[]) as video_url",
        [list(resolved_urls) or [""]],
    )
    fuzzy_rows = connection.execute(
        f"""
        with t as (
          select *, str_split(core, ' ') as core_tokens,
                 regexp_extract_all(core, '[0-9]+') as core_digits
          from targets
          where video_url not in (select video_url from done)
            and len(str_split(core, ' ')) >= 2
        )
        select t.video_url, p.name, p.lat, p.lon, p.category, p.confidence,
               p.is_food, {overlap} as overlap,
               'fuzzy ' || round(jaro_winkler_similarity(t.core, p.core), 3) as kind
        from t
        join cleaned p
          on p.lon between t.west and t.east
         and p.lat between t.south and t.north
         and split_part(p.core, ' ', 1) = t.core_tokens[1]
        where p.is_food
          and (list_has_all(str_split(p.core, ' '), t.core_tokens)
               or list_has_all(t.core_tokens, str_split(p.core, ' ')))
          and regexp_extract_all(p.core, '[0-9]+') = t.core_digits
          and jaro_winkler_similarity(t.core, p.core) >= {threshold}
        """
    ).fetchall()

    matched: dict[str, dict] = {}
    ambiguous: set[str] = set()
    for label, batch in (("exact", exact_rows), ("fuzzy", fuzzy_rows)):
        grouped: dict[str, list[dict]] = {}
        for (
            video_url,
            name,
            lat,
            lon,
            category,
            confidence,
            is_food,
            hint_overlap,
            kind,
        ) in batch:
            grouped.setdefault(video_url, []).append(
                {
                    "name": name,
                    "lat": lat,
                    "lon": lon,
                    "category": category,
                    "confidence": confidence,
                    "is_food": is_food,
                    "overlap": hint_overlap,
                    "kind": kind,
                }
            )
        added = 0
        for video_url, candidates in grouped.items():
            best, verdict = choose(candidates)
            if verdict == "ambiguous":
                ambiguous.add(video_url)
                continue
            if not best:
                continue
            matched[video_url] = {
                "latitude": best["lat"],
                "longitude": best["lon"],
                "source": f"overture-{label}",
                "matched_name": best["name"],
                "detail": " ".join(
                    part
                    for part in [
                        best["kind"],
                        best["category"] or "",
                        f"addr{best['overlap']}",
                    ]
                    if part
                ),
            }
            added += 1
        print(
            f"overture {label}: +{added} ({len(grouped) - added} ambiguous)",
            file=sys.stderr,
        )
    ambiguous -= set(matched)
    return matched, ambiguous


def nominatim_lookup(query: str) -> dict | None:
    url = NOMINATIM + "?" + urllib.parse.urlencode(
        {
            "q": query,
            "format": "json",
            "limit": 1,
            "countrycodes": "my",
            "addressdetails": 0,
        }
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            payload = json.load(response)
    except Exception as error:
        print(f"  nominatim error: {error}", file=sys.stderr)
        return None
    return payload[0] if payload else None


def match_nominatim(
    rows: list[dict],
    addresses: dict,
    cache_path: pathlib.Path,
    bboxes: dict,
    limit: int | None,
) -> dict[str, dict]:
    cache: dict[str, dict] = {}
    if cache_path.exists():
        with cache_path.open(encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    record = json.loads(line)
                    cache[record["video_url"]] = record

    matched: dict[str, dict] = {}
    todo = [row for row in rows if row["video_url"] not in cache]
    if limit:
        todo = todo[:limit]
    print(f"nominatim: {len(cache)} cached, {len(todo)} to look up", file=sys.stderr)

    with cache_path.open("a", encoding="utf-8") as handle:
        for index, row in enumerate(todo, 1):
            hint = (addresses.get(row["video_url"]) or {}).get("address")
            queries = []
            if hint:
                parts = [
                    part.strip()
                    for part in clean_address(hint).split(",")
                    if part.strip()
                ]
                # Progressively drop leading components: the caption leads with
                # the business name, which Nominatim cannot resolve, but the
                # tail is a real street/suburb.
                for start in range(len(parts)):
                    queries.append(", ".join(parts[start:]) + ", Malaysia")
            # Cap the address suffixes so the name fallback always gets a turn:
            # a long caption address would otherwise eat the whole budget.
            queries = queries[:3]
            if row.get("negeri"):
                queries.append(f"{row['name']}, {row['negeri']}, Malaysia")

            found = None
            for query in queries:
                hit = nominatim_lookup(query)
                time.sleep(1.1)
                if not hit:
                    continue
                if (hit.get("addresstype") or hit.get("type")) in COARSE_TYPES:
                    continue
                box = bboxes.get(row.get("negeri") or "")
                lat, lon = float(hit["lat"]), float(hit["lon"])
                if box and not (
                    box["west"] <= lon <= box["east"]
                    and box["south"] <= lat <= box["north"]
                ):
                    continue
                found = {
                    "latitude": lat,
                    "longitude": lon,
                    "source": "nominatim",
                    "matched_name": hit.get("display_name", "")[:80],
                    "detail": hit.get("addresstype") or hit.get("type") or "",
                    "query": query,
                }
                break

            record = {"video_url": row["video_url"], "result": found}
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
            handle.flush()
            cache[row["video_url"]] = record
            if index % 25 == 0:
                print(f"  {index}/{len(todo)}", file=sys.stderr)

    for video_url, record in cache.items():
        if record.get("result"):
            matched[video_url] = record["result"]
    return matched


def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def render_statements(
    matched: dict[str, dict], out_dir: pathlib.Path, chunk: int
) -> int:
    items = sorted(matched.items())
    written = 0
    for index in range(0, len(items), chunk):
        batch = items[index : index + chunk]
        values = ",\n    ".join(
            "({}, {}, {})".format(
                quote(video_url),
                repr(float(hit["latitude"])),
                repr(float(hit["longitude"])),
            )
            for video_url, hit in batch
        )
        written += 1
        statement = (
            "update public.restaurants as r\n"
            "set latitude = v.latitude, longitude = v.longitude\n"
            "from (values\n"
            f"    {values}\n"
            ") as v(video_url, latitude, longitude)\n"
            "where r.video_url = v.video_url;\n"
        )
        (out_dir / f"stmt_geo_{written:02d}.sql").write_text(
            statement, encoding="utf-8"
        )
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["pull-overture", "match"])
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--addresses", help="url -> {address} map from the candidates")
    parser.add_argument("--state-bbox", help="negeri -> bbox json")
    parser.add_argument("--threshold", type=float, default=0.93)
    parser.add_argument("--chunk", type=int, default=100)
    parser.add_argument("--skip-nominatim", action="store_true")
    parser.add_argument("--nominatim-limit", type=int)
    args = parser.parse_args()

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.command == "pull-overture":
        pull_overture(out_dir)
        return

    bbox_path = pathlib.Path(args.state_bbox or out_dir / "state_bbox.json")
    bboxes = json.loads(bbox_path.read_text(encoding="utf-8"))
    addresses = (
        json.loads(pathlib.Path(args.addresses).read_text(encoding="utf-8"))
        if args.addresses
        else {}
    )

    rows = fetch_rows()
    print(f"{len(rows)} rows without a fix", file=sys.stderr)

    matched, ambiguous = match_overture(
        rows, out_dir, bboxes, args.threshold, addresses
    )
    if not args.skip_nominatim:
        remaining = [row for row in rows if row["video_url"] not in matched]
        matched.update(
            match_nominatim(
                remaining,
                addresses,
                out_dir / "nominatim_cache.jsonl",
                bboxes,
                args.nominatim_limit,
            )
        )

    report = out_dir / "geocode_report.tsv"
    with report.open("w", encoding="utf-8") as handle:
        handle.write("video_url\tname\tnegeri\tsource\tlat\tlon\tmatched\tdetail\n")
        for row in rows:
            hit = matched.get(row["video_url"])
            handle.write(
                "\t".join(
                    [
                        row["video_url"],
                        row["name"],
                        row.get("negeri") or "",
                        hit["source"]
                        if hit
                        else ("ambiguous" if row["video_url"] in ambiguous else "none"),
                        f"{hit['latitude']:.6f}" if hit else "",
                        f"{hit['longitude']:.6f}" if hit else "",
                        hit["matched_name"] if hit else "",
                        hit["detail"] if hit else "",
                    ]
                )
                + "\n"
            )

    files = render_statements(matched, out_dir, args.chunk)
    print(
        f"resolved {len(matched)}/{len(rows)} -> {files} statement file(s), "
        f"report at {report}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
