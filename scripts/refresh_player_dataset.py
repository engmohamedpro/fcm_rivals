#!/usr/bin/env python3
"""FCM Rivals — player dataset refresh pipeline (players_v1.json, format v3).

Rebuilds `assets/data/players_v1.json` from the open Transfermarkt-derived
player-scores dataset (originally by dcaribou, mirrored on HuggingFace at
`ngeorgea/transfermarkt-player-scores`). Run it any time to refresh the app
with the latest upstream snapshot:

    python3 scripts/refresh_player_dataset.py                 # full refresh
    python3 scripts/refresh_player_dataset.py --data-dir DIR  # pre-downloaded CSVs
    python3 scripts/refresh_player_dataset.py --keep-current-set
                                        # keep today's player roster, only
                                        # re-emit rows (used when only the
                                        # extra v3 fields were introduced)

Inputs (downloaded automatically unless --data-dir is given):
    players.csv, clubs.csv, competitions.csv, transfers.csv

Output row format (v3), fields 0..4 byte-compatible with v2:
    [playerId, name, position, nationality, marketValueEur, clubId, imageUrl]

Top-level maps (new in v3, ignored by the v2-era Dart parser):
    "leagues": {code: [displayName, logoUrl]}
    "clubs":   {clubId: [name, wappenUrl, leagueCode]}

Transfermarkt CDN URL patterns (verified 2026-11-11; the ?lm= cache buster
is optional and omitted):
    player portrait : https://img.a.transfermarkt.technology/portrait/header/{id}-{ts}.png|.jpg
    club crest      : https://img.a.transfermarkt.technology/wappen/head/{clubId}.png
    league logo     : https://img.a.transfermarkt.technology/logo/header/{code-lowercase}.png
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

HF_BASE = (
    "https://huggingface.co/datasets/ngeorgea/transfermarkt-player-scores"
    "/resolve/main"
)
CSV_FILES = ("players.csv", "clubs.csv", "competitions.csv", "transfers.csv")

TM_CDN = "https://img.a.transfermarkt.technology"
TM_CLUB_LOGO = TM_CDN + "/wappen/head/{}.png"
TM_LEAGUE_LOGO = TM_CDN + "/logo/header/{}.png"

FREE_AGENT_CLUB_ID = 515
FREE_AGENT_NAME = "Free Agent"

# sub_position -> the 12 GDD position codes (reverse-engineered from the
# original generation; "Second Striker" folds into CAM).
POSITION_MAP = {
    "Centre-Forward": "ST",
    "Left Winger": "LW",
    "Right Winger": "RW",
    "Attacking Midfield": "CAM",
    "Second Striker": "CAM",
    "Left Midfield": "LM",
    "Right Midfield": "RM",
    "Central Midfield": "CM",
    "Defensive Midfield": "CDM",
    "Centre-Back": "CB",
    "Right-Back": "RB",
    "Left-Back": "LB",
    "Goalkeeper": "GK",
}

# Upstream nationality spelling normalised by the original generator.
NATIONALITY_OVERRIDES = {"Korea, South": "South Korea"}

# League display names. Codes are Transfermarkt competition ids; names follow
# Transfermarkt's own competition titles for the well-known leagues (the
# competitions.csv `name` column is only a URL slug). Codes absent here fall
# back to the prettified slug; COL1 is not tracked by the dataset at all.
LEAGUE_DISPLAY_NAMES = {
    "GB1": "Premier League",
    "ES1": "LaLiga",
    "IT1": "Serie A",
    "L1": "Bundesliga",
    "FR1": "Ligue 1",
    "PO1": "Liga Portugal",
    "NL1": "Eredivisie",
    "BE1": "Jupiler Pro League",
    "TR1": "Süper Lig",
    "RU1": "Russian Premier Liga",
    "UKR1": "Ukrainian Premier Liga",
    "BRA1": "Brasileirão Série A",
    "ARG1": "Liga Profesional de Fútbol",
    "MLS1": "Major League Soccer",
    "MEX1": "Liga MX",
    "JAP1": "J1 League",
    "SA1": "Saudi Pro League",
    "AUS1": "A-League",
    "GR1": "Super League Greece",
    "C1": "Swiss Super League",
    "A1": "Austrian Bundesliga",
    "PL1": "Ekstraklasa",
    "RO1": "Superliga Romania",
    "SER1": "Serbian SuperLiga",
    "KR1": "HNL",
    "RSK1": "K League 1",
    "TS1": "Chance Liga",
    "SC1": "Scottish Premiership",
    "DK1": "Superliga",
    "SE1": "Allsvenskan",
    "NO1": "Eliteserien",
    "COL1": "Categoría Primera A",
}

# Clubs missing from every dataset table (verified via their Wikidata
# Transfermarkt-team-ID sitelinks, 2026-11-11).
CLUB_NAME_OVERRIDES = {
    10747: "SP Tre Penne",
    69032: "Bahla Club",
    116570: "Thitsar Arman FC",
}

MIN_LAST_SEASON = 2024


def log(msg: str) -> None:
    print(msg, flush=True)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def download_csvs(dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for name in CSV_FILES:
        target = dest / name
        if target.exists() and target.stat().st_size > 0:
            log(f"  cached: {name}")
            continue
        log(f"  downloading {name} ...")
        req = urllib.request.Request(f"{HF_BASE}/{name}", headers={"User-Agent": "fcm-rivals-refresh/1.0"})
        with urllib.request.urlopen(req, timeout=300) as resp, target.open("wb") as out:
            out.write(resp.read())


def prettify_slug(slug: str) -> str:
    words = [w.capitalize() for w in slug.split("-")]
    return " ".join(words)


def build(data_dir: Path, out_path: Path, keep_current_set: bool) -> int:
    players_csv = read_csv(data_dir / "players.csv")
    clubs_csv = {int(r["club_id"]): r for r in read_csv(data_dir / "clubs.csv")}
    comps_csv = {r["competition_id"]: r for r in read_csv(data_dir / "competitions.csv")}

    # Club-name candidates from transfer history (covers clubs the curated
    # tables never track, e.g. African/Asian leagues).
    transfer_names: dict[int, str] = {}
    for r in read_csv(data_dir / "transfers.csv"):
        if r["from_club_id"] and r["from_club_name"]:
            transfer_names.setdefault(int(r["from_club_id"]), r["from_club_name"].strip())
        if r["to_club_id"] and r["to_club_name"]:
            transfer_names.setdefault(int(r["to_club_id"]), r["to_club_name"].strip())

    keep_ids: set[int] | None = None
    if keep_current_set and out_path.exists():
        current = json.loads(out_path.read_text(encoding="utf-8"))
        keep_ids = {p[0] for p in current["players"]}
        log(f"keeping the current roster: {len(keep_ids)} players")
    elif keep_current_set:
        log("--keep-current-set given but no existing asset found; full refresh")

    rows = []
    club_info: dict[int, tuple[str, str]] = {}  # clubId -> (leagueCode, clubName)
    for r in players_csv:
        pid = int(r["player_id"])
        try:
            mv = int(r["market_value_in_eur"] or 0)
        except ValueError:
            mv = 0
        eligible = int(r["last_season"]) >= MIN_LAST_SEASON and mv > 0
        if keep_ids is not None:
            if pid not in keep_ids:
                continue
        elif not eligible:
            continue

        name = (r["name"] or r["last_name"] or r["first_name"]).strip()
        sub = r["sub_position"]
        if sub not in POSITION_MAP:
            raise SystemExit(f"unknown sub_position {sub!r} for player {pid}")
        position = POSITION_MAP[sub]
        nationality = NATIONALITY_OVERRIDES.get(
            r["country_of_citizenship"], r["country_of_citizenship"]
        ).strip()
        if not nationality:
            raise SystemExit(f"missing nationality for player {pid}")
        image_url = r["image_url"].split("?")[0].strip()
        # Transfermarkt serves a generic placeholder ("default.jpg") for
        # players without a real photo — store '' instead and let the app
        # render its own fallback.
        if image_url.rsplit("/", 1)[-1].split(".")[0].lower() == "default":
            image_url = ""

        club_id = int(r["current_club_id"]) if r["current_club_id"] else 0
        league_code = r["current_club_domestic_competition_id"].strip()
        if club_id and club_id not in club_info:
            if club_id == FREE_AGENT_CLUB_ID:
                club_name = FREE_AGENT_NAME
            else:
                club_name = (
                    clubs_csv.get(club_id, {}).get("name", "").strip()
                    or r["current_club_name"].strip()
                    or CLUB_NAME_OVERRIDES.get(club_id, "")
                    or transfer_names.get(club_id, "")
                )
            club_info[club_id] = (league_code, club_name)
        rows.append([pid, name, position, nationality, mv, club_id, image_url])

    if keep_ids is not None and len(rows) != len(keep_ids):
        missing = keep_ids - {r[0] for r in rows}
        raise SystemExit(
            f"upstream snapshot lost {len(missing)} current players "
            f"(e.g. {sorted(missing)[:5]}); refusing to shrink the roster — "
            "use a fresh full refresh instead"
        )

    # Original ordering: Market Value desc, then name asc.
    rows.sort(key=lambda r: (-r[4], r[1]))

    leagues: dict[str, list[str]] = {}
    for club_id, (league_code, club_name) in sorted(club_info.items()):
        if league_code and league_code not in leagues:
            display = LEAGUE_DISPLAY_NAMES.get(league_code)
            if display is None:
                slug = comps_csv.get(league_code, {}).get("name", league_code)
                display = prettify_slug(slug)
            leagues[league_code] = [display, TM_LEAGUE_LOGO.format(league_code.lower())]

    clubs = {}
    for club_id, (league_code, club_name) in sorted(club_info.items()):
        if club_id == FREE_AGENT_CLUB_ID:
            logo = ""  # free agents carry no crest
        elif club_id == 0:
            logo = ""
        else:
            logo = TM_CLUB_LOGO.format(club_id)
        clubs[str(club_id)] = [club_name, logo, league_code]

    players_payload = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
    digest = hashlib.sha256(players_payload.encode("utf-8")).hexdigest()[:16]

    asset = {
        "format": "fcm-rivals-players",
        "version": 3,
        "asOf": time.strftime("%Y-%m-%d"),
        "digest": digest,
        "leagues": leagues,
        "clubs": clubs,
        "players": rows,
    }
    text = json.dumps(asset, ensure_ascii=False, separators=(",", ":"))
    out_path.write_text(text, encoding="utf-8")

    with_image = sum(1 for r in rows if r[6])
    with_club = sum(1 for r in rows if r[5] and r[5] != FREE_AGENT_CLUB_ID)
    with_logo = sum(1 for r in rows if r[5] and clubs[str(r[5])][1])
    with_league = sum(1 for r in rows if r[5] and clubs[str(r[5])][2])
    log("")
    log(f"players : {len(rows)}")
    log(f"  with player image : {with_image}")
    log(f"  with club name    : {with_club}")
    log(f"  with club logo    : {with_logo}")
    log(f"  with league       : {with_league}")
    log(f"clubs   : {len(clubs)}")
    log(f"leagues : {len(leagues)}")
    unnamed = [c for c, v in clubs.items() if not v[0]]
    if unnamed:
        log(f"  unnamed clubs: {unnamed}")
    log(f"digest  : {digest}")
    log(f"wrote    : {out_path} ({len(text):,} bytes)")
    return 0


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--data-dir", type=Path, default=repo / ".dataset-cache",
                    help="directory for the source CSVs (downloaded here when missing)")
    ap.add_argument("--out", type=Path, default=repo / "assets/data/players_v1.json")
    ap.add_argument("--keep-current-set", action="store_true",
                    help="keep the player roster of the existing asset instead "
                         "of re-applying the eligibility filter")
    args = ap.parse_args()

    log(f"source CSVs: {args.data_dir}")
    download_csvs(args.data_dir)
    return build(args.data_dir, args.out, args.keep_current_set)


if __name__ == "__main__":
    sys.exit(main())
