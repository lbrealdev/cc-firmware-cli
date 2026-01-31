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

# Check if the Coinkite public key is imported.
check_ck_public_key() {
  local key_fingerprint
  # Use --no-tty and --batch to prevent interactive prompts
  key_fingerprint=$(gpg --batch --no-tty --list-keys --with-colons 2>/dev/null | grep -i "coinkite" | grep "^fpr" | head -1 | cut -d: -f10 || true)

  if [ -z "$key_fingerprint" ]; then
    echo "Error: Coinkite public key not found."
    exit 1
  fi

  echo "Found Coinkite key: $key_fingerprint"
}

main() {
  echo "###########################################"
  echo "#         ColdCard MK4 Firmware           #"
  echo "###########################################"
  echo ""

  check_dependencies
  check_ck_public_key
}

main
