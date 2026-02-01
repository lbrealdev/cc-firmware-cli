#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_VERSION=""
FIRMWARE_FILE=""

# COINKITE CONFIG VARIABLES
COINKITE_PGP_PUBLIC_KEY="0xA3A31BAD5A2A5B10"
COINKITE_GITHUB_REPO="Coldcard/firmware"

show_usage() {
  echo "Usage: $SCRIPT_NAME --version <X.Y.Z>"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    echo "Error: --version is required"
    show_usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case $1 in
      --version)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          FIRMWARE_VERSION="$2"
          shift 2
        else
          echo "Error: --version requires a version in X.Y.Z format (e.g., 5.4.1)"
          exit 1
        fi
        ;;
      *)
        echo "Error: Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

import_ck_public_key() {
  curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=$COINKITE_PGP_PUBLIC_KEY" | gpg --import -q
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

  if ! command -v git > /dev/null; then
    echo "git is not installed or not in PATH."
    exit 1
  fi
}

# Check if the Coinkite public key is imported.
check_ck_public_key() {
  echo "Checking Coinkite PGP key..."
  
  local key_fingerprint
  # Use --no-tty and --batch to prevent interactive prompts
  key_fingerprint=$(gpg --batch --no-tty --list-keys --with-colons 2>/dev/null | grep -i -B2 "coinkite" | grep "^fpr" | head -1 | cut -d: -f10 || true)

  if [ -z "$key_fingerprint" ]; then
    echo "  Key not found, importing from keyserver..."
    import_ck_public_key
    
    # Verify the key was imported successfully
    key_fingerprint=$(gpg --batch --no-tty --list-keys --with-colons 2>/dev/null | grep -i -B2 "coinkite" | grep "^fpr" | head -1 | cut -d: -f10 || true)
    
    if [ -z "$key_fingerprint" ]; then
      echo "Error: Failed to import Coinkite public key."
      exit 1
    fi
  fi
  
  echo "✓ Key ready: $key_fingerprint"
}

download_firmware() {
  local _firmware_version="$1"
  local firmware_platform="mk4-coldcard"
  local firmware_ext="dfu"

  echo ""
  echo "Validating firmware version $_firmware_version..."

  ck_gh_tag_version=$(git ls-remote -t https://github.com/"$COINKITE_GITHUB_REPO".git | awk '{print $2}' | grep "$_firmware_version" | head -1 || true)

  # Validate that a matching tag was found
  if [ -z "$ck_gh_tag_version" ]; then
    echo "Error: Version $_firmware_version not found."
    echo ""
    echo "You can find available firmware versions at:"
    echo "  - GitHub releases: https://github.com/Coldcard/firmware/tags"
    echo "  - Coldcard downloads: https://coldcard.com/downloads/mk4"
    exit 1
  fi

  echo "✓ Version found on GitHub"

  ck_firmware_version=${ck_gh_tag_version//refs\/tags\/}

  local firmware_file="${ck_firmware_version}-${firmware_platform}.${firmware_ext}"
  local firmware_url="https://coldcard.com/downloads/${firmware_file}"

  # Check for existing .dfu files
  local existing_dfu
  existing_dfu=$(find . -maxdepth 1 -name "*.dfu" -type f 2>/dev/null)

  if [ -n "$existing_dfu" ]; then
    # Count and list existing files
    local dfu_count
    dfu_count=$(echo "$existing_dfu" | wc -l)
    echo ""
    echo "Found $dfu_count firmware file(s) in current directory:"
    echo "$existing_dfu" | while read -r file; do
      echo "  - $(basename "$file")"
    done
    echo ""

    # Check if exact version already exists
    if [ -f "$firmware_file" ]; then
      echo "Requested version already exists: $firmware_file"
      echo "Skipping download."
      FIRMWARE_FILE="$firmware_file"
      return 0
    fi

    # Different version exists - ask user
    echo "You requested: $firmware_file"
    echo ""
    read -p "Download requested version? (y/N): " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Download cancelled."
      exit 0
    fi
  fi

  echo ""
  echo "Downloading firmware..."

  if ! curl -fsSLo "$firmware_file" "$firmware_url"; then
    echo "Error: Failed to download firmware."
    exit 1
  fi

  echo "> $firmware_file"

  # Set global variable for later use
  FIRMWARE_FILE="$firmware_file"
}

download_signature() {
  local signatures_url="https://raw.githubusercontent.com/$COINKITE_GITHUB_REPO/master/releases/signatures.txt"
  local signatures_file="signatures.txt"

  echo ""
  echo "Downloading signatures..."

  # Remove old signature file if exists (always download fresh)
  if [ -f "$signatures_file" ]; then
    echo "  Removing old signature file..."
    rm -f "$signatures_file"
  fi

  # Download fresh signature file
  if ! curl -fsSLo "$signatures_file" "$signatures_url"; then
    echo "Error: Failed to download signatures file from $signatures_url"
    exit 1
  fi

  # Validate file is not empty
  if [ ! -s "$signatures_file" ]; then
    echo "Error: Downloaded signatures file is empty."
    rm -f "$signatures_file"
    exit 1
  fi

  echo "> $signatures_file"
}

verify_signatures_file() {
  echo ""
  echo "Verifying PGP signature..."

  if ! gpg --verify signatures.txt >/dev/null 2>&1; then
    echo "Error: Failed to verify signatures.txt PGP signature."
    exit 1
  fi

  echo "✓ Signature valid"
}

verify_firmware_hash() {
  echo ""
  echo "Verifying firmware hash..."

  if [ ! -f "$FIRMWARE_FILE" ]; then
    echo "Error: Firmware file not found: $FIRMWARE_FILE"
    exit 1
  fi

  local actual_hash
  actual_hash=$(sha256sum "$FIRMWARE_FILE" | awk '{print $1}')
  echo "  Actual:   $actual_hash"

  local expected_line
  expected_line=$(grep "$FIRMWARE_FILE" signatures.txt || true)

  if [ -z "$expected_line" ]; then
    echo "Error: Firmware file not found in signatures.txt"
    exit 1
  fi

  local expected_hash
  expected_hash=$(echo "$expected_line" | awk '{print $1}')
  echo "  Expected: $expected_hash"

  if [ "$actual_hash" = "$expected_hash" ]; then
    echo "✓ Hash verified"
  else
    echo ""
    echo "Error: Hash mismatch!"
    echo "  Calculated: $actual_hash"
    echo "  Expected:   $expected_hash"
    exit 1
  fi
}

main() {
  parse_args "$@"

  echo "###########################################"
  echo "#         ColdCard MK4 Firmware           #"
  echo "###########################################"
  echo ""

  check_dependencies
  check_ck_public_key
  download_firmware "$FIRMWARE_VERSION"
  download_signature
  verify_signatures_file
  verify_firmware_hash
}

main "$@"
