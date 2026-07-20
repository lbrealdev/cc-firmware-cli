# cc-firmware-cli

A small Bash tool that automates ColdCard firmware **download and verification** using only the steps documented by Coinkite.

Manually verifying firmware means fetching the right `.dfu`, authenticating Coinkite’s signed `signatures.txt`, and checking SHA-256 hashes. This script does that path for you so you are less likely to grab the wrong file or mis-compare a hash. It does not invent new security checks.

## Quick start

```shell
./cc_firmware.sh --version <X.Y.Z> [options]
```

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

## Trust model

Two phases, in this order:

1. **Authenticate the manifest** — download `signatures.txt` from the official ColdCard firmware repo and verify its PGP signature with Coinkite’s pinned public key.
2. **Check firmware integrity** — resolve the matching `.dfu` name from that verified manifest, download it from coldcard.com, and confirm its SHA-256 matches the manifest entry.

Details: [docs/VERIFICATION.md](docs/VERIFICATION.md).

## What this tool does

- Downloads firmware only from official ColdCard / Coinkite sources
- Verifies the PGP signature on `signatures.txt`
- Resolves MK / MK4 / Q1 (and factory) filenames from the verified manifest
- Validates the firmware SHA-256 against that manifest

## What this tool does not do

- Install firmware on a ColdCard
- Talk to the device in any way
- Replace understanding the official verification steps
- Guarantee safety if official keys, hosts, or your machine are compromised

## Disclaimer

This project is **not affiliated with Coinkite Inc. or ColdCard**. It automates the official verify-then-download path only. Use at your own risk; see [LICENSE](LICENSE) (MIT, no warranty). Prefer reading [docs/SECURITY.md](docs/SECURITY.md) and the official Coinkite docs before relying on it.

## Documentation

- [Security & threat model](docs/SECURITY.md)
- [Verification flow](docs/VERIFICATION.md)
- [Contributing](CONTRIBUTING.md)

### Official Coinkite resources

- Documentation: https://coldcard.com/docs/
- Downloads: https://coldcard.com/downloads/
- Firmware repo: https://github.com/Coldcard/firmware
- PGP key id: `0xA3A31BAD5A2A5B10`

### Related reading

Independent write-ups that discuss firmware verification culture (not affiliated with this project or Coinkite):

- https://binarywatch.org/
- https://x.com/BinaryWatchBot
