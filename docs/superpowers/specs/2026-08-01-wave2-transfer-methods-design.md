# Cash Me Outside — Wave 2: Mesh, Sensors, NFC (Bureau graphs A/B/C)

**Date:** 2026-08-01
**Status:** Approved (scope confirmed by owner: mesh first, then sensors ∥ NFC)
**Parent spec:** [README.md](../../../README.md) §3.3–§4 · **Builds on:** [walking skeleton](2026-08-01-walking-skeleton-design.md) (promoted `1ccfb77`, device-verified)
**Build executor:** The Bureau. Workers have Flutter, no devices, no Android SDK (APK builds stay local). All protocol logic MUST be headless-testable behind ports; plugin adapters stay thin and are human-verified on hardware.

---

## 1. Wave plan

- **Graph A — "Pinnie Net" (mesh core):** BLE transport port + gossip protocol + mesh-send method + radar screen + relay notifications. Riskiest work, everything else rides on it.
- **Graph B — sensors (after A):** pour-to-pay, shake-to-cancel, make-it-rain. Consumes A's `MeshTransport` port.
- **Graph C — NFC (parallel with B):** Android↔Android HCE tap + NTAG payment stickers/vouchers.
- **Deferred (README cut order):** contacts, voice, calendar, chat UI (chat *protocol* support ships in A's envelope `kind`; the chat screen is a later graph).

Each graph: `validation: unit`, `install: flutter pub get`, `test: bash tool/check.sh`, destination `hackathon-flutter`, toolchain `flutter`. No engine-side APK gates (see `tool/PROBE.md`).

---

## 2. Graph A — mesh core (normative)

### 2.1 Envelope wire format

Compact JSON (same canonicalization conventions as the skeleton spec §2.1), fields:

| Field | Meaning |
|---|---|
| `v` | protocol version, `1` |
| `msgId` | UUIDv7, lowercase canonical — dedupe key |
| `kind` | `"tx" \| "presence" \| "receipt" \| "chat" \| "pour"` |
| `origin` | sender wallet address (skeleton encoding) |
| `target` | recipient wallet address, or `null` = broadcast/flood |
| `ttl` | int, **starts at 8**, decremented per relay; dropped at 0 |
| `path` | array of relay addresses, **appended by each relaying node** (origin NOT included; hop count = `path.length`) |
| `payload` | string, kind-specific (below) |

Kind payloads: `tx` → a full `cmo:tx1:` string (reuse the skeleton codec verbatim — the mesh moves the exact same signed envelopes QR does); `presence` → compact JSON `{addr, name}` (feeds `PeerDirectory`; **name remains unauthenticated** — all skeleton display rules apply); `receipt` → compact JSON `{forMsgId, hops}` sent targeted at the original `origin` when a `tx` envelope is delivered; `chat`/`pour` reserved (defined in later graphs; unknown kinds are relayed but not delivered — forward compatibility, mirrors the ledger's unknown-type rule).

Envelopes are NOT independently signed in v1 — the `tx` payload inside carries its own Ed25519 signature and the ledger re-validates on ingest, so forged envelopes can move counterfeit bytes but can never mint accepted pinnies. Presence spoofing ≡ rr-name spoofing, already handled by display rules.

### 2.2 Gossip rules (normative — the demo's credibility lives here)

1. On receive: if `msgId` in seen-cache → drop silently.
2. Add to seen-cache (LRU, capacity 1024, persisted).
3. If `target == null` or `target == self`: deliver locally (dispatch by `kind`). Broadcast kinds are BOTH delivered and relayed.
4. If `ttl > 1` and (`target != self`): re-broadcast with `ttl-1` and self appended to `path`. When relaying another node's envelope, emit a relay notification ("your phone just relayed ᵽN for a stranger 🕵️" for tx kinds; silent for presence).
5. **Store-and-forward:** targeted (`target != null`) envelopes that have no connected peers at send/relay time persist in an outbox (drift); on every new-peer event the outbox retransmits (each attempt fresh `ttl` decrement applies only to relays, not retransmits). Delivered receipts clear the matching outbox entry. Outbox entries expire after 24h.
6. Delivery of a `tx` envelope = ingest via the existing `LedgerController.ingestExternal` (all skeleton validation applies) + send a `receipt` envelope targeted at `origin`.
7. Presence is broadcast on transport start and every 30s (`target: null`, fresh `msgId` each time).

### 2.3 Ports (Graph A adds; skeleton port rules apply — fakes for every port, plugins only in adapters)

```dart
class MeshPeer { final String addr; final String? name; final int rssi; final DateTime lastSeen; }

abstract interface class MeshTransport {
  Future<void> start();                 // begin advertise + scan + connect
  Future<void> stop();
  Stream<MeshPeer> get peerEvents;      // connect/update events (rssi refreshes re-emit)
  Stream<String> get inboundFrames;     // whole envelope JSON strings (chunking is adapter-internal)
  Future<void> broadcastFrame(String frameJson); // to all currently connected peers
}

abstract interface class Notifier {
  Future<void> show({required int id, required String title, required String body});
}

abstract interface class OutboxStore {   // store-and-forward persistence
  Future<void> put(String msgId, String frameJson, DateTime expiresAt);
  Future<void> remove(String msgId);
  Future<List<(String msgId, String frameJson)>> pending();
}
```

**Fakes:** `FakeMeshTransport` (programmable peers, inbound injection, records broadcasts) and — the load-bearing test asset — **`LoopbackHub`**: an in-memory hub that joins N `FakeMeshTransport` instances into a virtual radio space (`hub.join(transport)`, per-link connect/disconnect, optional per-link drop flag). Multi-node tests instantiate 4 full gossip stacks over one hub and assert flood dedupe, TTL expiry, store-and-forward on late join, and receipt hop counts — no Bluetooth anywhere.

**Adapters (thin, device-verified):** BLE via `flutter_blue_plus` (central) + `bluetooth_low_energy` (peripheral): advertise service UUID `0xCA5E` with truncated wallet id in manufacturer data; scan/connect same UUID; GATT characteristic exchange, MTU-negotiate toward 512, length-prefixed chunking internal to the adapter. `flutter_local_notifications` → `Notifier`. Drift table → `OutboxStore`. **Verify plugin versions/API at build time; if peripheral mode is unavailable on a worker-buildable API path, adapter degrades to central-only + advertising-packet discovery and records the limitation in the task report (README risk register).**

### 2.4 Features

- **Mesh send:** radial-menu "Mesh" method enabled → peer picker (union of `PeerDirectory` and live `peerEvents`, live peers badged) → existing confirm screen + biometric gate (unchanged) → sign → ingest-at-signing (unchanged) → wrap in `tx` envelope, gossip it. Delivery states on the send screen and in History: sent → hopping (animated) → delivered ("arrived via N phones", from receipt `hops`). Undelivered stays "hopping" with the outbox retrying; History remains the recovery surface (tx QR re-show still works — same transaction).
- **Radar screen:** new route `/radar`; CustomPainter — self at center, live peers as blips ringed by RSSI bucket, pulse animation on gossip traffic, distinct flash when *this* phone relays. Tap a blip → send flow prefilled with that peer. (Compass bearing arrives with Graph B; radar works without it.)
- **Relay/receive notifications** via `Notifier` (receive pinnies, relay events, delivery receipts).

### 2.5 Graph A verification bar

`tool/check.sh` green (existing gate). New required tests: envelope codec round trips + malformed/unknown-kind handling; gossip engine unit tests (dedupe, TTL, path append, receipt emission, outbox retransmit + expiry + clear-on-receipt); **LoopbackHub 4-node simulation** (A→D via B,C relays: D ingests exactly once, receipt reaches A with `hops == 2`, late-joining D receives from outbox); widget tests for mesh-send flow + radar against fakes. Human device pass: 2-phone BLE direct send, then 3–4 phone relay test, foregrounded (iOS background limits per README).

---

## 3. Graph B — sensors (consumes A; normative highlights)

- **Ports:** `MotionSensor { Stream<double> tiltRadians; Stream<void> shakes; }` (`sensors_plus` adapter; fake with injectable streams), `Haptics { tick(); }`.
- **Pour-to-pay:** pour session = targeted `pour` envelopes streaming progress (unsigned, cosmetic — pinnies-per-second derived from tilt angle); the **money is exactly one signed transaction at pour end** for the accumulated amount, sent as a normal `tx` envelope. Ledger rules untouched; a dropped session transfers nothing until the final tx. Receiver "catch mode" cup fills from progress envelopes; haptic tick per pinnie on both ends.
- **Shake-to-cancel:** the confirm screen gains a 5-second "sending…" grace window AFTER biometric approval and BEFORE sign+ingest; a shake during the window aborts (haptic + rewind animation). After signing, cancellation is impossible by design (ledger is grow-only) — UI copy must not promise otherwise.
- **Make-it-rain:** amount split randomly (each recipient ≥1, sums exactly) across currently-live mesh peers; one signed tx per recipient, each gossiped targeted; confetti + notification on recipients. Uses the existing per-tx signing loop — no new ledger rules.
- Radar gains compass bearing (`flutter_compass`) where available.

## 4. Graph C — NFC (parallel with B; normative highlights)

- **Port:** `NfcPort { Future<void> writeTag(String uri); Stream<String> tagsRead; Future<void> startHceSession(String uri); Future<void> stopHceSession(); }` — payloads are existing `cmo:rr1:`/`cmo:tx1:` URIs, nothing new to parse. Fake with injectable reads.
- **Android↔Android HCE tap:** receiver emulates a tag carrying its `cmo:rr1:` request; sender taps → reads → existing confirm flow. (`nfc_manager` + HCE plugin; iOS documented as reader-only.)
- **NTAG payment stickers:** write a `cmo:rr1:` (pay-the-owner request) to a physical tag.
- **Voucher stickers ("ᵽ50 under a chair"):** tag holds `cmo:v1:` = compact JSON `{tx: <cmo:tx1 string paying a throwaway address>, seed: <b64u 32-byte seed of that throwaway>}`. Claimant ingests the tx, reconstructs the throwaway keys from the seed, signs a sweep tx (throwaway → self), ingests both. First scanner to *sync* wins; double-claims are the fake-money double-spend feature. New codec kind `v1` added to the QR/URI codec (shared with QR sneakernet for free).
- Human device pass needs physical NTAG215 tags + two Android phones.

---

## 5. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Envelope signing | Unsigned envelopes; signed payloads | Ledger already rejects forgery; halves protocol surface |
| Hop tracking | `path` array appended per relay | Powers "arrived via N phones" + History forensics (README §5) |
| Mesh testability | `LoopbackHub` joining N fake transports | 4-node mesh assertions fully headless — the whole reason workers can build this |
| Pour money model | Cosmetic stream + single signed tx at end | Keeps grow-only ledger rules intact; no partial-pour corruption |
| Shake-cancel window | Post-biometric, pre-sign | Sender-ingest-at-signing makes post-sign cancel impossible; window placement preserves that invariant |
| Voucher format | `cmo:v1:{tx, seed}` throwaway-key sweep | Offline-claimable with zero new ledger rules |
| Chat | Protocol kind reserved, UI deferred | Envelope pipe ships now; screen is a cheap later graph |
