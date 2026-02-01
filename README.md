# cc-firmware-cli

A command-line tool to automate ColdCard firmware download and verification.

## Why This Tool Exists

Manually downloading and verifying ColdCard firmware involves multiple steps: finding the correct firmware file, downloading the signed signatures manifest, verifying PGP signatures, and comparing SHA-256 hashes. This script automates the entire workflow, ensuring you get authentic, uncorrupted firmware for your ColdCard device.

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
./cc_firmware.sh --version <X.Y.Z>
```

Example:
```shell
./cc_firmware.sh --version 5.4.1
```

## Checking Coinkite Key

```shell
gpg --list-keys --keyid-format=long | grep -B2 -A1 "coinkite"
```

## References

- https://x.com/BinaryWatchBot
- https://binarywatch.org/
