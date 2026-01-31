#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_VERSION=""
COINKITE_PGP_PUBLIC_KEY="0xA3A31BAD5A2A5B10"

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

  if ! command -v gh > /dev/null; then
    echo "gh is not installed or not in PATH."
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

download_firmware() {
  local firmware_url="https://github.com/Coldcard/firmware/releases/download/${FIRMWARE_VERSION}/firmware-${FIRMWARE_VERSION}.dfu"
  local firmware_file="firmware-${FIRMWARE_VERSION}.dfu"
  
  echo ""
  echo "Checking for existing firmware..."
  
  # Check for any existing .dfu files
  local existing_dfu
  existing_dfu=$(find . -maxdepth 1 -name "*.dfu" -type f 2>/dev/null | head -1)
  
  if [ -n "$existing_dfu" ]; then
    echo "Found existing firmware: $(basename "$existing_dfu")"
    echo "Skipping download."
    return 0
  fi
  
  # Download the firmware
  echo "Firmware not found locally."
  echo "Downloading firmware..."
  
  if ! curl -L --progress-bar -o "$firmware_file" "$firmware_url"; then
    echo "Error: Failed to download firmware."
    exit 1
  fi
  
  echo "Successfully downloaded: $firmware_file"
}

main() {
  parse_args "$@"

  echo "###########################################"
  echo "#         ColdCard MK4 Firmware           #"
  echo "###########################################"
  echo ""

  check_dependencies
  check_ck_public_key
  download_firmware
}

main "$@"
