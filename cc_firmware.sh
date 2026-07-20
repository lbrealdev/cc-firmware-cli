#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_VERSION=""
FIRMWARE_FILE=""
ASSUME_YES=0

# COINKITE CONFIG VARIABLES
COINKITE_PGP_PUBLIC_KEY="0xA3A31BAD5A2A5B10"
# Full fingerprint for Peter D. Gray <peter@coinkite.com> / Coinkite key 0xA3A31BAD5A2A5B10
COINKITE_PGP_FINGERPRINT="4589779ADFC14F3327534EA8A3A31BAD5A2A5B10"
COINKITE_GITHUB_REPO="Coldcard/firmware"

CURL_MAX_TIME_FIRMWARE=300
CURL_MAX_TIME_SIGNATURES=60

HASH_CMD=()

show_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME --version <X.Y.Z> [--yes|-y]

Download and verify ColdCard MK4 firmware.

Options:
  --version <X.Y.Z>  Firmware version to download (required)
  --yes, -y          Skip confirmation when other .dfu files exist
  --help, -h         Show this help and exit
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    echo "Error: --version is required"
    show_usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        show_usage
        exit 0
        ;;
      --version)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          FIRMWARE_VERSION="$2"
          shift 2
        else
          echo "Error: --version requires a version in X.Y.Z format (e.g., 5.4.1)"
          exit 1
        fi
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      *)
        echo "Error: Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done

  if [[ -z "$FIRMWARE_VERSION" ]]; then
    echo "Error: --version is required"
    show_usage
    exit 1
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" > /dev/null; then
    echo "Error: $cmd is not installed or not in PATH."
    exit 1
  fi
}

resolve_hash_command() {
  if command -v sha256sum > /dev/null; then
    HASH_CMD=(sha256sum)
  elif command -v shasum > /dev/null; then
    HASH_CMD=(shasum -a 256)
  else
    echo "Error: Neither sha256sum nor shasum is installed or in PATH."
    exit 1
  fi
}

file_sha256() {
  local file="$1"
  "${HASH_CMD[@]}" "$file" | awk '{print $1}'
}

check_dependencies() {
  require_command gpg
  require_command curl
  require_command git
  require_command awk
  require_command grep
  resolve_hash_command
}

get_key_fingerprint() {
  # Return fingerprint if the pinned Coinkite key is present in the keyring.
  gpg --batch --no-tty --list-keys --with-colons "$COINKITE_PGP_FINGERPRINT" 2>/dev/null \
    | awk -F: -v expected="$COINKITE_PGP_FINGERPRINT" '
        $1 == "fpr" && $10 == expected { print $10; exit }
      '
}

import_ck_public_key() {
  curl -fsS --max-time "$CURL_MAX_TIME_SIGNATURES" \
    "https://keyserver.ubuntu.com/pks/lookup?op=get&search=$COINKITE_PGP_PUBLIC_KEY" \
    | gpg --batch --import -q
}

# Check if the Coinkite public key is imported and matches the pinned fingerprint.
check_ck_public_key() {
  echo "Checking Coinkite PGP key..."

  local key_fingerprint
  key_fingerprint="$(get_key_fingerprint || true)"

  if [[ -z "$key_fingerprint" ]]; then
    echo "  Key not found, importing from keyserver..."
    import_ck_public_key

    key_fingerprint="$(get_key_fingerprint || true)"

    if [[ -z "$key_fingerprint" ]]; then
      echo "Error: Failed to import Coinkite public key with fingerprint $COINKITE_PGP_FINGERPRINT."
      exit 1
    fi
  fi

  if [[ "$key_fingerprint" != "$COINKITE_PGP_FINGERPRINT" ]]; then
    echo "Error: Unexpected PGP fingerprint."
    echo "  Expected: $COINKITE_PGP_FINGERPRINT"
    echo "  Found:    $key_fingerprint"
    exit 1
  fi

  echo "✓ Key ready: $key_fingerprint"
}

resolve_firmware_tag() {
  local version="$1"
  local matches=()
  local sha ref tag

  while read -r sha ref; do
    [[ -z "${ref:-}" ]] && continue
    [[ "$ref" == *'^{}' ]] && continue
    [[ "$ref" == refs/tags/* ]] || continue

    tag="${ref#refs/tags/}"
    if [[ "$tag" == "$version" || "$tag" == "v$version" || "$tag" == *"-v$version" ]]; then
      matches+=("$tag")
    fi
  done < <(git ls-remote -t "https://github.com/${COINKITE_GITHUB_REPO}.git")

  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "Error: Version $version not found."
    echo ""
    echo "You can find available firmware versions at:"
    echo "  - GitHub releases: https://github.com/Coldcard/firmware/tags"
    echo "  - Coldcard downloads: https://coldcard.com/downloads/mk4"
    exit 1
  fi

  if [[ ${#matches[@]} -gt 1 ]]; then
    echo "Error: Multiple tags match version $version:"
    local match
    for match in "${matches[@]}"; do
      echo "  - $match"
    done
    exit 1
  fi

  printf '%s\n' "${matches[0]}"
}

confirm_download() {
  local firmware_file="$1"

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Error: Refusing to prompt without a TTY. Re-run with --yes to confirm download of:"
    echo "  $firmware_file"
    exit 1
  fi

  echo "You requested: $firmware_file"
  echo ""
  local response
  read -r -p "Download requested version? (y/N): " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
  fi
}

download_firmware() {
  local _firmware_version="$1"
  local firmware_platform="mk4-coldcard"
  local firmware_ext="dfu"

  echo ""
  echo "Validating firmware version $_firmware_version..."

  local ck_firmware_version
  ck_firmware_version="$(resolve_firmware_tag "$_firmware_version")"

  echo "✓ Version found on GitHub: $ck_firmware_version"

  local firmware_file="${ck_firmware_version}-${firmware_platform}.${firmware_ext}"
  local firmware_url="https://coldcard.com/downloads/${firmware_file}"

  # Check for existing .dfu files
  local existing_dfu
  existing_dfu=$(find . -maxdepth 1 -name "*.dfu" -type f 2>/dev/null || true)

  if [[ -n "$existing_dfu" ]]; then
    local dfu_count
    dfu_count=$(printf '%s\n' "$existing_dfu" | wc -l | tr -d ' ')
    echo ""
    echo "Found $dfu_count firmware file(s) in current directory:"
    while read -r file; do
      [[ -z "$file" ]] && continue
      echo "  - $(basename "$file")"
    done <<< "$existing_dfu"
    echo ""

    if [[ -f "$firmware_file" ]]; then
      echo "Requested version already exists: $firmware_file"
      echo "Skipping download."
      FIRMWARE_FILE="$firmware_file"
      return 0
    fi

    confirm_download "$firmware_file"
  fi

  echo ""
  echo "Downloading firmware..."

  if ! curl -fsSLo "$firmware_file" --max-time "$CURL_MAX_TIME_FIRMWARE" "$firmware_url"; then
    echo "Error: Failed to download firmware."
    exit 1
  fi

  echo "> $firmware_file"

  FIRMWARE_FILE="$firmware_file"
}

download_signature() {
  local signatures_url="https://raw.githubusercontent.com/$COINKITE_GITHUB_REPO/master/releases/signatures.txt"
  local signatures_file="signatures.txt"

  echo ""
  echo "Downloading signatures..."

  # Remove old signature file if exists (always download fresh)
  if [[ -f "$signatures_file" ]]; then
    echo "  Removing old signature file..."
    rm -f "$signatures_file"
  fi

  if ! curl -fsSLo "$signatures_file" --max-time "$CURL_MAX_TIME_SIGNATURES" "$signatures_url"; then
    echo "Error: Failed to download signatures file from $signatures_url"
    exit 1
  fi

  if [[ ! -s "$signatures_file" ]]; then
    echo "Error: Downloaded signatures file is empty."
    rm -f "$signatures_file"
    exit 1
  fi

  echo "> $signatures_file"
}

verify_signatures_file() {
  echo ""
  echo "Verifying PGP signature..."

  local status_file
  status_file="$(mktemp)"
  local verify_rc=0

  # Capture machine-readable status; show human-readable verify output on failure.
  if ! gpg --batch --no-tty --status-file "$status_file" --verify signatures.txt >/dev/null 2>&1; then
    verify_rc=1
  fi

  local good_signature=0
  local signer_fpr=""
  local primary_fpr=""

  while IFS= read -r line; do
    if [[ "$line" == '[GNUPG:] GOODSIG '* ]]; then
      good_signature=1
    elif [[ "$line" == '[GNUPG:] VALIDSIG '* ]]; then
      # VALIDSIG fields: fingerprint ... primary-key-fpr (last field)
      signer_fpr="$(awk '{print $3}' <<< "$line")"
      primary_fpr="$(awk '{print $NF}' <<< "$line")"
    fi
  done < "$status_file"

  if [[ "$verify_rc" -ne 0 || "$good_signature" -ne 1 || -z "$primary_fpr" ]]; then
    echo "Error: Failed to verify signatures.txt PGP signature."
    gpg --batch --no-tty --verify signatures.txt 2>&1 || true
    rm -f "$status_file"
    exit 1
  fi

  if [[ "$primary_fpr" != "$COINKITE_PGP_FINGERPRINT" && "$signer_fpr" != "$COINKITE_PGP_FINGERPRINT" ]]; then
    echo "Error: signatures.txt was not signed by the pinned Coinkite key."
    echo "  Expected: $COINKITE_PGP_FINGERPRINT"
    echo "  Found:    ${primary_fpr:-$signer_fpr}"
    rm -f "$status_file"
    exit 1
  fi

  rm -f "$status_file"
  echo "✓ Signature valid ($primary_fpr)"
}

verify_firmware_hash() {
  echo ""
  echo "Verifying firmware hash..."

  if [[ ! -f "$FIRMWARE_FILE" ]]; then
    echo "Error: Firmware file not found: $FIRMWARE_FILE"
    exit 1
  fi

  local actual_hash
  actual_hash="$(file_sha256 "$FIRMWARE_FILE")"
  echo "  Actual:   $actual_hash"

  local expected_hash
  expected_hash="$(
    awk -v filename="$FIRMWARE_FILE" '
      $1 ~ /^[0-9a-fA-F]{64}$/ && $2 == filename { print $1; exit }
    ' signatures.txt
  )"

  if [[ -z "$expected_hash" ]]; then
    echo "Error: Firmware file not found in signatures.txt"
    exit 1
  fi

  echo "  Expected: $expected_hash"

  if [[ "$actual_hash" == "$expected_hash" ]]; then
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
  download_signature
  verify_signatures_file
  download_firmware "$FIRMWARE_VERSION"
  verify_firmware_hash
}

main "$@"
