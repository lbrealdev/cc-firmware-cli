#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CK_PGP_PUBLIC_KEY="0xA3A31BAD5A2A5B10"

import_ck_public_key() {
  curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=$CK_PGP_PUBLIC_KEY" | gpg --import -q
}

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
  key_fingerprint=$(gpg --batch --no-tty --list-keys --with-colons 2>/dev/null | grep -i -B2 "coinkite" | grep "^fpr" | head -1 | cut -d: -f10 || true)

  if [ -z "$key_fingerprint" ]; then
    echo "Coinkite public key not found."
    echo "Importing Coinkite public key..."
    import_ck_public_key
    
    # Verify the key was imported successfully
    key_fingerprint=$(gpg --batch --no-tty --list-keys --with-colons 2>/dev/null | grep -i -B2 "coinkite" | grep "^fpr" | head -1 | cut -d: -f10 || true)
    
    if [ -z "$key_fingerprint" ]; then
      echo "Error: Failed to import Coinkite public key."
      exit 1
    fi
    
    echo "Successfully imported Coinkite key: $key_fingerprint"
  else
    echo "Found Coinkite key: $key_fingerprint"
  fi
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
