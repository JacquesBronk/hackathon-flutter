# Cash Me Outside — Walking Skeleton Design (Bureau kickoff #1)

**Date:** 2026-08-01
**Status:** Approved
**Parent spec:** [README.md](../../../README.md) (full product design)
**Build executor:** The Bureau (task graph; workers have Flutter preinstalled, no real devices)

---

## 1. Goal & scope

Build one end-to-end demoable slice of Cash Me Outside:

1. User onboards: name + avatar, Ed25519 keypair generation ("minting your wallet"), biometric enrollment.
2. User sees their wallet: balance hero, recent activity.
3. Pinnies move between two devices via QR: recipient shows a QR, sender scans it,
   confirms with biometrics, both ledgers update after the sender's signed-transaction
   QR is scanned back (or shared) — fully offline.

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

### 2.1 `lib/domain/`

- `Transaction` — `{ id (UUIDv7), type (mint|transfer), from, to, amount, memo,
  lamportTs, signature }`. Amounts are **integer pinnies** only.
- **Ledger** — grow-only CRDT set of signed transactions. Merge = set union keyed on
  `id`, dropping any transaction whose signature fails verification. Balances are
  derived by replaying the full set. Double-spend is allowed by design (fake money);
  forgery is not.
- **Lamport clock** — per-device counter: `max(local, highestSeen) + 1` on each new
  transaction.
- **Canonical signing bytes** — UTF-8 of compact JSON (no whitespace, keys sorted
  alphabetically) of `{ amount, from, id, lamportTs, memo, to, type }`. The signature
  field is excluded. Ed25519 via the `cryptography` package (pure Dart — runs in
  tests without a device).
- **Mint rule** — onboarding creates one self-signed mint transaction
  (`type: mint`, `from == to == self`, amount ᵽ500). Balances therefore derive purely
  from replay; no special-cased starting balance. Mint transactions are only valid
  when `from == to` and are accepted once per wallet address (first-by-lamportTs wins
  on replay; duplicates ignored).

### 2.2 `lib/ports/`

| Port | Responsibility |
|---|---|
| `KeyVault` | store/retrieve the Ed25519 private key; expose public key |
| `BiometricGate` | `Future<bool> authenticate(reason)` — app unlock + pre-signing |
| `QrScanner` | stream of decoded payload strings from the camera |
| `LedgerStore` | persist/load the transaction set + seen Lamport high-water mark |

### 2.3 `lib/adapters/` (plugin-backed)

`flutter_secure_storage` → KeyVault, `local_auth` → BiometricGate,
`mobile_scanner` → QrScanner, `drift` (SQLite) → LedgerStore. Verify current plugin
versions at build time — do not pin from this spec.

### 2.4 `lib/fakes/`

- `InMemoryKeyVault`
- `FakeBiometricGate` — approves after a short delay (configurable to deny, for
  failure-path tests)
- `FakeQrScanner` — emits injected payloads on demand
- `InMemoryLedgerStore`

Selection: `--dart-define=FAKE_HARDWARE=true` swaps all adapters for fakes via
Riverpod provider overrides, so the entire app runs headless (tests) or in a browser.
Default (no define) uses real adapters.

### 2.5 `lib/theme/`

Design tokens from the README's visual direction:

- **Palette:** counterfeit-bill green `#3E6B4F` + aged-paper cream `#F2EBD9` base;
  hazard orange `#FF5A1F` reserved for money-in-motion; ink navy `#1E2733` text;
  brass `#C9A54A` for the coin.
- **Type:** chunky slab/stencil display face for amounts and headers, clean grotesque
  for body, tabular figures wherever numbers appear.
- **Pinnie coin widget:** CustomPainter brass coin with one light flip animation.
  This is the design system's through-line; later graphs extend it (pour streams,
  rain confetti) rather than adding new assets.

Screens are real but animation-light in this pass. Full polish (hero transitions,
spring physics, haptics) is a later graph.

---

## 3. QR payload formats

`cmo:` URI scheme wrapping base64url-encoded compact JSON. Two payload kinds:

1. **Receive-request** — `cmo:rr:<base64url({ v: 1, addr, name, amount? })>`.
   Shown on the Receive screen; `amount` optional.
2. **Signed-transaction** — `cmo:tx:<base64url(full transaction JSON incl. signature)>`.
   A complete transfer envelope. In this slice it closes the loop: after the sender
   signs, their device shows this QR and the recipient scans it to ingest the
   transaction into their ledger. It is also the future sneakernet/voucher format.

Unknown scheme/kind/version → friendly "not a pinnie code" error, never a crash.

---

## 4. Screens & flows

1. **Onboarding** (3 screens, < 30s): name + avatar pick (preset avatars only — no
   photo upload in this slice) → keypair generation with a
   "minting your wallet" moment (coin flip + mint transaction created) → biometric
   enrollment (via `BiometricGate`).
2. **Wallet (home):** balance hero (derived from ledger replay), recent activity list,
   one Send button that opens a radial menu — **only QR enabled**; the other seven
   methods are visible but greyed with a "soon" affordance (menu is a plain fan-out;
   drag-gesture polish comes later).
3. **Send (QR):** scan recipient's receive-request → confirm screen (amount, optional
   memo, coin, recipient name) → `BiometricGate.authenticate` → sign → show
   signed-transaction QR for the recipient to scan → success state.
4. **Receive:** show own receive-request QR (optional amount entry); scanning the
   sender's signed-transaction QR ingests + verifies it; received state updates
   balance.
5. **History:** ledger view, newest first, entries expandable (id, counterparty,
   memo, lamportTs).

App unlock: `BiometricGate` gates entry to the wallet on every cold start after
onboarding.

---

## 5. Error handling

- Signature verification failure on ingest → transaction rejected, non-blocking
  "counterfeit pinnies rejected" notice.
- Biometric failure/cancel → stay on confirm screen, allow retry; no signing occurs.
- Malformed/unknown QR → friendly error state.
- Duplicate transaction ingest (same `id`) → silently idempotent.
- Storage errors surface as a retryable error state, never data loss (ledger is
  append-only; writes are transactional in drift).

---

## 6. Verification bar (gates every Bureau task)

1. `dart format --set-exit-if-changed .` clean
2. `flutter analyze` clean
3. `flutter test` green, including at minimum:
   - **Domain unit tests:** ledger merge (union, dedupe, forged-signature rejection),
     balance replay (incl. mint rule + duplicate-mint rejection), Lamport clock
     behavior, canonical-bytes stability (property-style: encode→sign→verify round
     trips), QR payload encode/decode round trips incl. malformed input.
   - **Widget tests:** full onboard → send → receive → history flow against fakes,
     biometric-denied path, malformed-QR path.
4. Final integration task additionally: `flutter build apk --debug` succeeds and the
   APK path is reported.

Human hardware pass (sideload APK; real biometrics, camera, secure storage on a
physical Android device) happens after the graph completes — workers never claim
device verification.

---

## 7. Bureau graph shape (sketch)

Final graph is authored at kickoff after `bureau_discover` confirms engine
capabilities. Intended shape — approximately 7 tasks in 3 waves:

- **Wave 1 (parallel):**
  - T1: Flutter scaffold, CI-ish task runner script, theme tokens + coin widget.
  - T2: domain layer (transaction, ledger, clock, crypto, QR codecs) + unit tests.
- **Wave 2 (parallel, after W1):**
  - T3: ports + fakes + drift/secure-storage/local_auth/mobile_scanner adapters.
  - T4: onboarding + wallet home features.
  - T5: send/receive/history features.
  - (T4/T5 use file locks to avoid collisions; both build against T2's domain and
    T3's ports-with-fakes.)
- **Wave 3:**
  - T6: integration — wire real adapters behind the FAKE_HARDWARE switch, end-to-end
    widget flow test, APK build gate.
  - T7: gated review — independent reviewer task on domain + integration; workers'
    green is not trusted without it.

---

## 8. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Scope | Walking skeleton only | De-risk architecture; mandatory requirement met end-to-end first |
| UI depth | Design system + basic coin now | Later waves build on tokens instead of retrofitting |
| Acceptance | format + analyze + tests + debug-APK gate | Headless-verifiable by agents; human does device pass |
| Architecture | Ports-and-adapters + Riverpod | Domain stays pure Dart; hardware swaps to fakes for agent testing |
| State of build env | Bureau workers have Flutter | Confirmed by owner; validate with `bureau_discover` at kickoff |
| Money | Integer pinnies, mint-at-onboarding ᵽ500 | Pure replay-derived balances, no special cases |
