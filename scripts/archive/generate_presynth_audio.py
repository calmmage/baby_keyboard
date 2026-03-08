from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import quote

from loguru import logger


DEFAULT_VOICES = {
    "en": "Samantha",
    "ru": "Milena",
    "de": "Anna",
}


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(
        description="Generate pre-synthesized audio files for canonical word entries.",
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=repo_root / "BabyKeyboardLock" / "Resources" / "word_sets.json",
        help="Path to canonical word catalog JSON",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=repo_root / "web" / "public" / "generated-audio" / "presynth",
        help="Output folder for generated audio files",
    )
    parser.add_argument(
        "--languages",
        default="en,ru,de",
        help="Comma-separated language codes",
    )
    parser.add_argument(
        "--voice",
        action="append",
        default=[],
        help="Override voice mapping with lang=voice_name (e.g. --voice en=Alex)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate files even if they already exist",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Generate only first N entries (0 = all)",
    )
    parser.add_argument(
        "--base-url",
        default="",
        help="Optional public base URL for manifest entries (e.g. https://bucket.s3.us-east-1.amazonaws.com)",
    )
    parser.add_argument(
        "--url-prefix",
        default="",
        help="Optional URL prefix under base URL (e.g. baby-keyboard)",
    )
    return parser.parse_args()


def parse_voice_overrides(values: list[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"Invalid --voice format: {value}")
        lang, voice = value.split("=", 1)
        lang = lang.strip().lower()
        voice = voice.strip()
        if not lang or not voice:
            raise ValueError(f"Invalid --voice mapping: {value}")
        result[lang] = voice
    return result


def load_entries(catalog_path: Path) -> list[dict[str, Any]]:
    raw = json.loads(catalog_path.read_text(encoding="utf-8"))
    if "entries" in raw and isinstance(raw["entries"], list):
        return raw["entries"]
    # Legacy fallback
    entries: list[dict[str, Any]] = []
    for set_data in raw.get("sets", []):
        for word in set_data.get("words", []):
            english = str(word.get("english", "")).strip()
            translation = str(word.get("translation", "")).strip()
            if not english:
                continue
            entries.append(
                {
                    "id": english.lower(),
                    "spelling": english,
                    "translations": (
                        [{"language": "ru", "text": translation}] if translation else []
                    ),
                }
            )
    return entries


def translation_map(entry: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for item in entry.get("translations", []):
        language = str(item.get("language", "")).strip().lower()
        text = str(item.get("text", "")).strip()
        if language and text:
            mapping[language] = text
    return mapping


def text_for_language(entry: dict[str, Any], language: str) -> str | None:
    if language == "en":
        spelling = str(entry.get("spelling", "")).strip()
        return spelling or None
    return translation_map(entry).get(language)


def run_command(command: list[str]) -> None:
    subprocess.run(command, check=True)


def synthesize_to_file(text: str, voice: str, output_path: Path) -> None:
    run_command(["say", "-v", voice, "-o", str(output_path), text])


def convert_aiff_to_wav(aiff_path: Path, wav_path: Path) -> None:
    run_command(
        [
            "afconvert",
            "-f",
            "WAVE",
            "-d",
            "LEI16@22050",
            str(aiff_path),
            str(wav_path),
        ]
    )


def main() -> None:
    args = parse_args()
    languages = [lang.strip().lower() for lang in args.languages.split(",") if lang.strip()]
    voice_overrides = parse_voice_overrides(args.voice)
    voices = {**DEFAULT_VOICES, **voice_overrides}

    if not shutil.which("say"):
        raise RuntimeError("macOS 'say' command is required")

    has_afconvert = shutil.which("afconvert") is not None
    extension = "wav" if has_afconvert else "aiff"

    entries = load_entries(args.catalog)
    if args.limit > 0:
        entries = entries[: args.limit]

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    base_url = args.base_url.strip().rstrip("/")
    url_prefix = args.url_prefix.strip().strip("/")

    generated = 0
    skipped = 0
    manifest_items: list[dict[str, Any]] = []

    for entry in entries:
        word_id = str(entry.get("id", "")).strip()
        if not word_id:
            continue
        safe_word_id = quote(word_id.lower(), safe="")

        for language in languages:
            text = text_for_language(entry, language)
            if not text:
                continue

            voice = voices.get(language) or DEFAULT_VOICES.get("en", "Samantha")
            language_dir = output_dir / language
            language_dir.mkdir(parents=True, exist_ok=True)
            final_path = language_dir / f"{safe_word_id}.{extension}"
            relative_url = f"generated-audio/presynth/{language}/{final_path.name}"
            if url_prefix:
                relative_url = f"{url_prefix}/{relative_url}"
            manifest_url = f"/{relative_url}"
            if base_url:
                manifest_url = f"{base_url}/{relative_url}"

            if final_path.exists() and not args.force:
                skipped += 1
                manifest_items.append(
                    {
                        "word_id": word_id,
                        "language": language,
                        "text": text,
                        "voice": voice,
                        "url": manifest_url,
                    }
                )
                continue

            if has_afconvert:
                temp_aiff = language_dir / f"{safe_word_id}.aiff"
                synthesize_to_file(text=text, voice=voice, output_path=temp_aiff)
                convert_aiff_to_wav(temp_aiff, final_path)
                temp_aiff.unlink(missing_ok=True)
            else:
                synthesize_to_file(text=text, voice=voice, output_path=final_path)

            generated += 1
            manifest_items.append(
                {
                    "word_id": word_id,
                    "language": language,
                    "text": text,
                    "voice": voice,
                    "url": manifest_url,
                }
            )

    manifest = {
        "generated_at": datetime.now(UTC).isoformat(),
        "catalog_path": str(args.catalog),
        "languages": languages,
        "extension": extension,
        "items": manifest_items,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    logger.info(
        "Audio generation complete: generated={}, skipped={}, manifest={}",
        generated,
        skipped,
        manifest_path,
    )


if __name__ == "__main__":
    main()
