"""Export default word sets from Swift source into a bundled JSON file.

Usage:
  uv run python -m scripts.export_word_sets_json --out BabyKeyboardLock/Resources/word_sets.json

We keep this script so word sets can be updated without hand-editing Swift.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from scripts.word_utils import DEFAULT_SWIFT_PATH, PROJECT_ROOT, load_word_sets


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

    payload = {
        "version": 1,
        "source": source,
        "sets": [
            {
                "name": ws.name,
                "words": [asdict(w) for w in ws.words],
            }
            for ws in word_sets
        ],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
