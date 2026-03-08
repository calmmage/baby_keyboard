"""Generate candidate words to expand the bundled word library.

Usage examples:
  uv run python -m scripts.generate_library_words --count 200 --out /tmp/word_candidates.json
  uv run python -m scripts.generate_library_words --catalog BabyKeyboardLock/Resources/word_sets.json --language en --count 100
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from scripts.word_utils import PROJECT_ROOT

DEFAULT_CATALOG_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "word_sets.json"
DEFAULT_SCAN_MULTIPLIER = 20


ASCII_WORD_PATTERN = re.compile(r"^[a-z][a-z'-]*$")


def _normalize_word(value: str) -> str:
    return " ".join(value.strip().lower().split())


def _load_payload(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _entries(payload: dict[str, Any]) -> list[dict[str, Any]]:
    entries = payload.get("entries")
    if isinstance(entries, list):
        return entries
    words = payload.get("words")
    if isinstance(words, list):
        return words
    return []


def _existing_word_ids(entries: list[dict[str, Any]]) -> set[str]:
    result: set[str] = set()
    for entry in entries:
        entry_id = str(entry.get("id", "")).strip()
        if entry_id:
            normalized_id = _normalize_word(entry_id)
            if normalized_id:
                result.add(normalized_id)
                continue

        spelling = _normalize_word(str(entry.get("spelling", "")))
        if spelling:
            result.add(spelling)
    return result


def _is_allowed_word(word: str, min_length: int, max_length: int, ascii_only: bool) -> bool:
    if len(word) < min_length or len(word) > max_length:
        return False
    if ascii_only:
        return bool(ASCII_WORD_PATTERN.fullmatch(word))
    return True


def _top_words(language: str, scan_size: int) -> list[str]:
    try:
        import wordfreq  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("missing dependency: wordfreq (uv add wordfreq)") from exc

    try:
        return list(wordfreq.top_n_list(language, scan_size))
    except TypeError:
        return list(wordfreq.top_n_list(language, n_top=scan_size))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate candidate words to grow the Baby Keyboard library.")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH, help="Path to word catalog JSON")
    parser.add_argument("--language", default="en", help="Language for frequency source (default: en)")
    parser.add_argument("--count", type=int, default=100, help="How many candidates to emit")
    parser.add_argument(
        "--scan-size",
        type=int,
        default=0,
        help="How many top-frequency words to scan (default: count * 20)",
    )
    parser.add_argument("--min-length", type=int, default=2, help="Minimum word length")
    parser.add_argument("--max-length", type=int, default=12, help="Maximum word length")
    parser.add_argument("--min-zipf", type=float, default=3.5, help="Minimum zipf frequency")
    parser.add_argument(
        "--allow-non-ascii",
        action="store_true",
        help="Include non-ASCII candidates (default filters to simple latin words)",
    )
    parser.add_argument("--out", type=Path, default=None, help="Optional output JSON file")
    args = parser.parse_args()

    if args.count <= 0:
        raise SystemExit("--count must be > 0")

    language = args.language.strip().lower().split("-", 1)[0] or "en"
    payload = _load_payload(args.catalog)
    entries = _entries(payload)
    existing = _existing_word_ids(entries)

    scan_size = args.scan_size if args.scan_size > 0 else max(args.count * DEFAULT_SCAN_MULTIPLIER, args.count)

    try:
        import wordfreq  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit("missing dependency: wordfreq (uv add wordfreq)") from exc

    raw_candidates = _top_words(language, scan_size)
    selected: list[dict[str, Any]] = []
    seen: set[str] = set()

    for raw in raw_candidates:
        candidate = _normalize_word(raw)
        if not candidate or candidate in seen:
            continue
        if candidate in existing:
            continue
        if not _is_allowed_word(
            candidate,
            min_length=max(1, args.min_length),
            max_length=max(max(1, args.min_length), args.max_length),
            ascii_only=not args.allow_non_ascii,
        ):
            continue

        zipf = float(wordfreq.zipf_frequency(candidate, language))
        if zipf < args.min_zipf:
            continue

        seen.add(candidate)
        selected.append(
            {
                "id": candidate,
                "translations": [{"language": "en", "text": candidate}],
                "partOfSpeech": None,
                "category": None,
                "tags": [],
                "definitions": [],
                "assets": [],
                "frequency": {
                    "zipf": round(zipf, 4),
                    "sourceLanguage": language,
                    "resolvedFrom": "translations[en]",
                },
            }
        )
        if len(selected) >= args.count:
            break

    output_payload = {
        "language": language,
        "catalogPath": str(args.catalog),
        "existingWordIDs": len(existing),
        "requestedCount": args.count,
        "generatedCount": len(selected),
        "candidates": selected,
    }

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(output_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote: {args.out}")
    else:
        print(json.dumps(output_payload, ensure_ascii=False, indent=2))

    if len(selected) < args.count:
        print(
            f"warning: generated {len(selected)} candidates (requested {args.count}). "
            "Try lowering --min-zipf or increasing --scan-size."
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
