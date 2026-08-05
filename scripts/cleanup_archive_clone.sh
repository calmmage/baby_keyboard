#!/usr/bin/env bash
set -euo pipefail

INCLUDE_OPTIONAL=0

if [[ "${1:-}" == "--include-optional" ]]; then
  INCLUDE_OPTIONAL=1
  shift
fi

ROOT="${1:-/Users/petrlavrov/archive/baby_keyboard}"

if [[ ! -d "$ROOT" ]]; then
  echo "Archive path does not exist: $ROOT" >&2
  exit 1
fi

TARGETS=(
  ".venv"
  "web/node_modules"
  "web/.next"
  "dev/output"
  ".specstory"
  ".idea"
  ".claude"
  ".uv-cache"
  "build"
)

OPTIONAL_TARGETS=(
  "dev/Resources"
  "archives"
  "dev/dev_doodle_family.png"
  "dev/dev_doodle_mama.png"
  "dev/dev_doodle_white young papa.png"
  "dev/dev_pencil_family.png"
  "dev/dev_pencil_papa.png"
  "dev/dev_pencil_white young mama.png"
  "dev/personal_certificate.p12"
)

echo "Archive cleanup root: $ROOT"
echo
echo "Targets:"
for rel in "${TARGETS[@]}"; do
  abs="$ROOT/$rel"
  if [[ -e "$abs" ]]; then
    du -sh "$abs" 2>/dev/null || true
  fi
done

if [[ "$INCLUDE_OPTIONAL" -eq 1 ]]; then
  echo
  echo "Optional targets:"
  for rel in "${OPTIONAL_TARGETS[@]}"; do
    abs="$ROOT/$rel"
    if [[ -e "$abs" ]]; then
      du -sh "$abs" 2>/dev/null || true
    fi
  done
fi

echo
echo "Removing local/generated directories..."
for rel in "${TARGETS[@]}"; do
  abs="$ROOT/$rel"
  if [[ -e "$abs" ]]; then
    rm -rf "$abs"
    echo "Removed $abs"
  fi
done

if [[ "$INCLUDE_OPTIONAL" -eq 1 ]]; then
  echo
  echo "Removing optional archive-only assets..."
  for rel in "${OPTIONAL_TARGETS[@]}"; do
    abs="$ROOT/$rel"
    if [[ -e "$abs" ]]; then
      rm -rf "$abs"
      echo "Removed $abs"
    fi
  done
fi

echo
echo "Archive size after cleanup:"
du -sh "$ROOT"
