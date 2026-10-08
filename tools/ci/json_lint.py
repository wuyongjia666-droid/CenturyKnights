#!/usr/bin/env python3
"""Parse project/data JSON and validate the v9.2 backlog card schema.

Exit 0 prints JSON LINT PASS. Any parse error or schema mismatch exits 1.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "project" / "data"
BACKLOG = ROOT / "docs" / "plan" / "backlog-v92.json"

REQUIRED = (
    "id",
    "title",
    "priority",
    "why",
    "scope",
    "files",
    "acceptance",
    "dependencies",
    "needs_farm",
    "size",
    "parallel_group",
)
OPTIONAL = {"needs_external_audio", "notes"}
PRIORITIES = {"P0", "P1", "P2"}
SIZES = {"S", "M", "L"}


def _load(path: Path):
    text = path.read_text(encoding="utf-8")
    return json.loads(text)


def _string_list(value, label: str, errors: list[str]) -> None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        errors.append(f"{label} must be a list of strings")


def _validate_card(card: object, index: int, seen: set[str]) -> list[str]:
    errors: list[str] = []
    where = f"cards[{index}]"
    if not isinstance(card, dict):
        return [f"{where} must be an object"]
    keys = set(card)
    missing = [key for key in REQUIRED if key not in keys]
    if missing:
        errors.append(f"{where} missing {', '.join(missing)}")
    unknown = sorted(keys - set(REQUIRED) - OPTIONAL)
    if unknown:
        errors.append(f"{where} unknown fields: {', '.join(unknown)}")
    card_id = card.get("id")
    if not isinstance(card_id, str) or not card_id:
        errors.append(f"{where}.id must be a non-empty string")
    elif card_id in seen:
        errors.append(f"duplicate card id {card_id}")
    else:
        seen.add(card_id)
        where = card_id
    for key in ("title", "why", "scope", "parallel_group"):
        if key in card and (not isinstance(card[key], str) or not card[key].strip()):
            errors.append(f"{where}.{key} must be a non-empty string")
    if "priority" in card and card["priority"] not in PRIORITIES:
        errors.append(f"{where}.priority must be one of {sorted(PRIORITIES)}")
    if "size" in card and card["size"] not in SIZES:
        errors.append(f"{where}.size must be one of {sorted(SIZES)}")
    if "files" in card:
        _string_list(card["files"], f"{where}.files", errors)
    if "acceptance" in card:
        _string_list(card["acceptance"], f"{where}.acceptance", errors)
        if isinstance(card["acceptance"], list) and not card["acceptance"]:
            errors.append(f"{where}.acceptance must not be empty")
    if "dependencies" in card:
        _string_list(card["dependencies"], f"{where}.dependencies", errors)
    if "needs_farm" in card and not isinstance(card["needs_farm"], bool):
        errors.append(f"{where}.needs_farm must be a boolean")
    if "needs_external_audio" in card and not isinstance(card["needs_external_audio"], bool):
        errors.append(f"{where}.needs_external_audio must be a boolean")
    if "notes" in card and not isinstance(card["notes"], str):
        errors.append(f"{where}.notes must be a string")
    return errors


def _validate_backlog(data: object) -> list[str]:
    if not isinstance(data, dict):
        return ["backlog-v92.json must be an object"]
    schema = data.get("schema")
    if not isinstance(schema, dict):
        return ["backlog schema missing"]
    declared = schema.get("card")
    if declared != list(REQUIRED):
        return [f"backlog schema.card drifted from json_lint required fields: {declared}"]
    cards = data.get("cards")
    if not isinstance(cards, list) or not cards:
        return ["backlog cards must be a non-empty list"]
    errors: list[str] = []
    seen: set[str] = set()
    for index, card in enumerate(cards):
        errors.extend(_validate_card(card, index, seen))
    return errors


def main() -> int:
    errors: list[str] = []
    files = sorted(DATA_DIR.rglob("*.json"))
    if not files:
        errors.append(f"no JSON under {DATA_DIR}")
    files.append(BACKLOG)
    parsed = 0
    for path in files:
        try:
            data = _load(path)
        except FileNotFoundError:
            errors.append(f"missing {path}")
            continue
        except json.JSONDecodeError as exc:
            errors.append(f"{path}: {exc}")
            continue
        parsed += 1
        if path == BACKLOG:
            errors.extend(_validate_backlog(data))
    if errors:
        print(f"JSON LINT FAIL files={parsed} errors={len(errors)}")
        for err in errors:
            print(f"FAIL {err}")
        return 1
    print(f"JSON LINT PASS files={parsed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
