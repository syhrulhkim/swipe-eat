#!/usr/bin/env python3
"""Turn reviewed candidates into INSERT statements for `public.restaurants`.

`extract_restaurants.py` produces candidates with a guessed name; a review pass
(a person, or a model reading the captions) decides which ones are really
restaurants and what they are called. This joins the two and writes SQL.

The review file is JSONL, one object per kept candidate, keyed by the
candidate's index in the candidates file:

    {"i": 1, "n": "Kerala B&B Restaurant", "t": "Indian"}
    {"i": 2, "n": "SOLENE", "t": "Fine Dining", "g": "Johor"}

`n` is the name, `t` the category badge, `g` an optional state and `gn` an
optional country, both overriding what the extractor read from the caption —
Malaysian street names carry state names ("Terengganu Road" in George Town), so
the caption's own guess is wrong often enough to be worth correcting by hand. A
candidate with no line is dropped — that is how advertisements, listicles and
mall events leave the pipeline.

Coordinates are written as 0/0 because a caption gives an address, not a fix;
the app already treats 0/0 as "no map fix" and hides directions for it, and
geocoding is a separate pass.

Usage:
    python3 scripts/restaurants_to_sql.py candidates.json keep.jsonl --out rows.sql
"""

import argparse
import json

# Every insert is guarded twice: `restaurants_name_key` and the partial unique
# index on video_url. A rerun of the same batch inserts nothing.
STATEMENT = """insert into public.restaurants
  (name, tag, details, rating, latitude, longitude, video_url, negara, negeri)
values
{values}
on conflict do nothing;"""


def quote(value):
    if value is None:
        return "null"
    return "'" + str(value).replace("'", "''") + "'"


def row_sql(candidate, review):
    # The card shows `details` under the name, so it wants the creator's line
    # about the place — not the address, and not the hashtag tail.
    details = candidate.get("headline") or candidate["caption"]
    if len(details) > 200:
        details = details[:197].rstrip() + "..."
    return "  ({})".format(
        ", ".join(
            [
                quote(review["n"]),
                quote(review["t"]),
                quote(details),
                "0",
                "0",
                "0",
                quote(candidate["video_url"]),
                quote(review.get("gn") or candidate.get("negara") or "Malaysia"),
                quote(review.get("g") or candidate.get("negeri")),
            ]
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidates", help="candidates.json from extract_restaurants.py")
    parser.add_argument("review", help="JSONL of kept candidates")
    parser.add_argument("--out", default="rows.sql")
    parser.add_argument(
        "--batch",
        type=int,
        default=100,
        help="rows per INSERT statement",
    )
    args = parser.parse_args()

    candidates = json.load(open(args.candidates))
    with open(args.review) as handle:
        reviews = [json.loads(line) for line in handle if line.strip()]

    # Two kept candidates can carry the same name — a chain, or the same stall
    # filmed twice. The name is unique in the database, so the first one wins
    # here rather than losing the whole statement to a conflict.
    seen_names = set()
    rows = []
    duplicates = 0
    for review in reviews:
        name = review["n"].strip()
        key = name.casefold()
        if key in seen_names:
            duplicates += 1
            continue
        seen_names.add(key)
        rows.append(row_sql(candidates[review["i"]], {**review, "n": name}))

    statements = []
    for start in range(0, len(rows), args.batch):
        statements.append(
            STATEMENT.format(values=",\n".join(rows[start : start + args.batch]))
        )

    with open(args.out, "w") as handle:
        handle.write("\n\n".join(statements) + "\n")

    print(f"{len(rows)} rows, {duplicates} duplicate names dropped")
    print(f"wrote {args.out} ({len(statements)} statements)")


if __name__ == "__main__":
    main()
