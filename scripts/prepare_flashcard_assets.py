"""Prepare flashcard asset upload manifest and catalog metadata."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import quote

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG_PATH = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "word_sets.json"
DEFAULT_IMAGES_DIR = PROJECT_ROOT / "BabyKeyboardLock" / "Resources" / "FlashcardImages"
DEFAULT_MANIFEST_PATH = PROJECT_ROOT / "dev" / "artifacts" / "flashcard-assets-manifest.json"
DEFAULT_CATALOG_OUT = PROJECT_ROOT / "dev" / "artifacts" / "word_sets.remote_assets.json"


@dataclass(frozen=True)
class AssetFile:
    style: str
    spelling: str
    filename: str
    relative_path: str
    local_path: str
    object_key: str
    public_url: str
    size_bytes: int


def normalize_spelling(value: str) -> str:
    return value.strip().lower()


def spelling_from_entry(entry: dict[str, Any]) -> str:
    spelling = entry.get("spelling")
    if isinstance(spelling, str) and spelling.strip():
        return normalize_spelling(spelling)

    translations = entry.get("translations")
    if isinstance(translations, list):
        for translation in translations:
            if not isinstance(translation, dict):
                continue
            language = str(translation.get("language", "")).strip().lower()
            text = str(translation.get("text", "")).strip()
            if language.startswith("en") and text:
                return normalize_spelling(text)

    entry_id = str(entry.get("id", "")).strip()
    if entry_id:
        return normalize_spelling(entry_id.split("|", 1)[0])

    return ""


def parse_asset_file(path: Path, object_key_prefix: str, base_url: str, images_dir: Path) -> AssetFile | None:
    if path.suffix.lower() != ".png":
        return None

    if path.parent == images_dir:
        return None

    style = path.parent.name.strip().lower()
    filename = path.name
    expected_prefix = f"{style}_"
    if not filename.lower().startswith(expected_prefix) or not filename.lower().endswith(".png"):
        return None

    spelling_token = filename[len(expected_prefix) : -4]
    spelling = spelling_token.replace("_", " ").strip().lower()
    if not spelling:
        return None

    object_key = f"{object_key_prefix.rstrip('/')}/{quote(style)}/{quote(filename)}"
    public_url = f"{base_url.rstrip('/')}/{object_key}"
    relative_path = path.relative_to(PROJECT_ROOT).as_posix()

    return AssetFile(
        style=style,
        spelling=spelling,
        filename=filename,
        relative_path=relative_path,
        local_path=str(path),
        object_key=object_key,
        public_url=public_url,
        size_bytes=path.stat().st_size,
    )


def discover_assets(images_dir: Path, object_key_prefix: str, base_url: str) -> list[AssetFile]:
    assets: list[AssetFile] = []
    for path in sorted(images_dir.rglob("*.png")):
        parsed = parse_asset_file(path, object_key_prefix=object_key_prefix, base_url=base_url, images_dir=images_dir)
        if parsed is not None:
            assets.append(parsed)
    return assets


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_manifest_payload(assets: list[AssetFile], object_key_prefix: str) -> dict[str, Any]:
    return {
        "version": 1,
        "objectKeyPrefix": object_key_prefix,
        "count": len(assets),
        "items": [
            {
                "style": asset.style,
                "spelling": asset.spelling,
                "filename": asset.filename,
                "relativePath": asset.relative_path,
                "localPath": asset.local_path,
                "objectKey": asset.object_key,
                "publicUrl": asset.public_url,
                "sizeBytes": asset.size_bytes,
            }
            for asset in assets
        ],
    }


def update_catalog_with_assets(catalog: dict[str, Any], assets: list[AssetFile], base_url: str) -> tuple[dict[str, Any], int]:
    assets_by_spelling: dict[str, list[AssetFile]] = {}
    for asset in assets:
        assets_by_spelling.setdefault(asset.spelling, []).append(asset)

    touched_entries = 0
    for entry in catalog.get("entries", []):
        if not isinstance(entry, dict):
            continue
        spelling = spelling_from_entry(entry)
        if not spelling:
            continue

        matched_assets = assets_by_spelling.get(spelling)
        if not matched_assets:
            continue

        existing_assets = entry.get("assets")
        preserved_assets: list[dict[str, Any]] = []
        if isinstance(existing_assets, list):
            for existing in existing_assets:
                if not isinstance(existing, dict):
                    continue
                if str(existing.get("kind", "")).strip().lower() != "image":
                    preserved_assets.append(existing)
                    continue
                uri = str(existing.get("uri", "")).strip()
                if uri and not uri.startswith(base_url.rstrip("/") + "/"):
                    preserved_assets.append(existing)

        generated_assets = [
            {
                "kind": "image",
                "language": "en",
                "uri": asset.public_url,
            }
            for asset in sorted(matched_assets, key=lambda item: (item.style, item.filename))
        ]
        entry["assets"] = preserved_assets + generated_assets
        touched_entries += 1

    return catalog, touched_entries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--images-dir", type=Path, default=DEFAULT_IMAGES_DIR)
    parser.add_argument("--base-url", required=True, help="Public base URL without trailing slash")
    parser.add_argument("--object-key-prefix", default="flashcard-images")
    parser.add_argument("--manifest-out", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--catalog-out", type=Path, default=DEFAULT_CATALOG_OUT)
    parser.add_argument(
        "--write-catalog",
        action="store_true",
        help="Write updated assets directly back to the catalog file instead of catalog-out",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    catalog_path: Path = args.catalog.resolve()
    images_dir: Path = args.images_dir.resolve()
    base_url: str = args.base_url.strip().rstrip("/")
    object_key_prefix: str = args.object_key_prefix.strip().strip("/")

    if not catalog_path.exists():
        raise SystemExit(f"Catalog does not exist: {catalog_path}")
    if not images_dir.exists():
        raise SystemExit(f"Images directory does not exist: {images_dir}")
    if not base_url:
        raise SystemExit("--base-url must not be empty")
    if not object_key_prefix:
        raise SystemExit("--object-key-prefix must not be empty")

    catalog = load_json(catalog_path)
    assets = discover_assets(images_dir, object_key_prefix=object_key_prefix, base_url=base_url)
    manifest_payload = build_manifest_payload(assets, object_key_prefix=object_key_prefix)
    write_json(args.manifest_out.resolve(), manifest_payload)

    updated_catalog, touched_entries = update_catalog_with_assets(catalog, assets, base_url=base_url)
    catalog_output_path = catalog_path if args.write_catalog else args.catalog_out.resolve()
    write_json(catalog_output_path, updated_catalog)

    print(
        json.dumps(
            {
                "manifest": str(args.manifest_out.resolve()),
                "catalog": str(catalog_output_path),
                "assetFiles": len(assets),
                "entriesUpdated": touched_entries,
                "baseUrl": base_url,
                "objectKeyPrefix": object_key_prefix,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
