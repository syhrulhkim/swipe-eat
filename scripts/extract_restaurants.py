#!/usr/bin/env python3
"""Turn scraped TikTok captions into restaurant rows.

`scrape_tiktok.py` fetches a creator's videos; this reads that JSON and pulls a
restaurant out of each caption. Food creators write to a house format —

    Matcha Mochi Brioche in JB 😍 ... Little Bun Cafe
    📍 G-08, Eco Nest Apartment, Jalan Eko Botanic 3/5, 79100, Johor
    ⏰ 9:30am - 9:30pm (Daily)

— so the pin emoji anchors the address, the clock ends it, and a Malaysian
postcode inside it names the state. That much is deterministic and lives here.

The restaurant's *name* is not: creators put it before the pin, after the pin,
or nowhere at all. So every candidate carries a `confidence` and the caption it
came from, and the uncertain ones are meant to be read by a human (or a model)
before anything is written to the database. This script never writes to
Supabase — it only ever produces a file.

Usage:
    python3 scripts/scrape_tiktok.py johorfoodie --jsonl videos.json
    python3 scripts/extract_restaurants.py videos.json --out candidates.json

    # skip clips already in the catalogue
    python3 scripts/extract_restaurants.py videos.json \
        --known-video-urls known.json --out candidates.json
"""

import argparse
import json
import re
import sys
from collections import Counter

PIN = "\U0001f4cd"  # 📍 — the address marker in every caption that has one.

# The caption ends its address at whichever of these comes first. A clock is the
# usual one (opening hours); the rest show up when a creator lists prices, a
# phone number or a promo after the address.
ADDRESS_TERMINATORS = [
    "⏰",  # ⏰
    "\U0001f552",  # 🕒
    "\U0001f4de",  # 📞
    "\U0001f4b0",  # 💰
    "\U0001f4b5",  # 💵
    "\U0001f9fe",  # 🧾
    "\U0001f17f",  # 🅿
    "\U0001f6d2",  # 🛒
    "#",
]

# Malaysian postcodes are five digits and the number itself names the state.
# Ranges from Pos Malaysia's assignment; the odd single-postcode entries
# (Fraser's Hill, Genting) are hill stations that sit inside another state's
# block but post as Pahang.
POSTCODE_RANGES = [
    (1000, 2999, "Perlis"),
    (5000, 9810, "Kedah"),
    (10000, 14400, "Pulau Pinang"),
    (15000, 18500, "Kelantan"),
    (20000, 24300, "Terengganu"),
    (25000, 28800, "Pahang"),
    (30000, 36810, "Perak"),
    (39000, 39200, "Pahang"),
    (40000, 48300, "Selangor"),
    (49000, 49000, "Pahang"),
    (50000, 60999, "Kuala Lumpur"),
    (62000, 62988, "Putrajaya"),
    (63000, 68100, "Selangor"),
    (69000, 69000, "Pahang"),
    (70000, 73509, "Negeri Sembilan"),
    (75000, 78309, "Melaka"),
    (79000, 86900, "Johor"),
    (87000, 87033, "Labuan"),
    (88000, 91309, "Sabah"),
    (93000, 98859, "Sarawak"),
]

# State names as a creator might type them, including the honorifics they carry
# in full postal addresses ("Johor Darul Ta'zim").
STATE_ALIASES = {
    "johor": "Johor",
    "johore": "Johor",
    "johor darul takzim": "Johor",
    "johor darul ta'zim": "Johor",
    "selangor": "Selangor",
    "selangor darul ehsan": "Selangor",
    "kuala lumpur": "Kuala Lumpur",
    "wilayah persekutuan": "Kuala Lumpur",
    "putrajaya": "Putrajaya",
    "labuan": "Labuan",
    "penang": "Pulau Pinang",
    "pulau pinang": "Pulau Pinang",
    "kedah": "Kedah",
    "kedah darul aman": "Kedah",
    "perlis": "Perlis",
    "perak": "Perak",
    "perak darul ridzuan": "Perak",
    "kelantan": "Kelantan",
    "terengganu": "Terengganu",
    "pahang": "Pahang",
    "negeri sembilan": "Negeri Sembilan",
    "melaka": "Melaka",
    "malacca": "Melaka",
    "sabah": "Sabah",
    "sarawak": "Sarawak",
}

# Towns, suburbs and malls that pin a caption to a state on their own. Needed
# because plenty of captions give a landmark and no postcode at all ("📍 Star
# Fish Leisure Farm"). Johor is dense here because the seed creator covers it;
# the rest of the country is one entry per major city so a future creator from
# another state still resolves.
CITY_STATES = {
    "Johor": [
        "johor bahru", "johor baru", "jb", "iskandar puteri", "nusajaya",
        "gelang patah", "puteri harbour", "skudai", "senai", "kulai",
        "kulaijaya", "pasir gudang", "masai", "ulu tiram", "tebrau",
        "permas jaya", "southkey", "mount austin", "setia tropika",
        "bukit indah", "taman molek", "larkin", "stulang", "danga bay",
        "batu pahat", "parit raja", "sri gading", "rengit", "yong peng",
        "ayer hitam", "air hitam", "simpang renggam", "kluang", "muar",
        "tangkak", "ledang", "segamat", "labis", "bekok", "pontian",
        "benut", "kukup", "pekan nanas", "kota tinggi", "bandar penawar",
        "desaru", "pengerang", "mersing", "endau", "paradigm mall",
        "sunway big box", "mid valley southkey", "aeon tebrau",
        "toppen", "ikea tebrau", "angsana",
    ],
    "Kuala Lumpur": [
        "kuala lumpur", "bukit bintang", "cheras", "kepong", "setapak",
        "wangsa maju", "mont kiara", "bangsar", "sri petaling", "titiwangsa",
        "klcc", "damansara heights", "sentul", "brickfields",
    ],
    "Selangor": [
        "petaling jaya", "shah alam", "subang jaya", "puchong", "klang",
        "ampang", "kajang", "bangi", "cyberjaya", "rawang", "sepang",
        "seri kembangan", "damansara utama", "ss15", "ara damansara",
        "setia alam", "kota damansara", "sunway pyramid",
    ],
    "Pulau Pinang": [
        "george town", "georgetown", "penang", "bayan lepas", "butterworth",
        "balik pulau", "tanjung bungah", "gurney", "seberang perai",
    ],
    "Perak": ["ipoh", "taiping", "teluk intan", "sitiawan", "lumut", "kampar"],
    "Melaka": ["melaka", "malacca", "jonker", "ayer keroh", "alor gajah"],
    "Negeri Sembilan": ["seremban", "port dickson", "nilai", "bahau"],
    "Pahang": [
        "kuantan", "cameron highlands", "genting highlands", "bentong",
        "temerloh", "raub", "pekan", "cherating",
    ],
    "Terengganu": ["kuala terengganu", "dungun", "kemaman", "marang"],
    "Kelantan": ["kota bharu", "pasir mas", "tumpat"],
    "Kedah": ["alor setar", "sungai petani", "langkawi", "kulim", "jitra"],
    "Perlis": ["kangar", "arau", "padang besar"],
    "Sabah": ["kota kinabalu", "sandakan", "tawau", "lahad datu", "semporna"],
    "Sarawak": ["kuching", "miri", "sibu", "bintulu", "samarahan"],
    "Putrajaya": ["putrajaya"],
    "Labuan": ["labuan"],
}

# A caption that is really an advertisement still carries a pin and an address.
# These are the giveaways that the pin belongs to a shop, an expo or a phone
# plan rather than a place to eat.
NON_FOOD_MARKERS = [
    "exhibition", "expo", "roadshow", "furniture", "mattress", "renovation",
    "interior design", "smart home", "gadget", "accessories", "phone plan",
    "insurance", "takaful", "loan", "mortgage", "property launch",
    "showroom", "car service", "workshop rims", "tyre", "skincare",
    "hair salon", "barber", "gym membership", "clinic", "dental",
    "optical", "spectacles", "laundry", "car wash", "hotel booking",
    "travel package", "flight ticket", "university", "college",
    "tuition", "scholarship", "job vacancy", "kerja kosong",
]

# Words that mean the caption is about eating, used only to rescue a caption
# that tripped a non-food marker in passing ("the mall's newest cafe").
FOOD_MARKERS = [
    "food", "makan", "eat", "restaurant", "restoran", "cafe", "kafe",
    "kopitiam", "warung", "stall", "gerai", "menu", "dish", "dishes",
    "breakfast", "brunch", "lunch", "dinner", "supper", "sarapan",
    "dessert", "coffee", "kopi", "tea", "drink", "buffet", "steamboat",
    "bbq", "grill", "noodle", "mee", "rice", "nasi", "roti", "chicken",
    "ayam", "beef", "daging", "seafood", "ikan", "sushi", "ramen",
    "burger", "pizza", "cake", "bakery", "bread", "ice cream", "sedap",
    "delicious", "tasty", "halal", "vegetarian", "spicy", "pedas",
]

# Leading hype a caption puts before the actual name. Stripped so "NEW Best
# Cafe in JB — Kopi Ali" does not become the restaurant's name.
HYPE_PREFIXES = re.compile(
    r"^(?:new|newly opened|newest|viral|trending|must try|must-try|best|"
    r"hidden gem|underrated|famous|legendary|the best|top|first|finally|"
    r"open now|now open|baru|terbaru|wajib|paling)\b[\s:,\-–—!]*",
    re.IGNORECASE,
)

EMOJI = re.compile(
    "[\U0001f300-\U0001faff☀-➿️‍←-⇿⬀-⯿]"
)
HASHTAG = re.compile(r"#\S+")
WHITESPACE = re.compile(r"\s+")
POSTCODE = re.compile(r"\b(\d{5})\b")
SINGAPORE_POSTCODE = re.compile(r"\bS?\(?\d{6}\)?\b")

# A name is a short line of words, not an address. These are what an address
# fragment looks like when the split guesses wrong.
ADDRESS_TOKENS = re.compile(
    r"\b(jalan|jln|lorong|lrg|persiaran|lebuh|lebuhraya|taman|tmn|bandar|"
    r"kampung|kg|no\.?|lot|blok|block|tingkat|level|floor|unit|plaza|"
    r"seksyen|batu)\b",
    re.IGNORECASE,
)


def clean(text):
    """Strip emoji, hashtags and runs of whitespace for a display string."""
    text = HASHTAG.sub(" ", text)
    text = EMOJI.sub(" ", text)
    return WHITESPACE.sub(" ", text).strip(" ,-–—:;|")


def split_caption(description):
    """Split a caption into (before pin, address block, rest).

    Returns (None, None, None) when the caption has no pin, which is this
    script's definition of "not a place".
    """
    if PIN not in description:
        return None, None, None

    before, _, after = description.partition(PIN)
    cut = len(after)
    for terminator in ADDRESS_TERMINATORS:
        index = after.find(terminator)
        if index != -1:
            cut = min(cut, index)
    return before, after[:cut], after[cut:]


def state_from_postcode(text):
    for match in POSTCODE.finditer(text):
        code = int(match.group(1))
        for low, high, state in POSTCODE_RANGES:
            if low <= code <= high:
                return state
    return None


def state_from_words(text):
    lowered = text.lower()
    for alias, state in STATE_ALIASES.items():
        if re.search(rf"\b{re.escape(alias)}\b", lowered):
            return state
    for state, cities in CITY_STATES.items():
        for city in cities:
            if re.search(rf"\b{re.escape(city)}\b", lowered):
                return state
    return None


def locate(address, whole_caption, default_negeri=None):
    """Best (negara, negeri) for a caption, address first then the whole text.

    A state read out of a postcode is the only reading that cannot be wrong. A
    state read out of words can be: "Penang Rojak" is a dish sold in Johor, and
    "Langkawi's famous ice cream" is a shop in Johor Bahru. `default_negeri` is
    the creator's home state, used only when the caption says nothing at all,
    and it is worth setting for a creator who covers one state.
    """
    if re.search(r"\bsingapore\b", whole_caption, re.IGNORECASE) or (
        SINGAPORE_POSTCODE.search(address) and not POSTCODE.search(address)
    ):
        return "Singapore", None

    for text in (address, whole_caption):
        state = state_from_postcode(text) or state_from_words(text)
        if state:
            return "Malaysia", state
    return "Malaysia", default_negeri


def looks_like_name(text):
    """A name is short, wordy and not an address fragment."""
    if not text:
        return False
    words = text.split()
    if not 1 <= len(words) <= 7:
        return False
    if ADDRESS_TOKENS.search(text):
        return False
    if POSTCODE.search(text):
        return False
    return sum(character.isdigit() for character in text) <= 2


def guess_name(before, address):
    """Guess the restaurant's name and say how sure the guess is.

    Two houses styles, in the order they are tried:
      1. the name opens the address block  — "📍 Kopi Ali, 12 Jalan ..."
      2. the name closes the hype line     — "Best kaya toast, Kopi Ali 📍 12 ..."
    """
    head = clean(address.split(",")[0])
    head = HYPE_PREFIXES.sub("", head)
    if looks_like_name(head):
        return head, "high"

    tail = clean(before)
    if tail:
        # The last sentence-ish chunk of the hype line is where the name sits.
        chunk = re.split(r"[.!?•\|\n]", tail)[-1].strip()
        chunk = HYPE_PREFIXES.sub("", chunk)
        if looks_like_name(chunk):
            return chunk, "medium"

    # Nothing convincing: hand back the least-bad string and flag it.
    fallback = head or clean(before)[:60]
    return fallback or None, "low"


def is_food(description):
    lowered = description.lower()
    if any(marker in lowered for marker in NON_FOOD_MARKERS):
        # Rescue only if the caption is clearly still about eating.
        return sum(marker in lowered for marker in FOOD_MARKERS) >= 3
    return True


def extract(entry, default_negeri=None):
    """One video in, one candidate (or a rejection reason) out."""
    description = entry.get("description") or entry.get("title") or ""
    before, address, _ = split_caption(description)
    if address is None:
        return None, "no-pin"
    if not is_food(description):
        return None, "not-food"

    name, confidence = guess_name(before, address)
    if not name:
        return None, "no-name"

    negara, negeri = locate(address, description, default_negeri=default_negeri)
    if negeri is None and negara == "Malaysia":
        confidence = "low"

    return {
        "name": name,
        # What the creator says about the place, before the address begins. This
        # is the line worth showing on a card; the address that follows it is
        # not, and the hashtag tail even less so.
        "headline": clean(before) or clean(address),
        "address": clean(address),
        "negara": negara,
        "negeri": negeri,
        "confidence": confidence,
        "video_url": entry.get("webpage_url") or entry.get("url"),
        "tiktok_id": entry.get("id"),
        "uploader": entry.get("uploader"),
        "view_count": entry.get("view_count"),
        "caption": WHITESPACE.sub(" ", description).strip(),
    }, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="JSON or JSONL of scraped videos")
    parser.add_argument("--out", default="candidates.json")
    parser.add_argument(
        "--default-negeri",
        default=None,
        help="state to assume when a caption names none, e.g. Johor for @johorfoodie",
    )
    parser.add_argument(
        "--known-video-urls",
        default=None,
        help="JSON array of video URLs already in the catalogue; they are skipped",
    )
    args = parser.parse_args()

    with open(args.source) as handle:
        text = handle.read().strip()
    entries = (
        json.loads(text)
        if text.startswith("[")
        else [json.loads(line) for line in text.splitlines() if line.strip()]
    )

    known = set()
    if args.known_video_urls:
        with open(args.known_video_urls) as handle:
            known = set(json.load(handle))

    candidates = []
    reasons = Counter()
    seen_urls = set()
    for entry in entries:
        url = entry.get("webpage_url") or entry.get("url")
        if url in known:
            reasons["already-in-catalogue"] += 1
            continue
        if url in seen_urls:
            reasons["duplicate-clip"] += 1
            continue
        seen_urls.add(url)

        candidate, reason = extract(entry, default_negeri=args.default_negeri)
        if candidate is None:
            reasons[reason] += 1
            continue
        candidates.append(candidate)

    with open(args.out, "w") as handle:
        json.dump(candidates, handle, indent=2, ensure_ascii=False)

    by_confidence = Counter(candidate["confidence"] for candidate in candidates)
    print(f"read {len(entries)} videos", file=sys.stderr)
    for reason, count in reasons.most_common():
        print(f"  skipped {count}: {reason}", file=sys.stderr)
    print(f"  candidates {len(candidates)}: {dict(by_confidence)}", file=sys.stderr)
    print(f"wrote {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
