# Graph C — NFC (HCE Tap + NTAG Stickers + Vouchers) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. This plan is the source for Bureau graph C; plan Task N = Bureau task CN. **Declared after Graph A promotes** (runs in parallel with Graph B — file sets are disjoint; C must NOT touch any file B's plan assigns to B).

**Goal:** Tap-to-pay: Android↔Android HCE (receiver emulates a tag carrying its payment request), NTAG payment stickers (pay-the-owner), and claimable voucher stickers (`cmo:v1:` throwaway-key sweep — "stick ᵽ50 under a chair").

**Normative spec:** `docs/superpowers/specs/2026-08-01-wave2-transfer-methods-design.md` §4. All skeleton constraints in force. NFC payloads are EXISTING `cmo:` URIs — the only new codec kind is `v1`.

## Global Constraints (additions for C)

- **Voucher codec (`cmo:v1:`, normative):** base64url-no-pad of compact JSON `{"tx": "<cmo:tx1:... string>", "seed": "<b64u 32-byte throwaway seed>"}`. Claim = ingest the inner tx (full skeleton validation), reconstruct throwaway keys from seed, build + sign sweep tx (throwaway → self, amount = voucher amount, fresh lamport), ingest it. Malformed/unknown → `QrDecodeException` ("not a pinnie code"). Double-claim is the sanctioned double-spend feature; UI never promises exclusivity.
- **Ownership:** C1 extends `lib/domain/qr_codec.dart` (voucher kind — the ONLY shared-file edit in this graph, and only C1 makes it) + creates `lib/domain/voucher.dart`; C2 creates `lib/ports/nfc_port.dart`, `lib/fakes/nfc_fakes.dart`, `lib/state/nfc_controller.dart`, appends providers; C3 owns `pubspec.yaml` NFC plugin adds (verify current plugin landscape for HCE support at build time — nfc_manager + an HCE package; if no maintained HCE plugin fits, implement reader/writer + vouchers fully and record HCE as device-pass-blocked in the task report, do not fail) + `lib/adapters/nfc_adapter.dart` + `android/` manifest NFC permissions/HCE service registration (declared exception to android/ ownership — C3 only, additive). C4 features (fakes only). **C5 integration** (radial `send.method.nfc` enable, routes, wiring, e2e) — only editor of shared surfaces; because Graph B's B5 ALSO edits the radial menu in parallel, **C5 must NOT edit `radial_send_menu.dart`; it exposes NFC via the Receive screen ("Tap mode") and a `/nfc` route, and the radial NFC entry is wired by whichever of B5/C5 lands second — the engine serializes integration merges; if the menu already has the other graph's entries when C5's clone is cut, C5 adds only its own line.** Resolution recorded here so neither graph assumes exclusive menu ownership.
- **Widget-test keys:** `nfc.tapmode.toggle`, `nfc.write.request`, `nfc.write.voucher`, `nfc.voucher.amount`, `nfc.claim.result`.

### Task C1: Voucher domain

Extend the codec with `v1` (`VoucherPayload extends QrPayload { Transaction tx; Uint8List seed; }`, encode/decode + strict failures) and `lib/domain/voucher.dart`: `Future<Transaction> buildSweep({required VoucherPayload voucher, required String claimant, required int lamportTs})` (reconstruct keys from seed via `WalletKeys.fromSeed`, sign throwaway→claimant for the voucher tx amount) and `Future<(Transaction voucherTx, Transaction sweepTx)?> claimVoucher(...)` orchestration returning null on validation failure. `Future<(String voucherUri, Uint8List seed)> mintVoucher({required WalletKeys owner, required int amount, required int lamportTs})` — creates throwaway keys, signs owner→throwaway tx, encodes. TDD: round trips, malformed rejects, full mint→claim ledger test (owner debited once, claimant credited via sweep, replay-stable under merge permutations), double-claim test (two claimants both credit — documented feature).

### Task C2: NFC port, fakes, controller

Port per spec §4 (`writeTag`, `tagsRead`, `startHceSession`/`stopHceSession`); `FakeNfcPort` (injectable reads, records writes/HCE sessions); `NfcController`: tap-mode (HCE session carrying own `cmo:rr1:`), handle read URIs by dispatching to existing decode flows (rr → send confirm; tx1 → ingest; v1 → claim), `writeRequestTag(amount?)`, `writeVoucherTag(amount)` (biometric-gated — it signs money away). Tests with fakes incl. claim-from-read path updating the ledger.

### Task C3: NFC adapter + Android config

Pubspec adds FIRST (verify current: `nfc_manager` for read/write; HCE via a maintained package or `nfc_manager`'s HCE support if current — check pub.dev, do not trust memory). Manifest: `android.permission.NFC`, `<uses-feature android:name="android.hardware.nfc" android:required="false"/>`, HCE `apduservice` registration if HCE lands. Adapter thin; no headless tests beyond construction — device pass verifies. Record exact HCE capability outcome in the task report.

### Task C4: NFC UI

Fakes only. Receive screen gains "Tap mode" toggle (`nfc.tapmode.toggle`, HCE session while active, NFC-active indicator per README §5); `lib/features/nfc/sticker_studio.dart` — write request tag (`nfc.write.request`) and voucher tag (`nfc.write.voucher`, amount entry `nfc.voucher.amount`, biometric gate, "anyone who taps can claim — first to sync wins, chaos is the point" copy); claim result banner (`nfc.claim.result`, +ᵽN with coin flip). Widget tests: injected v1 read → claim → balance moves; injected rr read → routed to send confirm; write-voucher requires biometric.

### Task C5: Integration + review handoff

Routes `/nfc` (sticker studio); Receive tap-mode wired; real adapter in `realHardwareOverrides`; radial menu per the Global Constraints resolution above; e2e with fakes (mint voucher → simulate another wallet claiming → ledgers converge); web-build compile check. Then **C6: review** (REVIEW ONLY): voucher crypto conformance (sweep signed by throwaway key, ingest-validated), biometric gates on all signing paths, codec strictness, no plugin leaks, radial-menu resolution honored, check.sh twice from clean, commit audit.

## Plan Self-Review (completed)

Spec §4 coverage: HCE→C2/C3/C4, stickers→C4, voucher→C1, port→C2, device-pass caveats→C3 report. Radial-menu contention with parallel Graph B explicitly resolved (C5 defers unless landing second). Voucher double-claim is tested as a feature, not hidden. The only shared-file edits: C1's codec extension (additive kind) and C5's integration surfaces.
