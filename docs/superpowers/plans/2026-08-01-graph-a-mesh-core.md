# Graph A — "Pinnie Net" Mesh Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. This plan is the source for Bureau graph A; plan Task N = Bureau task AN.

**Goal:** BLE gossip mesh: signed transactions hop phone-to-phone (flood, TTL 8, store-and-forward), with a mesh-send method, radar screen, delivery receipts with hop counts, and relay notifications.

**Architecture:** Transport-agnostic `GossipEngine` in pure Dart; `MeshTransport` port with a `LoopbackHub` fake that joins N fake transports into a virtual radio space so multi-node mesh behavior is fully headless-testable. BLE plugins live only in adapters.

**Normative spec:** `docs/superpowers/specs/2026-08-01-wave2-transfer-methods-design.md` §2 (envelope format, gossip rules, ports). The skeleton spec's encodings and display rules remain in force. On conflict, specs win.

## Global Constraints

- **Gate:** `bash tool/check.sh` green before claiming done (build_runner → format non-generated → analyze → test). `git add` new files before the gate.
- **All skeleton Global Constraints still apply** (encodings, unauthenticated-name display rule, no plugin imports outside `lib/adapters/` except `qr_flutter`, memo rule, riverpod 2.x pin).
- **Envelope normative fields** (spec §2.1): `v:1, msgId(UUIDv7 lowercase), kind(tx|presence|receipt|chat|pour), origin, target(nullable), ttl(starts 8), path(relay addrs, origin excluded), payload(string)`. Compact JSON. Unknown kinds relayed, never delivered. Hop count = `path.length`.
- **Gossip rules** (spec §2.2) are normative: seen-cache dedupe → deliver-if-target-self-or-broadcast → relay if `ttl > 1 && target != self` with `ttl-1` + self appended to `path` → store-and-forward via outbox for targeted frames with no connected peers, retransmit on peer-connect, clear on receipt, 24h expiry. Presence broadcast on start + every 30s.
- **Shared-surface ownership:** A1 creates `lib/domain/mesh/`; A2 creates `lib/ports/{mesh_transport,notifier,outbox_store,seen_store}.dart`, extends `lib/fakes/` (new file `lib/fakes/mesh_fakes.dart`), creates `lib/state/mesh_controller.dart`, and appends the new providers to `lib/providers.dart`. **A6 is the only later editor of `lib/app.dart`, `lib/main.dart`, `lib/providers.dart`, `lib/features/wallet/radial_send_menu.dart`, and `pubspec.yaml` (BLE/notification plugin adds).** A3 adds plugin deps? NO — A6 owns pubspec; A3 lists its required deps in its task report and codes against them with A6 wiring... **Correction (binding): A2 adds the pure-Dart test deps it needs (none expected); A3 needs plugin packages to compile — therefore A3 owns the `flutter pub add flutter_blue_plus bluetooth_low_energy flutter_local_notifications` pubspec change, made FIRST, in its own commit, and A4/A5 must not touch pubspec.** Parallel-wave tasks (A3∥A4∥A5) run isolated on branches and stage only their own paths.
- **Widget-test keys (exact spellings, A4/A5 produce, A6 consumes):** `mesh.peer.<addr>` (peer picker tile), `mesh.send.confirm`, `mesh.status.<txId>` (delivery state chip — deliveries are keyed by TRANSACTION id, see A4), `radar.blip.<addr>`, `send.method.mesh`.
- Timers: presence/retry timers must NOT auto-start in widget-test paths — controllers expose one-shot methods (`broadcastPresenceOnce()`, `flushOutboxOnce()`); only A6's real wiring starts periodic timers. Looping animations forbidden (pumpAndSettle).

---

### Task A1: Mesh domain — envelope codec + gossip engine (pure Dart)

**Bureau:** A1, no deps. **Files:** Create `lib/domain/mesh/envelope.dart`, `lib/domain/mesh/gossip_engine.dart`; Test `test/domain/mesh/envelope_test.dart`, `test/domain/mesh/gossip_engine_test.dart`.

**Interfaces produced (exact):**

```dart
// envelope.dart
const envKindTx = 'tx'; const envKindPresence = 'presence';
const envKindReceipt = 'receipt'; const envKindChat = 'chat'; const envKindPour = 'pour';
const meshInitialTtl = 8;

class MeshEnvelope {
  const MeshEnvelope({required this.msgId, required this.kind, required this.origin,
    required this.target, required this.ttl, required this.path, required this.payload});
  final String msgId; final String kind; final String origin;
  final String? target; final int ttl; final List<String> path; final String payload;
  MeshEnvelope relayedBy(String selfAddr) => // ttl-1, path + [selfAddr]
  Map<String, Object?> toJson(); // {'v':1, 'msgId':..., 'kind':..., 'origin':..., 'target':..., 'ttl':..., 'path':[...], 'payload':...}
  factory MeshEnvelope.fromJson(Map<String, Object?> json); // strict; FormatException on missing/wrong types or v != 1
}
class FrameDecodeException implements Exception { final String message; }
String encodeFrame(MeshEnvelope e);            // compact JSON
MeshEnvelope decodeFrame(String frameJson);    // throws FrameDecodeException on anything malformed

// gossip_engine.dart — transport-agnostic; NO Flutter imports, NO port imports.
class RelayEvent { final MeshEnvelope envelope; }
class GossipEngine {
  GossipEngine({required String selfAddr, required Set<String> initialSeen,
      DateTime Function()? now});
  Stream<MeshEnvelope> get delivered;   // target==self or broadcast, known kinds only, exactly once per msgId
  Stream<String> get outboundFrames;    // frames the caller must broadcast
  Stream<RelayEvent> get relays;        // fired when relaying another node's envelope
  Stream<String> get seenAdditions;     // msgIds newly seen (caller persists)
  /// Frames needing store-and-forward: caller persists (msgId, frame, expiresAt=now+24h).
  Stream<(String msgId, String frame, DateTime expiresAt)> get outboxPuts;
  Stream<String> get outboxClears;      // msgId of receipts' forMsgId — caller removes
  bool get hasConnectedPeers; set hasConnectedPeers(bool v); // caller updates from transport
  void onFrame(String frameJson);       // full §2.2 pipeline; malformed frames dropped silently
  void originate(MeshEnvelope e);       // stamps nothing; caller builds envelope; engine emits outbound + outbox-put if targeted && !hasConnectedPeers
  void retransmit(String frame);        // outbox flush path: re-emit outbound WITHOUT ttl decrement
}
```

Receipt payload helpers in envelope.dart: `String receiptPayload(String forMsgId, int hops)` / `(String forMsgId, int hops) parseReceiptPayload(String)`; presence: `String presencePayload(String addr, String name)` / `({String addr, String name}) parsePresencePayload(String)` (throw `FormatException` on malformed).

- [ ] **Steps (TDD, commit per green cycle):**
  1. Envelope tests: exact-JSON layout, round trip, strict fromJson rejections (missing field, `v:2`, ttl non-int, path non-list), `relayedBy` (ttl 8→7, path append), payload helpers round trips + malformed.
  2. Implement envelope.dart; green; commit `feat: mesh envelope codec`.
  3. Engine tests (drive via `onFrame`/`originate`, collect streams):
     - dedupe: same frame twice → delivered once, no second relay;
     - deliver+relay matrix: broadcast → delivered AND relayed; targeted-at-self → delivered, NOT relayed; targeted-at-other → relayed only, `RelayEvent` fired; `ttl:1` → not relayed; unknown kind → relayed, never delivered;
     - relay output frame has ttl-1 and self in path;
     - originate targeted with `hasConnectedPeers=false` → outboxPuts fires with expiry now+24h; with peers → no outbox put;
     - receipt frame delivered to self → outboxClears emits its `forMsgId`;
     - `retransmit` re-emits the frame unchanged (no ttl decrement);
     - malformed frame via onFrame → nothing emitted, no throw.
  4. Implement gossip_engine.dart; green; commit `feat: gossip engine (flood, ttl, store-and-forward hooks)`.
  5. `bash tool/check.sh` green; final commit.

---

### Task A2: Mesh ports, fakes + LoopbackHub, MeshController, providers

**Bureau:** A2, dependsOn A1. **Files:** Create `lib/ports/mesh_transport.dart`, `lib/ports/notifier.dart`, `lib/ports/outbox_store.dart`, `lib/ports/seen_store.dart`, `lib/fakes/mesh_fakes.dart`, `lib/state/mesh_controller.dart`; Modify `lib/providers.dart` (append only); Test `test/fakes/mesh_fakes_test.dart`, `test/state/mesh_controller_test.dart`.

**Interfaces produced (exact):** ports verbatim from spec §2.3 (`MeshPeer`, `MeshTransport`, `Notifier`, `OutboxStore`) plus `abstract interface class SeenStore { Future<Set<String>> load(); Future<void> add(String msgId); }` (drift adapter caps at 1024 in A3; fake unbounded).

`lib/fakes/mesh_fakes.dart`:

```dart
class FakeNotifier implements Notifier { final List<(int, String, String)> shown; ... }
class InMemoryOutboxStore implements OutboxStore { ... }
class InMemorySeenStore implements SeenStore { ... }
class FakeMeshTransport implements MeshTransport {
  // start()/stop() toggle `running`; injectPeer(MeshPeer), injectFrame(String);
  // broadcastFrame records into `sentFrames` AND forwards to an attached hub.
}
class LoopbackHub {
  void join(String addr, FakeMeshTransport t);       // full mesh by default
  void setLink(String a, String b, {required bool up}); // partition control
  // broadcastFrame from a joined transport delivers (async microtask) to every
  // transport with an `up` link; also emits peerEvents on join/link changes.
}
```

`lib/state/mesh_controller.dart` — `class MeshController extends AsyncNotifier<MeshState>`:

```dart
class MeshState { final List<MeshPeer> livePeers; final Map<String, MeshDeliveryStatus> deliveries; }
enum MeshDeliveryStatus { hopping, delivered } // keyed by tx envelope msgId
// Wires: transport.inboundFrames→engine.onFrame; engine.outboundFrames→transport.broadcastFrame;
// engine.delivered dispatch: tx→ledgerController.ingestExternal + originate receipt (hops=path.length) + notifier;
//   presence→peerDirectory.record; receipt→deliveries[forMsgId]=delivered + notifier;
// engine.relays→notifier ("relayed ᵽN for a stranger 🕵️" for tx kinds only);
// engine.seenAdditions→seenStore.add; outboxPuts/Clears→outboxStore; peerEvents→livePeers (+engine.hasConnectedPeers, flushOutboxOnce on first peer).
Future<String> sendMeshTx({required String to, required int amount, String? memo});
  // ledgerController.send(...) (existing biometric-gated flow calls this AFTER auth) →
  // wrap cmo:tx1 in envelope (fresh UUIDv7 msgId, ttl 8, empty path) → originate →
  // deliveries[msgId]=hopping → returns msgId.
Future<void> broadcastPresenceOnce(); Future<void> flushOutboxOnce(); // one-shots; NO timers here
```

- [ ] **Steps:** TDD as in A1. Required tests: fake/hub behavior (2 transports on a hub exchange frames; link-down partitions); controller tests via `ProviderContainer` with all fakes — incoming tx envelope ingests + emits receipt + notification; receipt updates delivery status; presence records peer name; relay of foreign envelope fires notifier; `sendMeshTx` with zero peers persists to outbox and `flushOutboxOnce` after peer-connect retransmits; **4-node LoopbackHub sim** (A,B,C,D; only chain links up A–B–C–D): A `sendMeshTx` → D's ledger credits exactly once, D's receipt reaches A with `hops == 2`, A's delivery flips to delivered; then a late-joining E targeted earlier receives on join via outbox flush. Gate green; scoped commits.

---

### Task A3: Adapters — BLE transport, notifications, outbox/seen drift

**Bureau:** A3, dependsOn A2, parallel with A4/A5. **Files:** Modify `pubspec.yaml` (FIRST, own commit: `flutter pub add flutter_blue_plus bluetooth_low_energy flutter_local_notifications` — verify current versions); Create `lib/adapters/ble_mesh_transport.dart`, `lib/adapters/local_notifier.dart`, `lib/adapters/drift_outbox_store.dart` (+ extend `lib/adapters/drift_db.dart` with `OutboxRows`/`SeenRows` tables, schemaVersion 2 + migration); Test `test/adapters/drift_outbox_test.dart`.

- BLE adapter: service UUID `0xCA5E` (16-bit base-expanded), advertise with truncated (8-byte) wallet id in manufacturer data; central scans + connects; single write/notify characteristic; **length-prefixed (4-byte big-endian) chunking reassembled internally** — `inboundFrames` emits whole JSON strings; MTU request 512 with graceful fallback. Peers mapped to `MeshPeer` (addr from a hello frame exchanged on connect: `{"hello": <addr>, "name": <name>}` — adapter-internal, never surfaced as an envelope). If the peripheral API is unusable, degrade per spec §2.3 and record it in the task report. No headless test possible beyond construction — device pass verifies.
- Drift stores testable headless with `NativeDatabase.memory()` (pattern: `test/adapters/drift_db_test.dart`). Seen table capped at 1024 (delete-oldest on insert).
- `flutter_local_notifications` adapter thin; Android init in adapter, channel id `cmo.pinnies`.
- [ ] Steps: pubspec commit → drift tables TDD → adapters → gate green → scoped commits (`lib/adapters`, `test/adapters`, `pubspec.*`).

### Task A4: Mesh send flow + delivery states

**Bureau:** A4, dependsOn A2, parallel with A3/A5. **Files:** Create `lib/features/send/mesh_send_flow.dart`; Modify `lib/features/history/history_screen.dart` (delivery-status chip on own outgoing txs via `mesh.status.<msgId>`... status is keyed by envelope msgId which History doesn't know — **binding resolution: MeshController.deliveries is keyed by TRANSACTION id, not envelope msgId** (one tx = one envelope; use `tx.id`); A2 implements accordingly, `sendMeshTx` returns the tx id); Test `test/features/mesh_send_test.dart`.

- Peer picker (PeerDirectory ∪ livePeers, live badged, key `mesh.peer.<addr>`) → amount/memo (skeleton rules: range validation, empty memo → null) → **existing biometric gate** → `sendMeshTx` → status screen with `mesh.status.<txId>` chip animating hopping→delivered. Uses fakes via ProviderScope overrides; no plugin imports. History chip: hopping/delivered shown for own transfers present in `deliveries`.
- [ ] Steps: TDD with FakeMeshTransport-driven receipt to flip status; gate green; scoped commit.

### Task A5: Radar screen

**Bureau:** A5, dependsOn A2, parallel with A3/A4. **Files:** Create `lib/features/radar/radar_screen.dart`; Test `test/features/radar_test.dart`.

- CustomPainter: self-center, peers at radius by RSSI bucket (>-60 inner, -60..-80 mid, else outer), blip key `radar.blip.<addr>`, tap → `Navigator.pushNamed('/send-mesh', arguments: addr)` (route registered by A6 — test taps assert navigation intent via a mocked observer or pumps the screen directly), single-run pulse on relay events (listen `relays` via controller-exposed stream; finite animations only). Reduced-motion: static blips.
- [ ] Steps: TDD (3 fake peers render 3 blips; relay event triggers one pulse cycle; tap fires navigation); gate green; scoped commit.

### Task A6: Integration — wiring, routes, radial menu, periodic timers, e2e

**Bureau:** A6, dependsOn A3+A4+A5. Only editor of `lib/app.dart`, `lib/main.dart`, `lib/providers.dart`, `lib/features/wallet/radial_send_menu.dart`. **Files:** those + Test `test/integration/mesh_e2e_test.dart`.

- Register `/radar`, `/send-mesh` routes; enable "Mesh" in the radial menu (`send.method.mesh`); add radar entry point on wallet app bar. `realHardwareOverrides()` gains BLE transport, local notifier, drift outbox/seen. Real wiring starts transport + 30s presence timer + outbox-retry-on-peer-connect (timers live ONLY here). Fake path (`FAKE_HARDWARE`) uses a solo FakeMeshTransport.
- e2e (fakes, LoopbackHub): onboard → radial → Mesh → pick live peer → biometric → status hopping → hub delivers → counterparty stack ingests → receipt → status delivered with hop count; radar shows the peer; relay notification path asserted via FakeNotifier.
- [ ] Steps: wire → e2e TDD → full gate → `flutter build web --dart-define=FAKE_HARDWARE=true` compiles → commit.

### Task A7: Independent conformance review (gate)

**Bureau:** A7, dependsOn A6. REVIEW ONLY — findings report with PASS/FAIL + file:line evidence. **First action: read spec §2 and this plan's Global Constraints.** Checklist: envelope fields + strict decode vs spec §2.1; every §2.2 gossip rule implemented and tested (dedupe, deliver/relay matrix, ttl, path, receipt, outbox lifecycle incl. expiry + clear-on-receipt, presence cadence); unknown kinds relayed-not-delivered; deliveries keyed by tx id; no plugin imports outside adapters; no periodic timers outside A6 wiring; unauthenticated-name display rule holds on peer picker + radar; 4-node sim + e2e exist and run; `tool/check.sh` twice from clean state; per-task commit audit.

---

## Plan Self-Review (completed)

Spec §2 coverage: envelope/§2.1→A1; gossip/§2.2→A1 engine + A2 controller lifecycle; ports/§2.3→A2 (+SeenStore addition, declared); adapters→A3; features/§2.4→A4/A5/A6; verification/§2.5→per-task tests + A6 e2e + A7. Known deviations (binding, declared): `deliveries` keyed by tx id not msgId (History needs it; 1:1 anyway); `SeenStore` port added beyond spec's three; A3 owns the pubspec plugin additions (A6 owns it otherwise). Type consistency: engine stream contracts in A1 match A2's wiring list; key spellings centralized in Global Constraints.
