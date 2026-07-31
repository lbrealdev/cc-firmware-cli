# COLDCARD RNG / Seed Entropy Incident — Situation and Impact

| Field | Value |
| --- | --- |
| Investigation id | `coldcard-rng-seed-entropy-2026` |
| Document | Situation and impact (File 1 of 2) |
| Companion | [01-TECHNICAL-ANALYSIS.md](01-TECHNICAL-ANALYSIS.md) |
| Incident window (public disclosure) | 2026-07-30 (Coinkite fixed-release update 2026-07-31) |
| Document status | Synthesis of public sources (includes Coinkite technical deep dive + fixed Mk3/Edge releases) |
| Scope of this repo | Documentation only — this project does not generate seeds or talk to devices |

---

## 1. Status banner

**What is happening:** Public reports and vendor advisories describe a COLDCARD firmware random-number-generation (RNG) integration failure that can leave newly generated wallet seeds with far less entropy than users expect. Funds associated with such seeds may be recoverable by an attacker who can sufficiently constrain device and timing state and validate candidates against a known address, xpub, or public key.

**Why this document exists:** This repository (`cc-firmware-cli`) automates official firmware download/verification. The incident is recorded here, outside product `docs/`, so the investigation is visible in-repo without conflating it with this tool’s own trust model.

| Claim | Attribution | Confidence for this investigation |
| --- | --- | --- |
| Mk3 seeds generated on firmware **4.0.1–4.1.9** may put funds at risk | Coinkite | High (vendor advisory) |
| Mk3 affected effective search space ≈ **40 bits** under current attack assumptions | Coinkite (technical deep dive) | High as vendor estimate; Coinkite marks it preliminary and subject to change |
| Mk4 / Mk5 / Q before fixed Standard/Edge releases affected (~**72 bits** vs expected 128) | Coinkite | High (vendor advisory + technical deep dive) |
| Strong unique BIP-39 passphrase is an **interim** barrier only; migrate to a new seed as soon as practical | Coinkite | High (vendor advisory); weak/common passphrases may be guessable |
| Root cause is libngu binding to MicroPython Yasmarang fallback; Mk4+ SE mixing / reseed did not restore 128-bit security | Coinkite + Block | High for code-path analysis; Block states full empirical exploit testing was not completed |
| Active exploitation is under way | Block | Stated by Block; not independently verified by this repository |
| Fixed releases: Mk3 **4.2.0+**; Mk4/Mk5 Standard **5.6.0+** / Edge **6.6.0X+**; Q Standard **1.5.0Q+** / Edge **6.6.0QX+** | Coinkite (2026-07-31 update) | High (vendor hotfix release) |
| TAPSIGNER, OPENDIME, SATSCARD unaffected | Coinkite | High (different codebases) |

> **Important:** Coinkite published a [technical deep dive](https://blog.coinkite.com/entropy-technical-backgrounder/) confirming the root cause (~40-bit Mk3 / ~72-bit Mk4/Q/Mk5 under current assumptions) and, on **2026-07-31**, confirmed fixed firmware for **every** affected model/track including Mk3 **4.2.0**. Block’s analysis remains explicitly preliminary on full empirical exploit testing. Where sources differ in framing, both are retained and attributed.

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
| Mk3 | **4.0.1–4.1.9** inclusive | Confirmed vulnerable path; no SE reseed; Coinkite warns funds may be at risk; vendor estimate ≈ **40 bits** (preliminary) |
| Mk4 | Production before Standard **5.6.0** or Edge **6.6.0X** | Fallback remains; SE mixing/reseed limited (Block: 32-bit reseed); Coinkite: ≈ **72 bits** vs expected 128 |
| Q | Production before Standard **1.5.0Q** or Edge **6.6.0QX** | Same Mk4-class construction (Block); Coinkite: ≈ **72 bits** |
| Mk5 | Production before Standard **5.6.0** or Edge **6.6.0X** | Same current Mk construction (Block); Coinkite: ≈ **72 bits** |

### 3.2 Products Coinkite states are not affected

| Product | Status |
| --- | --- |
| TAPSIGNER | Not affected (different codebase) |
| OPENDIME | Not affected (different codebase) |
| SATSCARD | Not affected (different codebase) |

### 3.3 Fixed firmware targets (Coinkite, updated 2026-07-31)

| Device | Standard track | Edge track |
| --- | --- | --- |
| Mk3 | **4.2.0** or later | — |
| Mk4 | **5.6.0** or later | **6.6.0X** or later |
| Mk5 | **5.6.0** or later | **6.6.0X** or later |
| Q | **1.5.0Q** or later | **6.6.0QX** or later |

Standard and Edge are separate release tracks. If you use Edge, install the fixed Edge build for your model. Do not assume an older Edge 6.x is fixed merely because its version number is higher than the Standard release (Coinkite).

Do not generate a new seed until the update is installed. Updating does **not** repair a seed already generated on affected firmware.

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
| Seed generated on Mk3 **4.0.1–4.1.9** (or Mk2 v4.x affected path), **no** dice / unknown dice count | Treat as **at risk** | Upgrade to fixed firmware → **new** seed → migrate (see §7) |
| Same, but **Add Dice Rolls** with **≥ 50** fair, independent, private rolls | Coinkite: dice alone contributed ≥ 128 bits; **not considered at risk from this RNG issue alone** | Still verify your own operational certainty; migrate if rolls may have been exposed or count is uncertain |
| Same, with **≥ 99** fair, independent, private rolls | Coinkite: dice alone ≈ 256 bits | Same as above |
| Seed generated on Mk4 / Mk5 / Q before fixed Standard or Edge release, without sufficient private dice | Treat as **at risk** (reduced entropy) | Upgrade on the correct track → new seed → migrate |
| Seed generated on Mk2/Mk3 **through v3.2.2** using the then-current HW RNG path | Outside this regression per Block | No action required **for this bug**; keep normal operational hygiene |
| Seed was **imported** from an external BIP-39 source that you trust was generated safely | Device RNG path not the origin of the secret | This bug does not rewrite an imported seed; risk follows the original generation method |
| Affected seed with a **strong, unique BIP-39 passphrase** | Interim independent barrier (Coinkite); weak/common/patterned/quoted/reused may be guessable | **Still migrate as soon as practical**; never enter passphrase on untrusted devices/websites |
| Only the COLDCARD **PIN** was used (no BIP-39 passphrase) | PIN is not a substitute for seed entropy or a passphrase barrier | Follow migration guidance; consider strong passphrase only as interim while preparing new seed |
| Multisig where **every** cosigner key was generated on affected firmware | Arrangement remains exposed (Block) | Replace vulnerable cosigner keys; ensure quorum includes safely generated keys |
| Multisig with at least one safely generated key required in every spend | Reduces impact of a single weak cosigner, depending on policy | Still replace weak keys; do not assume “multisig = immune” |
| Paper wallet / random XOR split / other `ngu.random` features used under affected firmware | May inherit the same entropy limits (Block) | See technical companion; treat generated material as suspect |

If you are uncertain which firmware created the seed, how many dice rolls you entered, or whether rolls stayed private: **migrate**.

---

## 6. What a firmware upgrade does and does not fix

| Action | Effect on an **existing** seed | Effect on **future** seed generation |
| --- | --- | --- |
| Upgrade Mk3 to ≥ **4.2.0** | Does **not** repair the old seed | New seeds use the corrected path (Coinkite) |
| Upgrade Mk4/Mk5 to Standard ≥ **5.6.0** or Edge ≥ **6.6.0X** | Does **not** repair the old seed | Same |
| Upgrade Q to Standard ≥ **1.5.0Q** or Edge ≥ **6.6.0QX** | Does **not** repair the old seed | Same |
| Exporting the old seed to Sparrow, Electrum, another hardware wallet, etc. | Seed remains the same weak secret | N/A |

Mk3 can complete migration alone after installing **4.2.0+**. Do not generate a replacement seed until fixed firmware is confirmed on-device (Coinkite).

---

## 7. Migration guidance (calm sequence)

Rushing a migration can create a more immediate loss than the entropy defect. Coinkite’s operational sequence, synthesized. Decision-tree overview: [README.md](README.md#migration-decision-tree).

### 7.1 Real exit — fixed firmware, then a new seed (all models)

Applies to at-risk seeds on **Mk3**, **Mk4**, **Mk5**, and **Q** (unless the ≥50 private-dice exception applies).

1. [Upgrade the firmware](https://coldcard.com/docs/upgrade/) on the correct track **before** generating any new seed (see §3.3). Confirm the version on-device.
2. Generate a **completely new** seed on the updated COLDCARD.
3. On fixed firmware, the device-generated seed is sufficient; dice rolls are optional for addressing this issue. A BIP-39 passphrase on the **new** wallet is a separate security choice (Coinkite).
4. Back up the new seed and any passphrase carefully. Store the passphrase separately from the seed words.
5. Power-cycle the COLDCARD and verify the wallet fingerprint (XFP) and a receive address on the device screen.
6. Send a **small test transaction**; confirm receipt in the new wallet.
7. Move the remaining funds.
8. Keep the old backup until the entire migration is confirmed.

**Mk3 one-device note (Coinkite):** Using one Mk3 for both old and new wallets requires carefully switching seeds. Prefer a second device with fixed firmware if available. Verify written backup and XFP of the affected seed before erasing; alternate restore/verify steps with a small test transaction before moving the remainder.

Updating firmware does **not** repair a seed generated by affected firmware. A new seed must be generated and funds migrated (Coinkite).

### 7.2 Interim barrier — strong BIP-39 passphrase (any at-risk seed)

This is **not** the real exit. Coinkite: if an affected seed was used with a **strong, unique** BIP-39 passphrase, that passphrase adds an independent barrier. Short, common, patterned, quoted, or reused passphrases may be guessable and should not be assumed to help. This means a BIP-39 passphrase, **not** the COLDCARD PIN.

**Even with a strong passphrase, migrate to a newly generated seed as soon as practical** (Coinkite). Treat the passphrase as a time bridge while you prepare the §7.1 exit — not as a permanent custody plan.

If you need that interim step before you can finish a full migration:

1. Read official [COLDCARD BIP-39 passphrase docs](https://coldcard.com/docs/passphrase/) before starting.
2. On the device, create or apply a **long, random, unique** BIP-39 passphrase. Enter it only on the COLDCARD.
3. Back up the passphrase exactly and **separately** from the seed words.
4. Apply passphrase; record the wallet’s eight-digit fingerprint (XFP).
5. Power-cycle, re-enter passphrase, confirm the same XFP.
6. Export to your coordinator; verify receive address on the COLDCARD screen.
7. If moving funds into the passphrase wallet from the no-passphrase view of the same seed: small test first, then the remainder.

Every passphrase (including typos) creates a different valid wallet. Verify XFP every time before sending. Never enter the passphrase on a website or untrusted device.

### 7.3 Optional advanced path — dice-only seed (after Mk3 4.2.0+)

After updating to **4.2.0+**, users who want a replacement seed that does not use the device RNG can use dice-only. This is **optional**; normal `New Wallet` is corrected in 4.2.0 (Coinkite).

- On an **empty** Mk3 running **4.2.0+**, select `Import Existing > Dice Rolls`.
- Enter **≥ 99** independent rolls of a fair six-sided die.
- This path hashes the roll sequence directly; it does not use the device generator.
- Never photograph rolls, store them digitally, or type them into a networked computer.
- One-device migration still requires careful alternation between old and new seeds; verify backups/XFPs and use a small test transaction.

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
| BIP-39 passphrase (strong, unique) | **Interim** independent barrier only; still migrate ASAP (Coinkite) |
| BIP-39 passphrase (weak/common/reused) | May be guessable; do not assume meaningful protection (Coinkite) |
| COLDCARD PIN | Unlocks the device; **not** a passphrase and **not** a seed-entropy fix |

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
| 2026-07-30 | Coinkite publishes technical deep dive; initial hotfixes for Mk4/Mk5/Q | Coinkite |
| 2026-07-31 | Coinkite confirms fixed firmware for all tracks: Mk3 **4.2.0**, Standard **5.6.0** / **1.5.0Q**, Edge **6.6.0X** / **6.6.0QX** | Coinkite |

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
| Mk3 fixed firmware **4.2.0** | **Released** (Coinkite 2026-07-31 update); corrects new seed generation only |
| Edge fixed releases **6.6.0X** / **6.6.0QX** | **Released** (Coinkite 2026-07-31 update) |
| Independent reproduction by this repository | **Not performed** — this package synthesizes public sources |

**Synthesis (this investigation):** An LLFOURN attack-cost model analysis is listed under [canonical sources](README.md#canonical-sources).

---

## 13. Primary sources

Canonical source list for this investigation package: **[README.md — Canonical sources](README.md#canonical-sources)**.

This file keeps operational inline links (for example upgrade/passphrase/dice URLs in migration steps) and does not duplicate the full URL table.

Migration decision tree (Mk*/Q Yes/No paths): **[README.md — Migration decision tree](README.md#migration-decision-tree)**.

---

## 14. Document control

| Version | Date | Notes |
| --- | --- | --- |
| 1.0 | 2026-07-31 | Initial investigation package in this repository |
| 1.1 | 2026-07-31 | Incorporate Coinkite technical deep dive; add upgrade docs link; refresh status/estimates |
| 1.2 | 2026-07-31 | Add COLDCARD Mk4 vs Mk3 docs link (hardware/model background) |
| 1.3 | 2026-07-31 | Point primary sources to folder README; decision tree lives in README |
| 1.4 | 2026-07-31 | Sync Mk3 4.2.0 + Edge fixed releases; reframe passphrase as interim for any at-risk seed |

Attribution legend used throughout:

- **Coinkite** — claim from Coinkite’s Mk3 advisory and/or technical deep dive
- **Block** — claim from Block’s engineering post
- **Synthesis** — organizational framing in this investigation (no new exploit claims)
