# Contributing

Contributions are welcome with one hard constraint:

**This project strictly follows official Coinkite documentation.**

The goal is to automate the official verification process, not invent a new one.

## In scope

- Bug fixes and reliability improvements to existing behavior
- Clearer errors and safer UX around the existing flow
- Support for newly released ColdCard models when they appear in official manifests
- Documentation clarifications that reference official sources

## Out of scope

- New verification methods not documented by Coinkite / ColdCard
- Alternative download or signature sources
- “Enhanced” security checks beyond the official recommendations
- Device install or hardware interaction features

Please open an issue before submitting significant changes.

## Development checks

Before opening a pull request:

```shell
mise run lint
mise run smoke
```

Or:

```shell
bash -n cc_firmware.sh
shellcheck cc_firmware.sh
./tests/smoke.sh
```
