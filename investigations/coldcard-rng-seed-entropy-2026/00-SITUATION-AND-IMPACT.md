# COLDCARD RNG / Seed Entropy Incident — Situation and Impact

| Field | Value |
| --- | --- |
| Investigation id | `coldcard-rng-seed-entropy-2026` |
| Document | Situation and impact (File 1 of 2) |
| Companion | [01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md) |
| Incident window (public disclosure) | 2026-07-30 |
| Document status | Synthesis of public sources (includes Coinkite technical deep dive) |
| Scope of this repo | Documentation only — this project does not generate seeds or talk to devices |

---

## 1. Status banner

**What is happening:** Public reports and vendor advisories describe a COLDCARD firmware random-number-generation (RNG) integration failure that can leave newly generated wallet seeds with far less entropy than users expect. Funds associated with such seeds may be recoverable by an attacker who can sufficiently constrain device and timing state and validate candidates against a known address, xpub, or public key.

**Why this document exists:** This repository (`cc-firmware-cli`) automates official firmware download/verification. The incident is recorded here, outside product `docs/`, so the investigation is visible in-repo without conflating it with this tool’s own trust model.

| Claim | Attribution | Confidence for this investigation |
| --- | --- | --- |
| Mk3 seeds generated on firmware 4.0.1+ may put funds at risk | Coinkite | High (vendor advisory) |
| Mk3 affected effective search space ≈ **40 bits** under current attack assumptions | Coinkite (technical deep dive) | High as vendor estimate; Coinkite marks it preliminary and subject to change |
| Mk4 / Mk5 before 5.6.0 and Q before 1.5.0Q affected (~**72 bits** vs expected 128) | Coinkite | High (vendor advisory + technical deep dive) |
| Root cause is libngu binding to MicroPython Yasmarang fallback; Mk4+ SE mixing / reseed did not restore 128-bit security | Coinkite + Block | High for code-path analysis; Block states full empirical exploit testing was not completed |
| Active exploitation is under way | Block | Stated by Block; not independently verified by this repository |
| Emergency hotfixes 5.6.0 (Mk4/Mk5) and 1.5.0Q (Q) generate entropy correctly | Coinkite | High (vendor hotfix release) |
| TAPSIGNER, OPENDIME, SATSCARD unaffected | Coinkite | High (different codebases) |

> **Important:** Coinkite published a [technical deep dive](https://blog.coinkite.com/entropy-technical-backgrounder/) on 2026-07-30 confirming the root cause and giving ~40-bit (Mk3) / ~72-bit (Mk4/Q/Mk5) search-space estimates under current assumptions. Block’s analysis remains explicitly preliminary on full empirical exploit testing. Where sources differ in framing, both are retained and attributed.

---

## 2. Plain-language summary

COLDCARD devices are expected to generate wallet secrets using strong hardware entropy. Beginning with firmware that switched seed generation onto the `ngu.random` path (released as v4.0.0 / March 2021), that path can fail to consume the intended STM32 hardware RNG.

Instead, under the production board configuration, the library can fall back to a **deterministic software PRNG** (Yasmarang) seeded from chip identity and timer registers. On newer devices (Mk4 / Q / Mk5), boot adds secure-element material, but only **32 bits** of that material effectively reseed the generator.

**Practical consequence:** A seed that users believed had 128- or 256-bit strength may belong to a much smaller candidate set. An attacker with enough side information and a public address/xpub can search that set offline and steal funds if they recover the seed or private key.

This is **not** a bug in this CLI tool. It concerns secrets generated **on device** under affected firmware.

---

## 3. Affected products and firmware

Exposure depends on the **firmware version used when the secret was generated**, not the manufacturing date of the unit, and not the firmware version installed later. Upgrading firmware does **not** repair an already-generated seed.

### 3.1 Device / firmware matrix

| Device | Firmware used when generating the secret | Assessment (public sources) |
| --- | --- | --- |
| Mk1 | All released through v3.0.6 | Outside this regression (Block) |
| Mk2 | Through v3.2.2 | Uses direct STM32 hardware RNG (Block) |
| Mk2 | v4.0.0–v4.1.9 | Confirmed vulnerable path; no secure reseed (Block) |
| Mk3 | Through v3.2.2 | Uses direct STM32 hardware RNG (Block) |
| Mk3 | v4.0.0–v4.1.9 (Coinkite highlights 4.0.1+) | Confirmed vulnerable path; no SE reseed; Coinkite warns funds may be at risk; vendor estimate ≈ **40 bits** (preliminary) |
| Mk4 | Production v5.0.0 onward, before **5.6.0** | Fallback remains; SE mixing/reseed limited (Block: 32-bit reseed); Coinkite: ≈ **72 bits** vs expected 128 |
| Q | All production firmware before **1.5.0Q** | Same Mk4-class construction (Block); Coinkite: ≈ **72 bits**; fixed target: 1.5.0Q+ |
| Mk5 | All production firmware before **5.6.0** | Same current Mk construction (Block); Coinkite: ≈ **72 bits**; fixed target: 5.6.0+ |

### 3.2 Products Coinkite states are not affected

| Product | Status |
| --- | --- |
| TAPSIGNER | Not affected (different codebase) |
| OPENDIME | Not affected (different codebase) |
| SATSCARD | Not affected (different codebase) |

### 3.3 Fixed firmware targets (Coinkite)

| Device | Minimum fixed firmware for **new** seed generation |
| --- | --- |
| Mk4 | 5.6.0 or later |
| Mk5 | 5.6.0 or later |
| Q | 1.5.0Q or later |
| Mk3 | No fixed release confirmed in the preliminary advisory; Coinkite may explore one final release only if a safe upgrade path exists |

---

## 4. Severity by generation path

| Path | Entropy picture (public analysis) | Fund-theft implication |
| --- | --- | --- |
| Mk2 / Mk3 on v4.x (no secure reseed) | For known UID, timer state, and RNG call history, wallet generation can be **deterministic** (Block). Coinkite estimates ≈ **40 bits** effective search space under current attack assumptions (preliminary). | Highest severity among COLDCARD seed paths described in the public reports |
| Mk4 / Q / Mk5 with SE mixing / 32-bit reseed | At most \(2^{32}\) securely distinguished RNG streams once fallback state and call history are fixed (Block). Coinkite estimates ≈ **72 bits** instead of expected **128**. | Serious; better than Mk3 in Coinkite’s framing, still far below the intended security target |
| Seed exported from a vulnerable COLDCARD to another wallet | Same insecure seed remains affected (Block) | Moving the seed does not heal it |
| Multisig composed only of vulnerable keys | Quorum of vulnerable keys does not neutralize the issue (Block) | Need a quorum of keys that were generated safely |

Detailed search-space tables: [01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md).

---

## 5. “Am I at risk?” decision table

Use the firmware version **at seed creation**, not today’s version.

| Situation | Risk from this RNG issue alone | Recommended action |
| --- | --- | --- |
| Seed generated on Mk3 with firmware **4.0.1+** (or Mk2/Mk3 v4.0.0–v4.1.9), **no** dice / unknown dice count | Treat as **at risk** | Migrate to a new seed on fixed firmware (or dice-only path if Mk3-only) |
| Same, but **Add Dice Rolls** with **≥ 50** fair, independent, private rolls | Coinkite: dice alone contributed ≥ 128 bits; **not considered at risk from this RNG issue alone** | Still verify your own operational certainty; migrate if rolls may have been exposed or count is uncertain |
| Same, with **≥ 99** fair, independent, private rolls | Coinkite: dice alone ≈ 256 bits | Same as above |
| Seed generated on Mk4 / Mk5 before **5.6.0**, or Q before **1.5.0Q**, without sufficient private dice | Treat as **at risk** (reduced entropy) | Upgrade device, generate new seed, migrate funds carefully |
| Seed generated on Mk2/Mk3 **through v3.2.2** using the then-current HW RNG path | Outside this regression per Block | No action required **for this bug**; keep normal operational hygiene |
| Seed was **imported** from an external BIP-39 source that you trust was generated safely | Device RNG path not the origin of the secret | This bug does not rewrite an imported seed; risk follows the original generation method |
| Seed used with a **strong, unique BIP-39 passphrase** | Passphrase is an independent barrier; weak/common passphrases may be guessable (Coinkite) | Do not rely on passphrase forever; migrate when practical; never enter passphrase on untrusted devices/websites |
| Only the COLDCARD **PIN** was used (no BIP-39 passphrase) | PIN is not a substitute for seed entropy | Follow migration guidance |
| Multisig where **every** cosigner key was generated on affected firmware | Arrangement remains exposed (Block) | Replace vulnerable cosigner keys; ensure quorum includes safely generated keys |
| Multisig with at least one safely generated key required in every spend | Reduces impact of a single weak cosigner, depending on policy | Still replace weak keys; do not assume “multisig = immune” |
| Paper wallet / random XOR split / other `ngu.random` features used under affected firmware | May inherit the same entropy limits (Block) | See technical companion; treat generated material as suspect |

If you are uncertain which firmware created the seed, how many dice rolls you entered, or whether rolls stayed private: **migrate**.

---

## 6. What a firmware upgrade does and does not fix

| Action | Effect on an **existing** seed | Effect on **future** seed generation |
| --- | --- | --- |
| Upgrade Mk4/Mk5 to ≥ 5.6.0 | Does **not** repair the old seed | New seeds on fixed firmware should use the corrected path (per Coinkite fixed releases) |
| Upgrade Q to ≥ 1.5.0Q | Does **not** repair the old seed | Same |
| Possible future Mk3 update | Cannot repair an already-generated weak seed (Coinkite) | Only relevant for new generation if/when published |
| Exporting the old seed to Sparrow, Electrum, another hardware wallet, etc. | Seed remains the same weak secret | N/A |

**Do not wait** for a possible Mk3 firmware release before protecting funds if migration guidance applies (Coinkite).

---

## 7. Migration guidance (calm sequence)

Rushing a migration can create a more immediate loss than the entropy defect. Coinkite’s operational sequence, synthesized:

### 7.1 Preferred path (Mk4 / Mk5 / Q available)

1. [Upgrade the firmware](https://coldcard.com/docs/upgrade/) before generating any new seed: Mk4/Mk5 **≥ 5.6.0**, or Q **≥ 1.5.0Q**. Confirm the version on-device.
2. Generate a **completely new** seed on the updated COLDCARD.
3. On fixed firmware, the device-generated seed is sufficient to address this issue; dice rolls are optional. A BIP-39 passphrase remains a separate wallet-security choice (Coinkite technical deep dive).
4. Back up the new seed and any passphrase carefully. Store the passphrase separately from the seed words.
5. Power-cycle the COLDCARD and verify the wallet fingerprint (XFP) and a receive address on the device screen.
6. Send a **small test transaction**; confirm receipt in the new wallet.
7. Move the remaining funds.
8. Keep the old backup until the entire migration is confirmed.

Updating firmware does **not** repair a seed generated by affected firmware. A new seed must be generated and funds migrated (Coinkite).

### 7.2 Interim measure if Mk3 is the only option (BIP-39 passphrase)

Coinkite describes this as an interim barrier until migration to a new seed on unaffected firmware is possible:

1. Read official COLDCARD BIP-39 passphrase docs before starting.
2. On the Mk3, create a **long, random, unique** BIP-39 passphrase (not a quote, name, or reused password). Enter it only on the COLDCARD.
3. Back up the passphrase exactly and **separately** from the seed words.
4. Apply passphrase; record the new wallet’s eight-digit fingerprint (XFP).
5. Power-cycle, re-enter passphrase, confirm the same XFP.
6. Export to your coordinator; verify receive address on the Mk3 screen.
7. Return to the original wallet (no passphrase), send a small test to the verified address; confirm under the passphrase wallet before moving the rest.

Every passphrase (including typos) creates a different valid wallet. Verify XFP every time before sending.

### 7.3 Advanced Mk3-only fallback: dice-only seed

If Mk3 is the only device and you can execute a careful one-device migration:

- On an **empty** Mk3 running **4.1.9**, use `Import Existing > Dice Rolls`.
- Enter **≥ 99** independent rolls of a fair six-sided die.
- This dedicated path hashes the roll sequence directly and does **not** use the device generator.
- Do **not** use normal `New Wallet` if the goal is to exclude the device RNG.
- Never photograph rolls, store them digitally, or type them into a networked computer.
- Verify backups and XFPs for both old and new seeds before erasing either; use a small test transaction.

---

## 8. Dice rolls and passphrase — detail

### 8.1 Dice

| Dice rolls entered via **Add Dice Rolls** | Coinkite entropy claim (dice contribution) | Stance on this RNG bug |
| --- | --- | --- |
| ≥ 50 and < 99, fair + private | ≥ 128 bits from dice alone | Not considered at risk from this RNG issue alone |
| ≥ 99, fair + private | ≈ 256 bits from dice alone | Same |
| < 50, or unknown, or rolls may have been exposed | Insufficient / uncertain | Follow migration guidance |

Applies to the **final** seed words shown after dice were added.

### 8.2 Passphrase vs PIN

| Mechanism | Role in this incident |
| --- | --- |
| BIP-39 passphrase | Independent secret; can raise cost of theft if strong and unique |
| COLDCARD PIN | Unlocks the device; **not** a replacement for seed entropy |

---

## 9. High-level public timeline

| Date | Event | Source |
| --- | --- | --- |
| 2021-01-28 | Vulnerable libngu STM32 guard pattern already present | Block |
| 2021-03-01 | COLDCARD migrates wallet generation toward libngu / `random.bytes` | Block |
| 2021-03-17 | Firmware **v4.0.0** ships with vulnerable generation path | Block |
| 2022-03-11 – 2022-03-14 | 32-bit reseed API and Mk4 production v5.0.0 include reseed | Block |
| 2026-07-30 | Reports of COLDCARD users losing funds; Block and others investigate | Block |
| 2026-07-30 | Coinkite publishes Mk3 security advisory | Coinkite |
| 2026-07-30 | Block discloses findings to Coinkite and publishes technical report | Block |
| 2026-07-30 | Coinkite publishes technical deep dive; emergency hotfixes **5.6.0** / **1.5.0Q** | Coinkite |

Full technical timeline with commit references: [01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md#12-technical-timeline).

---

## 10. Other features that may inherit weak RNG

Seed generation is the highest-visibility impact. Block also lists other consumers of `ngu.random`, including:

- Ephemeral / paper-wallet secp256k1 private keys
- Random seed XOR masks
- Some cloning, USB, Key Teleport, and Web2FA ECDH material
- Generated Secure Notes passwords
- HSM local-code material

Callers that use `ckcc.rng_bytes` instead reach the separate STM32 hardware-RNG implementation. Feature-by-feature notes: [01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md#9-other-affected-functionality).

---

## 11. Relationship to this repository

| Topic | Fact |
| --- | --- |
| Product | `cc-firmware-cli` downloads and verifies official `.dfu` files |
| Affiliation | Not affiliated with Coinkite Inc. |
| Role in this incident | None in seed generation; documentation only |
| Why document here | Users of this tool care about COLDCARD firmware provenance; the July 2026 advisory is operationally relevant when choosing firmware versions for **new** wallets |
| Not in `docs/` | Keeps product threat-model docs (`docs/SECURITY.md`) separate from third-party incident investigation |

Verifying a fixed firmware image with this tool does **not** by itself migrate funds. After download/verify, install per Coinkite’s [upgrade instructions](https://coldcard.com/docs/upgrade/), confirm version on-device, then generate a **new** seed.

---

## 12. Caveats and open items

| Item | Status |
| --- | --- |
| Coinkite formal technical deep dive | **Published** (2026-07-30): https://blog.coinkite.com/entropy-technical-backgrounder/ |
| Coinkite Mk3 ≈ 40-bit search-space estimate | Preliminary; Coinkite says it may change as analysis continues |
| Block full empirical exploit testing | Not completed (per Block) |
| Exact Mk3 RTC/SysTick distributions in the field | Pending hardware validation (Block) |
| Whether ordinary SE failures can skip reseed in production | Conditional / not established (Block) |
| Final Mk3 firmware release | Under consideration only if safe (Coinkite Mk3 advisory) |
| Independent reproduction by this repository | **Not performed** — this package synthesizes public sources |

**Synthesis (this investigation):** An LLFOURN attack-cost model analysis is referenced in the technical companion ([01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md) §15).

---

## 13. Primary sources

| Source | URL | Role |
| --- | --- | --- |
| Coinkite — Mk3 Security Advisory | https://blog.coinkite.com/coldcard-mk3-seed-generation-warning/ | Vendor user guidance, affected versions, migration, dice/passphrase |
| Coinkite — Technical Deep Dive into the Entropy Issue | https://blog.coinkite.com/entropy-technical-backgrounder/ | Vendor root-cause confirmation, ~40/~72-bit estimates, hotfix notes |
| Block Engineering — Predictable RNG Fallback and 32-Bit Reseed | https://engineering.block.xyz/blog/predictable-rng-fallback-and-32-bit-reseed-in-coldcard-firmware | Independent technical root cause, search spaces, feature blast radius |
| COLDCARD firmware upgrade docs | https://coldcard.com/docs/upgrade/ | Official install/upgrade procedure before generating a new seed |
| COLDCARD Mk4 vs Mk3 docs | https://coldcard.com/docs/coldcard-mk4/ | Hardware/model background (dual secure elements, Mk4 capabilities) |
| COLDCARD firmware downloads | https://coldcard.com/downloads/ | Firmware versions (incl. 5.6.0 / 1.5.0Q hotfixes) |
| COLDCARD BIP-39 passphrase docs | https://coldcard.com/docs/passphrase/ | Interim passphrase procedure |
| COLDCARD dice-roll method | https://coldcard.com/docs/verifying-dice-roll-math/ | Dice-only verification reference |
| COLDCARD firmware source | https://github.com/Coldcard/firmware | Code paths cited by Block and Coinkite |

---

## 14. Document control

| Version | Date | Notes |
| --- | --- | --- |
| 1.0 | 2026-07-31 | Initial investigation package in this repository |
| 1.1 | 2026-07-31 | Incorporate Coinkite technical deep dive; add upgrade docs link; refresh status/estimates |
| 1.2 | 2026-07-31 | Add COLDCARD Mk4 vs Mk3 docs link (hardware/model background) |

Attribution legend used throughout:

- **Coinkite** — claim from Coinkite’s Mk3 advisory and/or technical deep dive
- **Block** — claim from Block’s engineering post
- **Synthesis** — organizational framing in this investigation (no new exploit claims)
