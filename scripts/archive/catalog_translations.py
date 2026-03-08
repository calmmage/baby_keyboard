"""Audit and populate translations in the canonical word catalog.

Usage:
  uv run python -m scripts.catalog_translations audit
  uv run python -m scripts.catalog_translations populate --languages de,fr,es,it,ja,zh --write
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

from scripts.word_utils import PROJECT_ROOT

DEFAULT_CATALOG_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "word_sets.json"
DEFAULT_LEGACY_SOURCE_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "EventEffectHandler.swift"

LANGUAGE_ALIASES = {
    "en": "en",
    "english": "en",
    "ru": "ru",
    "russian": "ru",
    "de": "de",
    "german": "de",
    "fr": "fr",
    "french": "fr",
    "es": "es",
    "spanish": "es",
    "it": "it",
    "italian": "it",
    "ja": "ja",
    "japanese": "ja",
    "zh": "zh",
    "chinese": "zh",
}

LEGACY_MAP_TO_LANGUAGE = {
    "french": "fr",
    "russian": "ru",
    "german": "de",
    "spanish": "es",
    "italian": "it",
    "japanese": "ja",
    "chinese": "zh",
}


def _normalize_language(raw: str) -> str:
    lowered = raw.strip().lower()
    if not lowered:
        return lowered
    return LANGUAGE_ALIASES.get(lowered, lowered.split("-")[0])


def _parse_languages(raw: str) -> list[str]:
    values = []
    seen = set()
    for token in raw.split(","):
        lang = _normalize_language(token)
        if not lang or lang in seen:
            continue
        values.append(lang)
        seen.add(lang)
    return values


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _translation_map(entry: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for item in entry.get("translations", []):
        language = _normalize_language(str(item.get("language", "")))
        text = str(item.get("text", "")).strip()
        if language and text and language not in mapping:
            mapping[language] = text
    return mapping


def _has_translation(entry: dict[str, Any], language: str) -> bool:
    return language in _translation_map(entry)


def _word_label(entry: dict[str, Any]) -> str:
    spelling = str(entry.get("spelling", "")).strip()
    raw_meaning = entry.get("meaningKey")
    meaning_key = str(raw_meaning).strip() if raw_meaning is not None else ""
    if meaning_key:
        return f"{spelling}|{meaning_key}"
    return spelling


def _audit(catalog: dict[str, Any], languages: list[str], max_examples: int, fail_on_missing: bool) -> int:
    entries = catalog.get("entries", [])
    total = len(entries)
    print(f"Catalog: {total} entries")
    print(f"Languages audited: {', '.join(languages)}")
    print("")

    has_missing = False
    for language in languages:
        present = 0
        missing_examples: list[str] = []
        for entry in entries:
            if _has_translation(entry, language):
                present += 1
            elif len(missing_examples) < max_examples:
                missing_examples.append(_word_label(entry))
        missing = total - present
        if missing > 0:
            has_missing = True
        percent = (present * 100.0 / total) if total else 0.0
        print(f"{language}: {present}/{total} ({percent:.1f}%)")
        if missing_examples:
            print(f"  missing examples: {', '.join(missing_examples)}")
        if missing:
            print(f"  missing total: {missing}")
        print("")
    if fail_on_missing and has_missing:
        print("CRITICAL: missing translations detected.")
        return 2
    return 0


def _extract_legacy_translation_maps(source_text: str) -> dict[str, dict[str, str]]:
    maps: dict[str, dict[str, str]] = {}
    block_pattern = re.compile(
        r"let\s+(\w+)Translations:\s*\[String:\s*String\]\s*=\s*\[(.*?)\n\s*\]",
        re.DOTALL,
    )
    pair_pattern = re.compile(r'"([^"]+)"\s*:\s*"([^"]*)"')

    for match in block_pattern.finditer(source_text):
        name = match.group(1).strip().lower()
        language = LEGACY_MAP_TO_LANGUAGE.get(name)
        if not language:
            continue
        pairs = pair_pattern.findall(match.group(2))
        if not pairs:
            continue
        mapping: dict[str, str] = {}
        for source, target in pairs:
            key = source.strip().lower()
            value = target.strip()
            if key and value and key not in mapping:
                mapping[key] = value
        if mapping:
            maps[language] = mapping
    return maps


def _populate_from_legacy(
    catalog: dict[str, Any],
    legacy_maps: dict[str, dict[str, str]],
    languages: list[str],
    allow_ambiguous: bool,
) -> tuple[int, int]:
    entries = catalog.get("entries", [])
    spelling_counts = Counter(
        str(entry.get("spelling", "")).strip().lower() for entry in entries if str(entry.get("spelling", "")).strip()
    )

    added = 0
    skipped_ambiguous = 0

    for entry in entries:
        spelling = str(entry.get("spelling", "")).strip().lower()
        if not spelling:
            continue

        translations = list(entry.get("translations", []))
        existing = _translation_map(entry)

        for language in languages:
            if language in existing:
                continue
            legacy_map = legacy_maps.get(language)
            if not legacy_map:
                continue

            # One spelling can have multiple meanings; avoid unsafe auto-fill unless explicitly allowed.
            if not allow_ambiguous and spelling_counts[spelling] > 1:
                skipped_ambiguous += 1
                continue

            value = legacy_map.get(spelling)
            if not value:
                continue
            translations.append({"language": language, "text": value})
            existing[language] = value
            added += 1

        entry["translations"] = translations

    return added, skipped_ambiguous


def _command_audit(args: argparse.Namespace) -> int:
    catalog = _load_json(args.catalog)
    return _audit(catalog, args.languages, args.examples, args.fail_on_missing)


def _command_populate(args: argparse.Namespace) -> int:
    catalog = _load_json(args.catalog)
    source_text = args.legacy_source.read_text(encoding="utf-8")
    legacy_maps = _extract_legacy_translation_maps(source_text)

    missing_maps = [lang for lang in args.languages if lang not in legacy_maps]
    if missing_maps:
        print(f"Warning: no legacy source map for: {', '.join(missing_maps)}")

    added, skipped_ambiguous = _populate_from_legacy(
        catalog=catalog,
        legacy_maps=legacy_maps,
        languages=args.languages,
        allow_ambiguous=args.allow_ambiguous,
    )

    out_path = args.catalog if args.out is None else args.out
    if args.write:
        out_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote updated catalog: {out_path}")
    else:
        print("Dry run: no file changes written. Use --write to persist.")

    print(f"Added translations: {added}")
    print(f"Skipped ambiguous entries: {skipped_ambiguous}")
    print("")
    return _audit(catalog, args.languages, args.examples, args.fail_on_missing)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--catalog",
        type=Path,
        default=DEFAULT_CATALOG_PATH,
        help="Path to canonical catalog JSON",
    )
    parser.add_argument(
        "--languages",
        type=_parse_languages,
        default=_parse_languages("de,fr,es,it,ja,zh,ru"),
        help="Comma-separated language list, e.g. de,fr,es",
    )
    parser.add_argument(
        "--examples",
        type=int,
        default=8,
        help="How many missing examples to print per language",
    )
    parser.add_argument(
        "--fail-on-missing",
        action="store_true",
        help="Return non-zero exit code when any audited language has missing translations",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    audit_parser = subparsers.add_parser("audit", help="Show translation coverage by language")
    audit_parser.set_defaults(func=_command_audit)

    populate_parser = subparsers.add_parser(
        "populate",
        help="Populate missing translations from legacy dictionaries in EventEffectHandler.swift",
    )
    populate_parser.add_argument(
        "--legacy-source",
        type=Path,
        default=DEFAULT_LEGACY_SOURCE_PATH,
        help="Path to EventEffectHandler.swift",
    )
    populate_parser.add_argument(
        "--allow-ambiguous",
        action="store_true",
        help="Also populate entries where one spelling maps to multiple meanings",
    )
    populate_parser.add_argument(
        "--write",
        action="store_true",
        help="Write changes to --catalog (or --out). Without this flag command is dry-run.",
    )
    populate_parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output path; defaults to --catalog",
    )
    populate_parser.set_defaults(func=_command_populate)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
