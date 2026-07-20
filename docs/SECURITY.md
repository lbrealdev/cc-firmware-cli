# Security

This tool is intentionally narrow: automate Coinkite’s documented firmware download and verification steps. It does not claim to be a complete security product.

## Trust assumptions

- Coinkite’s published PGP key is authentic and not compromised.
- Official hosts serve the expected artifacts:
  - `https://raw.githubusercontent.com/Coldcard/firmware/...` for `signatures.txt`
  - `https://coldcard.com/downloads/` for `.dfu` files
  - Ubuntu keyserver for importing the Coinkite public key when needed
- Your local machine (shell, `gpg`, `curl`, disk) is not hostile.

If those assumptions fail, automation cannot save you.

## What the script pins

| Item | Value |
|---|---|
| Key id | `0xA3A31BAD5A2A5B10` |
| Full fingerprint | `4589779ADFC14F3327534EA8A3A31BAD5A2A5B10` |

The script imports and verifies against that fingerprint. Confirm it matches Coinkite’s published key before trusting a run.

List a locally imported key:

```shell
gpg --list-keys --keyid-format=long | grep -B2 -A1 "coinkite"
```

## Network surface

The script only initiates requests to:

- Ubuntu keyserver (PGP key fetch)
- `raw.githubusercontent.com` / `github.com` for the Coldcard firmware project (`signatures.txt`)
- `coldcard.com` for firmware downloads

It does not use third-party mirrors or alternate signature sources.

## What this does not protect against

- A compromised Coinkite signing key or official distribution infrastructure
- Malware on the machine running the script (can alter downloads, `gpg`, or the script itself)
- You installing firmware after a failed or skipped verification
- Social engineering that tricks you into running a modified copy of this repository

## How to audit

1. Read [`cc_firmware.sh`](../cc_firmware.sh) end to end — it is a single Bash file on purpose.
2. Compare each network call and check to [official ColdCard documentation](https://coldcard.com/docs/).
3. Confirm the pinned fingerprint above matches Coinkite’s published key.
4. Prefer `--dry-run` first to inspect the resolved filename, URL, and expected hash without fetching the `.dfu`.

Even if you trust this repository, understand the steps it automates.
