"""Export default word sets from Swift source into a bundled JSON file.

Usage:
  uv run python -m scripts.export_word_sets_json --out BabyKeyboardLock/Resources/word_sets.json

We keep this script so word sets can be updated without hand-editing Swift.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from scripts.word_utils import DEFAULT_SWIFT_PATH, PROJECT_ROOT, load_word_sets


def _normalize_text(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _make_word_id(spelling: str, meaning_key: str | None) -> str:
    base = _normalize_text(spelling)
    mk = _normalize_text(meaning_key or "")
    return f"{base}|{mk}" if mk else base


def _meaning_key_from_translation(value: str) -> str:
    normalized = _normalize_text(value).replace("|", " ")
    slug = re.sub(r"\s+", "_", normalized)
    slug = re.sub(r"[^\w\-]", "", slug, flags=re.UNICODE)
    return slug or "meaning"


def _set_id(name: str, index: int) -> str:
    base = re.sub(r"[^\w\-]+", "-", _normalize_text(name), flags=re.UNICODE).strip("-")
    if not base:
        base = "set"
    return f"{base}-{index}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--swift",
        type=Path,
        default=DEFAULT_SWIFT_PATH,
        help="Path to RandomWordList.swift to parse",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("BabyKeyboardLock/Resources/word_sets.json"),
        help="Where to write the JSON output",
    )
    args = parser.parse_args()

    word_sets = load_word_sets(args.swift)

    try:
        source = str(args.swift.relative_to(PROJECT_ROOT))
    except ValueError:
        source = str(args.swift)

    translation_variants: dict[str, set[str]] = {}
    for word_set in word_sets:
        for word in word_set.words:
            spelling = _normalize_text(word.english)
            translation = _normalize_text(word.translation)
            if not spelling or not translation:
                continue
            translation_variants.setdefault(spelling, set()).add(translation)

    entries_by_id: dict[str, dict] = {}
    ordered_entry_ids: list[str] = []
    sets_payload: list[dict] = []

    for set_index, word_set in enumerate(word_sets):
        word_ids: list[str] = []
        for word in word_set.words:
            spelling = word.english.strip()
            if not spelling:
                continue
            normalized_spelling = _normalize_text(spelling)
            translation = word.translation.strip()
            meaning_key = None
            if len(translation_variants.get(normalized_spelling, set())) > 1:
                meaning_key = _meaning_key_from_translation(translation)
            word_id = _make_word_id(spelling, meaning_key)
            word_ids.append(word_id)

            if word_id not in entries_by_id:
                translations = []
                if translation:
                    translations.append({"language": "ru", "text": translation})
                entries_by_id[word_id] = {
                    "id": word_id,
                    "spelling": spelling,
                    "meaningKey": meaning_key,
                    "partOfSpeech": None,
                    "category": None,
                    "tags": [],
                    "translations": translations,
                    "definitions": [],
                    "assets": [],
                }
                ordered_entry_ids.append(word_id)

        sets_payload.append(
            {
                "id": _set_id(word_set.name, set_index),
                "name": word_set.name,
                "wordIDs": word_ids,
            }
        )

    payload = {
        "version": 2,
        "source": source,
        "entries": [entries_by_id[word_id] for word_id in ordered_entry_ids],
        "sets": sets_payload,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
