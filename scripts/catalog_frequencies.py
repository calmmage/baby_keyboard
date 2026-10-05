"""Annotate catalog entries with spelling-level frequency stats.

Usage:
  uv run python -m scripts.catalog_frequencies --sample 10
  uv run python -m scripts.catalog_frequencies --catalog BabyKeyboardLock/Resources/word_sets.json --write
  uv run python -m scripts.catalog_frequencies --catalog BabyKeyboardLock/Resources/word_sets.json --all --write
  uv run python -m scripts.catalog_frequencies --catalog /path/to/art.json --language en --write
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from scripts.word_utils import PROJECT_ROOT

DEFAULT_CATALOG_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "word_sets.json"


@dataclass
class FrequencyRecord:
    index: int
    entry_id: str
    source_word: str
    resolved_from: str
    zipf: float | None
    rank: int | None = None
    ambiguous_spelling: bool = False


def _normalize_language(raw: str) -> str:
    value = raw.strip().lower()
    if not value:
        return ""
    return value.split("-")[0]


def _normalize_text(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _load_payload(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _entries_container(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], str]:
    entries = payload.get("entries")
    if isinstance(entries, list):
        return entries, "entries"
    words = payload.get("words")
    if isinstance(words, list):
        return words, "words"
    raise SystemExit("catalog must contain `entries` (or `words`) list")


def _translation_text(entry: dict[str, Any], language: str) -> str:
    translations = entry.get("translations")
    if not isinstance(translations, list):
        return ""
    for item in translations:
        if not isinstance(item, dict):
            continue
        item_language = _normalize_language(str(item.get("language", "")))
        if item_language != language:
            continue
        text = str(item.get("text", "")).strip()
        if text:
            return text
    return ""


def _source_word(entry: dict[str, Any], language: str) -> tuple[str, str]:
    spelling = str(entry.get("spelling", "")).strip()
    if spelling:
        return _normalize_text(spelling), "spelling"

    translated = _translation_text(entry, language)
    if translated:
        return _normalize_text(translated), f"translations[{language}]"

    entry_id = str(entry.get("id", "")).strip()
    if entry_id:
        return _normalize_text(entry_id.split("|", 1)[0]), "id-prefix"
    return "", "missing"


def _build_records(entries: list[dict[str, Any]], language: str) -> list[FrequencyRecord]:
    try:
        import wordfreq  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("missing dependency: wordfreq (uv add wordfreq)") from exc

    records: list[FrequencyRecord] = []
    for index, entry in enumerate(entries):
        source_word, resolved_from = _source_word(entry, language)
        zipf: float | None = None
        if source_word:
            value = float(wordfreq.zipf_frequency(source_word, language))
            if value > 0.0:
                zipf = value
        entry_id = str(entry.get("id", "")).strip() or f"entry[{index}]"
        records.append(
            FrequencyRecord(
                index=index,
                entry_id=entry_id,
                source_word=source_word,
                resolved_from=resolved_from,
                zipf=zipf,
            )
        )

    spelling_counts = Counter(record.source_word for record in records if record.source_word)
    for record in records:
        record.ambiguous_spelling = spelling_counts.get(record.source_word, 0) > 1

    with_frequency = [record for record in records if record.zipf is not None]
    with_frequency.sort(key=lambda record: (-record.zipf, record.source_word, record.entry_id))
    for rank, record in enumerate(with_frequency, start=1):
        record.rank = rank

    return records


def _has_non_empty_frequency(entry: dict[str, Any]) -> bool:
    frequency = entry.get("frequency")
    if not isinstance(frequency, dict):
        return False
    zipf = frequency.get("zipf")
    if zipf is None:
        return False
    if isinstance(zipf, str):
        return bool(zipf.strip())
    return isinstance(zipf, (int, float))


def _target_indices(entries: list[dict[str, Any]], refresh_all: bool) -> set[int]:
    if refresh_all:
        return set(range(len(entries)))
    return {
        index
        for index, entry in enumerate(entries)
        if not _has_non_empty_frequency(entry)
    }


def _apply_records_targeted(
    entries: list[dict[str, Any]],
    records: list[FrequencyRecord],
    language: str,
    selected: set[int],
) -> int:
    updated = 0
    for record in records:
        if record.index not in selected:
            continue
        entry = entries[record.index]
        new_frequency = {
            "zipf": None if record.zipf is None else round(record.zipf, 4),
            "rank": record.rank,
            "sourceWord": record.source_word or None,
            "sourceLanguage": language,
            "resolvedFrom": record.resolved_from,
            "matchMode": "spelling",
            "ambiguousSpelling": record.ambiguous_spelling,
        }
        if entry.get("frequency") == new_frequency:
            continue
        entry["frequency"] = new_frequency
        updated += 1
    return updated


def _print_summary(records: list[FrequencyRecord], sample_size: int, selected: set[int], refresh_all: bool) -> None:
    selected_records = [record for record in records if record.index in selected]
    total = len(records)
    mode = "all" if refresh_all else "missing-only"
    selected_total = len(selected_records)
    known = sum(1 for record in selected_records if record.zipf is not None)
    missing = selected_total - known
    ambiguous_entries = sum(1 for record in selected_records if record.ambiguous_spelling)
    ambiguous_words = len({record.source_word for record in selected_records if record.ambiguous_spelling})

    print(f"entries={total} mode={mode} target_updates={selected_total}")
    print(f"target_with_frequency={known} target_missing_frequency={missing}")
    print(f"target_ambiguous_entries={ambiguous_entries} target_ambiguous_spellings={ambiguous_words}")
    print("")
    print("sample:")
    print("id\tword\tzipf\trank\tambiguous\tresolved_from")

    sample = sorted(
        selected_records,
        key=lambda record: (
            record.rank is None,
            record.rank if record.rank is not None else 10**9,
            record.entry_id,
        ),
    )[:sample_size]
    for record in sample:
        zipf = "" if record.zipf is None else f"{record.zipf:.2f}"
        rank = "" if record.rank is None else str(record.rank)
        ambiguous = "yes" if record.ambiguous_spelling else "no"
        print(
            f"{record.entry_id}\t{record.source_word}\t{zipf}\t{rank}\t{ambiguous}\t{record.resolved_from}"
        )


def _write_payload(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Attach frequency metadata to catalog entries.")
    parser.add_argument(
        "--catalog",
        type=Path,
        default=DEFAULT_CATALOG_PATH,
        help="Catalog JSON path (supports files with `entries` or `words` list).",
    )
    parser.add_argument(
        "--language",
        default="en",
        help="Language code used for lookup and translation fallback (default: en).",
    )
    parser.add_argument(
        "--sample",
        type=int,
        default=10,
        help="How many rows to print in sample output.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output path; defaults to --catalog.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Persist updates to JSON. Without this flag command is dry-run.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Recompute and overwrite frequency for all entries (default: update only missing/empty frequency).",
    )
    args = parser.parse_args()

    payload = _load_payload(args.catalog)
    entries, container_name = _entries_container(payload)
    language = _normalize_language(args.language) or "en"

    records = _build_records(entries, language)
    selected = _target_indices(entries, refresh_all=args.all)
    candidate_count = len(selected)
    updated = _apply_records_targeted(entries, records, language, selected)
    _print_summary(records, max(0, args.sample), selected, args.all)

    if args.write:
        out_path = args.catalog if args.out is None else args.out
        print("")
        if updated > 0:
            _write_payload(out_path, payload)
            print(f"wrote: {out_path}")
            print(f"candidate_entries={candidate_count}")
            print(f"updated_entries={updated}")
        else:
            print("no changes: nothing matched update criteria")
    else:
        print("")
        print(
            f"dry-run: no file written ({container_name} updated in memory, candidate_entries={candidate_count}, updated_entries={updated})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
