#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Running smoke checks..."

bash -n cc_firmware.sh
echo "✓ bash -n"

./cc_firmware.sh --help >/dev/null
echo "✓ --help"

if command -v shellcheck >/dev/null; then
  shellcheck cc_firmware.sh
  echo "✓ shellcheck"
else
  echo "⚠ shellcheck not installed; skipping"
fi

echo "✓ Smoke checks passed"
