"""Generate meaningful dictionary definitions for catalog entries via calmlib LLM API.

Usage examples:
  uv run python -m scripts.generate_llm_definitions --limit 20
  uv run python -m scripts.generate_llm_definitions --model claude-3-5-haiku-latest --language en --write
  uv run python -m scripts.generate_llm_definitions --catalog /tmp/words.json --overwrite --write
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from pydantic import BaseModel, Field

from scripts.word_utils import PROJECT_ROOT

DEFAULT_CATALOG_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "word_sets.json"
DEFAULT_MODEL = "claude-3-5-haiku-latest"


class DefinitionResult(BaseModel):
    definition: str = Field(description="One concise dictionary-style definition sentence.")


def _normalize_language(value: str) -> str:
    normalized = value.strip().lower()
    if not normalized:
        return "en"
    return normalized.split("-", 1)[0]


def _load_payload(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _entries(payload: dict[str, Any]) -> list[dict[str, Any]]:
    entries = payload.get("entries")
    if isinstance(entries, list):
        return entries
    words = payload.get("words")
    if isinstance(words, list):
        return words
    raise SystemExit("catalog must contain `entries` (or `words`) list")


def _spelling(entry: dict[str, Any]) -> str:
    en_translation = _translation(entry, "en")
    if en_translation:
        return en_translation
    value = str(entry.get("spelling", "")).strip()
    if value:
        return value
    entry_id = str(entry.get("id", "")).strip()
    if entry_id:
        return entry_id.split("|", 1)[0]
    return ""


def _meaning_key(entry: dict[str, Any]) -> str:
    raw = entry.get("meaningKey")
    if raw is None:
        raw = entry.get("meaning_key")
    return str(raw).strip() if raw is not None else ""


def _translation(entry: dict[str, Any], language: str) -> str:
    translations = entry.get("translations")
    if not isinstance(translations, list):
        return ""

    language = _normalize_language(language)
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


def _has_definition(entry: dict[str, Any], language: str) -> bool:
    definitions = entry.get("definitions")
    if not isinstance(definitions, list):
        return False

    language = _normalize_language(language)
    for item in definitions:
        if not isinstance(item, dict):
            continue
        item_language = _normalize_language(str(item.get("language", "")))
        if item_language != language:
            continue
        text = str(item.get("text", "")).strip()
        if text:
            return True
    return False


def _upsert_definition(entry: dict[str, Any], language: str, text: str, source: str) -> None:
    definitions = entry.get("definitions")
    if not isinstance(definitions, list):
        definitions = []

    normalized_language = _normalize_language(language)
    updated = False
    for item in definitions:
        if not isinstance(item, dict):
            continue
        item_language = _normalize_language(str(item.get("language", "")))
        if item_language != normalized_language:
            continue
        item["language"] = normalized_language
        item["text"] = text
        item["source"] = source
        updated = True
        break

    if not updated:
        definitions.append({"language": normalized_language, "text": text, "source": source})

    entry["definitions"] = definitions


def _prompt_for_entry(entry: dict[str, Any], language: str) -> str:
    spelling = _spelling(entry)
    meaning_key = _meaning_key(entry)
    entry_id = str(entry.get("id", "")).strip()
    en_translation = _translation(entry, "en")
    ru_translation = _translation(entry, "ru")

    return (
        "Write one meaningful dictionary definition.\\n"
        f"Output language: {language}.\\n"
        "Requirements:\\n"
        "- One sentence only.\\n"
        "- Explain meaning naturally, do not output placeholders.\\n"
        "- Avoid tautology (do not define a word with itself).\\n"
        "- Keep it concise and kid-friendly.\\n\\n"
        f"Word: {spelling}\\n"
        f"Entry ID: {entry_id}\\n"
        f"Meaning key: {meaning_key or '(none)'}\\n"
        f"Known English translation: {en_translation or '(none)'}\\n"
        f"Known Russian translation: {ru_translation or '(none)'}\\n"
    )


def _write_payload(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Fill missing catalog definitions via calmlib.llm")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH, help="Catalog JSON path")
    parser.add_argument("--language", default="en", help="Definition language code (default: en)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="LLM model, default is Haiku-tier")
    parser.add_argument("--limit", type=int, default=50, help="Max entries to process")
    parser.add_argument("--sleep-ms", type=int, default=0, help="Delay between LLM calls in milliseconds")
    parser.add_argument("--overwrite", action="store_true", help="Regenerate definitions even if present")
    parser.add_argument("--write", action="store_true", help="Persist changes to catalog")
    parser.add_argument("--out", type=Path, default=None, help="Output path; defaults to --catalog")
    args = parser.parse_args()

    load_dotenv()
    load_dotenv(Path.home() / ".env")

    try:
        from calmlib.llm import query_llm_structured
    except ModuleNotFoundError as exc:
        raise SystemExit("missing dependency: calmlib (install extras or run in configured env)") from exc

    language = _normalize_language(args.language)
    payload = _load_payload(args.catalog)
    entries = _entries(payload)

    candidates: list[dict[str, Any]] = []
    for entry in entries:
        if not args.overwrite and _has_definition(entry, language):
            continue
        if not _spelling(entry):
            continue
        candidates.append(entry)

    if not candidates:
        print("no candidates: all entries already have definitions for target language")
        return 0

    limit = max(1, args.limit)
    source_tag = f"llm:{args.model}"

    print(f"target language: {language}")
    print(f"model: {args.model}")
    print(f"candidates: {len(candidates)}")
    print(f"processing: {min(limit, len(candidates))}")

    updated = 0
    failed = 0

    for entry in candidates[:limit]:
        prompt = _prompt_for_entry(entry, language)
        label = _spelling(entry)

        try:
            result: DefinitionResult = query_llm_structured(
                prompt=prompt,
                output_schema=DefinitionResult,
                model=args.model,
                temperature=0.2,
                max_tokens=120,
            )
            definition = result.definition.strip()
            if not definition:
                raise RuntimeError("empty definition returned")
            _upsert_definition(entry, language=language, text=definition, source=source_tag)
            updated += 1
            print(f"ok: {label} -> {definition}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"failed: {label}: {exc}")

        if args.sleep_ms > 0:
            time.sleep(args.sleep_ms / 1000.0)

    print(f"updated: {updated}")
    print(f"failed: {failed}")

    if not args.write:
        print("dry-run: no file changes written (use --write)")
        return 0

    out_path = args.catalog if args.out is None else args.out
    _write_payload(out_path, payload)
    print(f"wrote: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
