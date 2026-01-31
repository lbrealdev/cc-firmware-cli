#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_dependencies() {
  if ! command -v gpg > /dev/null; then
    echo "gpg is not installed or not in PATH."
    exit 1
  fi

  if ! command -v curl > /dev/null; then
    echo "curl is not installed or not in PATH."
    exit 1
  fi
}

main() {
  echo "###########################################"
  echo "#         ColdCard MK4 Firmware           #"
  echo "###########################################"
  echo ""

  check_dependencies
}

main
