# cc-firmware-cli

A command-line tool to automate ColdCard firmware download and verification.

## Why This Tool Exists

Manually downloading and verifying ColdCard firmware involves multiple steps: finding the correct firmware file, downloading the signed signatures manifest, verifying PGP signatures, and comparing SHA-256 hashes. This script automates the entire workflow, ensuring you get authentic, uncorrupted firmware for your ColdCard device.

## ⚠️ Important Notice

**This project is not affiliated with Coinkite Inc. or ColdCard.**

I am an independent user who follows the security practices recommended in the official ColdCard documentation. This tool automates the manual verification steps documented by Coinkite, following the principle: **"Don't trust, verify."**

### What This Tool Does
- Automates downloading firmware from official ColdCard sources
- Verifies PGP signatures using Coinkite's official public key
- Validates SHA-256 hashes against the signed manifest

### What This Tool Does NOT Do
- Install firmware on your ColdCard device
- Interact with the device in any way
- Replace the manual verification steps (you should still understand them)
- Guarantee security (always verify independently)

### Security Notice
- This script implements **only the first part** of the firmware process (download + verification)
- **Installing firmware on your device is at your own risk**
- Always cross-reference with official documentation
- This tool follows official Coinkite documentation - nothing more, nothing less

### Security Audit

This script is designed to be transparent and auditable:
- **Review the code**: All functionality is in a single bash script - read it before running
- **Verify independently**: Cross-check every step against official ColdCard documentation
- **PGP key verification**: The script shows which key it imports - verify it matches Coinkite's official key
- **No secrets**: The script doesn't handle private keys, seeds, or sensitive data
- **Network calls**: Only connects to official sources (coldcard.com, GitHub/Coldcard repos, Ubuntu keyserver)

**Recommendation**: Even if you trust this script, understand what it does by reading the source code and official documentation.

### Official Resources
All references in this repository link to official Coinkite resources:
- Documentation: https://coldcard.com/docs/
- Downloads: https://coldcard.com/downloads/
- GitHub: https://github.com/Coldcard/firmware
- PGP Key: 0xA3A31BAD5A2A5B10

### License & Liability
- **Use at your own risk**
- No warranty or guarantee provided
- Not responsible for device damage, fund loss, or security issues
- Always verify independently before use

## How It Works

The script follows a two-phase verification process based on Coinkite's security model:

### Phase 1: Trust (PGP Signature Verification)
The script downloads `signatures.txt` from ColdCard's official GitHub repository and verifies it using Coinkite's PGP public key (0xA3A31BAD5A2A5B10). This cryptographically proves the file originated from Coinkite and hasn't been tampered with during transmission.

### Phase 2: Integrity (Hash Verification)
Once the signatures file is authenticated, the script verifies your downloaded firmware's SHA-256 hash matches the value listed in the manifest. This ensures the firmware file wasn't corrupted during download or modified by a third party.

### Verification Methods

**Official Method (Coinkite Recommended):**
Coinkite recommends manually verifying the PGP signature with `gpg --verify` and visually comparing the SHA-256 hash from `signatures.txt` against your downloaded firmware. This educational approach helps users understand the security model.

**Automated Method (This Script):**
The script automates both verification steps. It extracts the hash/filename pairs from the authenticated `signatures.txt` and programmatically validates your firmware against them using standard hash verification tools. This provides the same security guarantees as the manual method while eliminating human error in hash comparison.

## Usage

```shell
./cc_firmware.sh --version <X.Y.Z> [options]
```

The script downloads and PGP-verifies `signatures.txt`, resolves the matching `.dfu` from that manifest, then downloads and hash-checks the firmware.

```shell
# MK production build (default model)
./cc_firmware.sh --version 5.5.1

# Preview resolved file/URL/hash without downloading firmware
./cc_firmware.sh --version 5.5.1 --dry-run

# Q1 production build
./cc_firmware.sh --version 1.4.1 --model q1

# Factory build
./cc_firmware.sh --version 5.5.1 --factory

# Non-interactive confirm when other .dfu files are present
./cc_firmware.sh --version 5.5.1 --yes
```

Options: `--model mk|q1` (default `mk`), `--factory`, `--dry-run`, `--yes`/`-y`, `--help`/`-h`.

## Checking Coinkite Key

```shell
gpg --list-keys --keyid-format=long | grep -B2 -A1 "coinkite"
```

## References

- https://x.com/BinaryWatchBot
- https://binarywatch.org/

## Development

Before opening a PR, run the local lint/smoke checks:

```shell
mise run lint
mise run smoke
```

Or equivalently:

```shell
bash -n cc_firmware.sh
shellcheck cc_firmware.sh
./tests/smoke.sh
```

## Contributing

Contributions are welcome, with one important constraint:

**This project strictly follows official Coinkite documentation.**

- Only implement verification methods documented by ColdCard
- No custom or "improved" security checks that deviate from official procedures
- All network requests must go to official Coinkite/GitHub sources
- Documentation updates should reference official sources only

**What this means:**
- ✅ Bug fixes and improvements to existing functionality
- ✅ Better error messages and user experience
- ✅ Support for new officially-released ColdCard models
- ✅ Documentation clarifications with official references
- ❌ New verification methods not in official docs
- ❌ Alternative download sources
- ❌ "Enhanced" security beyond official recommendations

The goal is to automate the official process, not invent new ones.

Please open an issue before submitting significant changes.
