# Cash Me Outside — Walking Skeleton Design (Bureau kickoff #1)

**Date:** 2026-08-01 (rev 2 — hardened after 3-lens adversarial review)
**Status:** Approved
**Parent spec:** [README.md](../../../README.md) (full product design)
**Build executor:** The Bureau (task graph; workers have Flutter, no real devices)

---

## 1. Goal & scope

Build one end-to-end demoable slice of Cash Me Outside:

1. User onboards: name + preset avatar, Ed25519 keypair generation ("minting your
   wallet"), biometric check + first authenticate.
2. User sees their wallet: balance hero, recent activity.
3. Pinnies move between two devices via QR, fully offline: recipient shows a
   receive-request QR → sender scans, confirms with biometrics, signs → sender shows a
   signed-transaction QR → recipient scans it back. Both ledgers update.

This slice satisfies the hackathon's **mandatory biometrics requirement** plus QR +
camera coverage. Everything else is upside delivered by later Bureau graphs.

### Out of scope (later graphs)

BLE direct/mesh, NFC (HCE + NTAG), all sensors (pour, shake, radar/compass), chat,
radar screen, notifications, contacts, calendar, voice, settings screen, photo memos,
responsive tablet/desktop layouts. The architecture seams below exist so these slot in
as new adapters + features without refactoring.

---

## 2. Architecture

**Pattern: ports-and-adapters, Riverpod for wiring.** Single Flutter app at repo root.
The domain layer never imports a plugin; every hardware capability is a Dart interface
with a fake (for headless tests and agent development) and a plugin-backed adapter
(verified on real hardware by a human).

```
lib/
  domain/     # pure Dart, zero Flutter/plugin imports
  ports/      # abstract interfaces for hardware/persistence
  adapters/   # plugin-backed implementations of ports
  fakes/      # in-memory / scripted implementations of ports
  features/   # UI + Riverpod state per feature
  theme/      # design tokens + pinnie coin widget
```

### 2.1 Domain: transactions & wire encodings

`Transaction` fields — all encodings are **normative**:

| Field | Encoding |
|---|---|
| `id` | UUIDv7 via the `uuid` package (^4.x, `v7()`), canonical lowercase-hyphenated string |
| `type` | `"mint"` or `"transfer"` |
| `from`, `to` | **address = base64url without padding of the raw 32-byte Ed25519 public key** |
| `amount` | Dart `int`, integer pinnies. **Valid range: `1 ≤ amount ≤ 2^53 − 1`** (web-safe) |
| `memo` | string; **always present in the signed object, `null` when empty**; bytes signed as received, no unicode normalization |
| `lamportTs` | Dart `int` |
| `signature` | base64url without padding of the raw 64-byte Ed25519 signature |

**Canonical signing bytes (pinned implementation):** insert the keys
`amount, from, id, lamportTs, memo, to, type` in that (alphabetical) order into a
`LinkedHashMap`, encode with `dart:convert`'s `jsonEncode`. `signature` is excluded.
Verifiers MUST re-canonicalize from parsed fields — never trust the envelope's byte
layout. Ed25519 via the `cryptography` package (pure Dart; verified maintained).

**Signature validity:** the signature MUST verify against the public key **decoded
from the `from` field**. Anything else is forgery and is rejected.

### 2.2 Domain: ledger rules

- **Ledger** = grow-only CRDT set of transactions, **keyed on the SHA-256 of the
  canonical signing bytes** (not on `id` — two different validly-signed transactions
  sharing an `id` must both survive, or devices diverge). Merge = set union on that
  key; ingest of an already-present key is silently idempotent.
- **Ingest validation** (applies on creation, QR ingest, and merge): signature valid
  per §2.1; `amount` in range; `type` ∈ {mint, transfer}. Transactions with an
  unknown `type` that otherwise verify are **retained but ignored during replay**
  (forward compatibility).
- **Replay order (total, deterministic):** ascending `(lamportTs, id)` with `id`
  compared bytewise. All balance derivation uses this order on every device.
- **Mint rule (protocol constants):** a mint is valid only when `from == to` **and
  `amount == 500`**. At most one mint per address counts: the first in replay order
  wins; later mints for the same address are ignored during replay.
- **Lamport clock:** per-device counter, `max(local, highestSeen) + 1` on each new
  transaction; high-water mark persisted.
- **Balances:** derived purely by replay. **Negative balances are permitted and
  displayed as negative; sends are never blocked by balance** (double-spend is a
  feature; forgery is not).

### 2.3 Ports (`lib/ports/`)

| Port | Responsibility |
|---|---|
| `KeyVault` | store/retrieve the Ed25519 private key; expose public key |
| `BiometricGate` | `Future<bool> authenticate(reason)` — app unlock + pre-signing; adapter uses `biometricOnly: false` (device-credential fallback) |
| `QrScanner` | stream of decoded payload strings **and the camera preview widget** (`Widget buildPreview(...)`) — the UI never imports the scanner plugin directly |
| `LedgerStore` | persist/load the transaction set + Lamport high-water mark |
| `ProfileStore` | display name, avatar id, onboarding-complete flag |
| `PeerDirectory` | local name cache keyed by address, populated from scanned receive-request QRs; UI falls back to truncated address |

### 2.4 Adapters (`lib/adapters/`, plugin-backed)

`flutter_secure_storage` → KeyVault, `local_auth` → BiometricGate, `mobile_scanner` →
QrScanner, `drift` (SQLite) → LedgerStore + PeerDirectory, `shared_preferences` (or
drift) → ProfileStore. Verify current plugin versions at build time.

**Android integration requirements (owned by T1, verified by the review task —
these pass every automated gate silently when missing and crash on-device):**

- `MainActivity` extends **`FlutterFragmentActivity`** (local_auth requirement;
  default scaffold uses `FlutterActivity`).
- Launch theme parented on a **`Theme.AppCompat`** descendant (local_auth).
- Manifest: `USE_BIOMETRIC` + `CAMERA` permissions; `android:allowBackup="false"`
  (secure-storage restore corruption).
- `minSdk 24`, `compileSdk 36` set explicitly (current plugin floors — re-verify at
  kickoff against the worker's Flutter version).
- `applicationId`: `dev.jcqb.cashmeoutside`.

### 2.5 Fakes (`lib/fakes/`)

`InMemoryKeyVault`, `FakeBiometricGate` (configurable `Duration` delay **defaulting
to `Duration.zero`**, configurable approve/deny), `FakeQrScanner` (emits injected
payloads; preview renders a placeholder box), `InMemoryLedgerStore`,
`InMemoryProfileStore`, `InMemoryPeerDirectory`.

**Selection:** widget tests construct `ProviderScope(overrides: [...fakes])`
explicitly. `--dart-define=FAKE_HARDWARE=true` selects fakes for `flutter run`
(browser/desktop click-through); it is **not** part of the test gate.

### 2.6 Theme (`lib/theme/`)

- **Palette:** counterfeit-bill green `#3E6B4F` + aged-paper cream `#F2EBD9` base;
  hazard orange `#FF5A1F` reserved for money-in-motion; ink navy `#1E2733` text;
  brass `#C9A54A` for the coin.
- **Fonts (bundled as assets — never `google_fonts` runtime fetch, which breaks the
  airplane-mode demo):** **Alfa Slab One** (OFL) for display/amounts, **Inter** (OFL)
  for body and all numerals with `FontFeature.tabularFigures()`.
- **Avatars:** preset set of 12 emoji glyphs rendered on a brass coin disc — no image
  assets, no photo upload.
- **Pinnie coin widget:** CustomPainter brass coin with one light flip animation —
  **finite, single-run** (looping controllers hang `pumpAndSettle`).

Screens are real but animation-light. Full polish is a later graph.

---

## 3. QR payload formats

Versioned scheme prefixes, base64url **without padding**, compact JSON:

1. **Receive-request** — `cmo:rr1:<base64url({ addr, name, amount? })>`. Shown on the
   Receive screen; `amount` optional. `name` is **unauthenticated** — any screen
   displaying it MUST show the truncated address alongside.
2. **Signed-transaction** — `cmo:tx1:<base64url(full transaction JSON incl.
   signature)>`. Ingest runs full §2.2 validation. Also the future
   sneakernet/voucher format.

Unknown scheme, kind, or version → friendly "not a pinnie code" error, never a crash.

---

## 4. Screens & flows

1. **Onboarding** (3 screens, < 30s): name + preset avatar → keypair generation with
   a "minting your wallet" moment (coin flip + mint transaction) → biometric step:
   check availability, first `authenticate` with device-credential fallback; if
   nothing is enrolled, show a "go enroll in Settings" state with skip-with-warning.
   Profile + onboarded flag persist via `ProfileStore`.
2. **Wallet (home):** balance hero (replay-derived; negatives render as negative),
   recent activity, Send button opening a radial menu — **only QR enabled**, the
   other seven greyed "soon". Plain fan-out; drag-gesture polish later.
3. **Send (QR):** scan recipient's rr QR (records name → `PeerDirectory`) → confirm
   screen (amount, optional memo, coin, recipient name **with truncated address**) →
   `BiometricGate.authenticate` → sign → **sender ingests the transaction into their
   own ledger immediately at signing** → show the `cmo:tx1:` QR for the recipient to
   scan → **success is a manual "Done" dismissal** (offline: no ack signal exists).
4. **Receive:** shows own rr QR (optional amount entry) with an explicit **"scan
   sender's code" button that swaps the QR view for the scanner**; scanning the tx QR
   validates + ingests; received state updates balance.
5. **History:** display order **newest-first by UUIDv7 timestamp** (`lamportTs` shown
   only in expanded detail — Lamport isn't chronological across devices). Entries
   expandable: id, counterparty (PeerDirectory name or truncated address), memo,
   lamportTs. **Transfer entries can re-display their `cmo:tx1:` QR** — the recovery
   path when a recipient failed to scan (sender is already debited; the pinnies must
   remain deliverable).

App unlock: `BiometricGate` gates entry on every cold start after onboarding.

---

## 5. Error handling

- Signature/validation failure on ingest → rejected, non-blocking "counterfeit
  pinnies rejected" notice.
- Biometric failure/cancel → stay on confirm screen, allow retry; no signing occurs.
- Malformed/unknown QR → friendly error state.
- Duplicate ingest (same canonical-bytes hash) → silently idempotent.
- Storage errors → retryable error state, never data loss (append-only; drift
  writes transactional).

---

## 6. Verification bar

**The T1 task-runner script (`tool/check.sh`) IS the gate** — every task must run it
green, in this order (drift codegen must precede format/analyze; generated files are
committed post-format and excluded from analysis via `analysis_options.yaml`):

1. `dart run build_runner build --delete-conflicting-outputs`
2. `dart format --set-exit-if-changed .`
3. `flutter analyze` (with `**/*.g.dart` excluded in `analysis_options.yaml`)
4. `flutter test`

Required test coverage:

- **Domain unit tests:** merge/convergence (union, canonical-bytes-hash dedupe,
  id-collision case, forged-signature rejection, wrong-key rejection), replay
  determinism under permuted merge orders, mint rule (amount≠500 rejected,
  duplicate-mint tie-break by `(lamportTs, id)`), amount range validation (0,
  negative, > 2^53−1), Lamport clock, canonical-bytes stability
  (encode→sign→verify round trips incl. null/unicode memos), QR codec round trips
  incl. malformed/unknown-version input.
- **Widget tests:** full two-party flow **with the test playing the counterparty** —
  the test generates a second Ed25519 keypair, crafts valid `cmo:rr1:`/`cmo:tx1:`
  payloads, injects them via `FakeQrScanner`, and asserts both ledger directions in
  one app instance. Plus: biometric-denied path, malformed-QR path,
  onboarding-persistence path. All via explicit `ProviderScope` fake overrides.

**Final integration task additionally:** `flutter build apk --debug` succeeds; APK
path reported. **Fallback:** if the Wave-1 probe found no Android toolchain in the
Bureau environment, the APK gates are dropped from the graph and the owner builds
locally (`flutter build apk --debug` on their machine) for the device pass — the
tests/format/analyze gates still bind every task.

### Human device pass (after the graph; workers never claim device verification)

Sideload the APK on a physical Android device and verify: real biometric unlock +
signing gate (incl. a device with no biometrics enrolled → fallback path), camera
scanning both QR kinds, secure-storage persistence across restarts, tabular figure
rendering (not machine-testable — `flutter test` renders Ahem), and **rehearse the
two-scan choreography** (show rr → scan → show tx → scan back) including the
recovery: botch the second scan, then deliver via History → re-show tx QR.

---

## 7. Bureau graph shape (sketch)

Final graph is authored at kickoff after `bureau_discover`. **T1 owns all shared
surfaces** — `pubspec.yaml` (complete dependency list below), `main.dart`, router
(named-route placeholders for all five screens), the Riverpod provider-override
scaffold, everything under `android/`, fonts/assets, and `tool/check.sh`. All other
tasks only add files under their own directories.

Dependency list (T1, verify versions at kickoff): `flutter_riverpod`, `cryptography`,
`uuid`, `drift` + `drift_flutter`/`sqlite3_flutter_libs`, `flutter_secure_storage`,
`local_auth`, `mobile_scanner`, `qr_flutter` (QR *rendering* — not behind a port),
`shared_preferences`; dev: `build_runner`, `drift_dev`, `flutter_test`.

- **Wave 1 — T1 "probe + foundation":** toolchain probe (`flutter doctor -v`,
  `java -version`, record Flutter/Dart versions, throwaway-scaffold
  `flutter build apk --debug`, drift `NativeDatabase.memory()` smoke test — the APK
  gate needs Android SDK + licenses + Java 17+ + Gradle network access, which
  "workers have Flutter" does not imply; **if the Android toolchain is missing, the
  APK gates are dropped per §6's fallback — the owner builds locally — and the graph
  proceeds**); then real scaffold with §2.4 Android config, theme tokens + coin widget,
  shared surfaces, `tool/check.sh`, and a committed bare-app APK build proof.
- **Wave 2 (parallel):** **T2** domain (§2.1–2.2 + unit tests) ∥ **T3** ports +
  fakes (§2.3, §2.5 + tests). Both pure-Dart/Flutter-only against T1's pubspec.
- **Wave 3 (parallel):** **T4** plugin adapters (§2.4) ∥ **T5** onboarding + wallet
  home ∥ **T6** send/receive/history. T5/T6 build against fakes only, so T4 runs
  alongside; file locks per feature directory.
- **Wave 4:** **T7** integration — real-adapter wiring behind FAKE_HARDWARE,
  two-party flow test, APK gate → **T8** gated review (independent reviewer;
  checklist: canonical-bytes conformance, ledger/mint rules vs §2.2, QR formats vs
  §3, fake/adapter parity per port, §2.4 Android config present, `tool/check.sh`
  actually run by every task). Workers' green is not trusted without T8.

---

## 8. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Scope | Walking skeleton only | De-risk architecture; mandatory requirement met end-to-end first |
| UI depth | Design system + basic coin now | Later waves build on tokens instead of retrofitting |
| Acceptance | check.sh gates + debug-APK gate + human device pass | Headless-verifiable by agents; hardware truths land on the human pass |
| Architecture | Ports-and-adapters + Riverpod | Domain stays pure Dart; hardware swaps to fakes for agent testing |
| Build env | Bureau workers have Flutter; **Wave-1 probe verifies the rest**; owner can build the APK locally if the env can't | "Has Flutter" ≠ has Android SDK/Java/Gradle network; local build covers the device pass either way |
| Money | Integer pinnies; mint ᵽ500 as a replay-enforced protocol constant | Pure replay-derived balances; no mint-amount forgery |
| Ledger key | SHA-256 of canonical signing bytes | id-collision cannot fork the CRDT |
| Replay order | Ascending `(lamportTs, id)`, id bytewise | Deterministic balances across devices |
| Negative balances | Allowed and displayed | Double-spend is a feature; behavior must be uniform |
| Fonts | Bundled Alfa Slab One + Inter (OFL) | Offline demo; tabular figures; no runtime fetch |

### Rev 2 changes (adversarial review, 2026-08-01)

Three parallel review lenses (protocol/crypto, Flutter/toolchain, flows/decomposition)
produced 7 blockers + 12 majors, all folded in above: ledger keyed on canonical-bytes
hash; `(lamportTs, id)` total order + mint constants; address/signature encodings
pinned and verification bound to `from`; amount range validation; pinned JSON
canonicalizer; toolchain probe + Wave-1 APK proof; local_auth scaffold requirements;
explicit-override test wiring; scanner preview behind the port; codegen-aware gate
order; two-party test harness; stranded-transaction recovery (re-show tx QR) + manual
Done; ProfileStore + PeerDirectory ports; bundled fonts/avatars; Android config
ownership; ports/fakes moved ahead of features in the graph; T1 owns all shared
surfaces.
