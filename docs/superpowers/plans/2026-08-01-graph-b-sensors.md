# Graph B — Sensors (Pour, Shake-to-Cancel, Make-it-Rain) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. This plan is the source for Bureau graph B; plan Task N = Bureau task BN. **Declared only after Graph A promotes** — B consumes A's merged `MeshTransport`/`MeshController` surfaces; read them from the repo, do not guess.

**Goal:** The showmanship layer: pour-to-pay (tilt-streamed cosmetic pour + one signed tx at pour end), shake-to-cancel (post-biometric, pre-sign grace window), make-it-rain (random split across live mesh peers), compass bearing on the radar, haptic ticks on money events.

**Normative spec:** `docs/superpowers/specs/2026-08-01-wave2-transfer-methods-design.md` §3. Skeleton + Graph A constraints remain in force (encodings, ledger rules, memo rule, name-display rule, no plugins outside adapters, riverpod 2.x, no periodic timers or looping animations in test paths).

## Global Constraints (additions for B)

- **Money invariants (non-negotiable):** the ledger only ever sees ordinary signed transactions. Pour progress is cosmetic (`pour`-kind envelopes, unsigned payloads); the transfer is EXACTLY ONE signed tx at pour end for the accumulated amount. Rain = one signed tx per recipient; split is random with every share ≥ 1 and shares summing exactly to the total. Shake-cancel aborts BEFORE `send()` is invoked — after signing, cancellation is impossible and UI copy must never imply otherwise.
- **Ownership:** B1 creates `lib/ports/motion_sensor.dart`, `lib/ports/haptics.dart`, extends `lib/fakes/` (`lib/fakes/sensor_fakes.dart`), creates `lib/state/pour_controller.dart`, `lib/state/rain_controller.dart`, appends providers. B2 owns `pubspec.yaml` (`flutter pub add sensors_plus flutter_compass` — verify current APIs) and `lib/adapters/{motion_sensor_adapter,compass_adapter,haptics_adapter}.dart`. B3/B4 are feature UI (fakes only). **B5 is the only editor of `lib/app.dart`, `lib/providers.dart` real-wiring, `lib/features/wallet/radial_send_menu.dart`, and `lib/features/radar/radar_screen.dart` (compass bearing merge).** Parallel tasks (B2∥B3∥B4) branch-isolated, scoped commits.
- **Pour envelope payload** (`kind: pour`, spec §2.1 reserved — B defines it, normative): compact JSON `{sessionId (UUIDv7), seq (int, from 0), pouredTotal (int), state: "pouring"|"stopped"|"final", txId (string, only when state=="final")}`. Receivers render from the highest `seq` only (out-of-order safe); `final` announces the tx id whose arrival (mesh or QR) completes the catch.
- **Sensor semantics:** pour rate = `clamp((tiltRadians - 0.35) / 1.2, 0, 1) * 25` pinnies/sec, integer-accumulated; tilt back below 0.35 rad pauses. Shake = `MotionSensor.shakes` event (adapter: accel magnitude > 2.2g debounced 500ms; fake: injectable).
- **Widget-test keys:** `pour.start`, `pour.stop`, `pour.amount`, `pour.catch.cup`, `send.grace.<txPendingId>` (grace window), `rain.amount`, `rain.shake.hint`, `send.method.pour`, `send.method.rain`.
- Haptics: `Haptics.tick()` per pinnie during pour (adapter: `HapticFeedback.selectionClick`), fake records count. All animations finite.

### Task B1: Sensor ports, fakes, pour/rain domain + controllers

**Bureau:** B1, no deps (within B). Ports:

```dart
abstract interface class MotionSensor { Stream<double> get tiltRadians; Stream<void> get shakes; }
abstract interface class Haptics { Future<void> tick(); }
```

Pure logic (in controllers, unit-tested with fake streams + injected clock):
- `PourController` — `startPour({required String to})` → streams pour envelopes via MeshController surface (read merged repo for the exact originate/send API), accumulates from a `Stream<double>` tilt at 4Hz sampling (test-injectable ticker), `stopPour()` → emits `state:"stopped"`; `finishPour()` → biometric gate → `ledgerController.send(to, pouredTotal)` → `final` envelope with txId. Catch side: `PourCatchState` from highest-seq envelope per sessionId.
- `RainController` — `splitRain(int total, List<String> recipients)` pure function (deterministic given injected `Random(seed)`; every share ≥1, sums exactly; throws if `total < recipients.length`); `makeItRain(int total)` → biometric ONCE → loop `ledgerController.send` per recipient → gossip each targeted.
- **Shake-cancel integration point:** a reusable `GraceWindow` helper (`Future<bool> run({required Duration window, required Stream<void> abortSignal})` — completes false if aborted; test-injectable timer) used by B3/B4 and wired into the EXISTING QR + mesh send confirms by B5.
- [ ] TDD required tests: split properties (sum, min-1, throw), pour accumulation math incl. pause + integer boundaries, pour envelope seq/out-of-order handling, GraceWindow abort/timeout, rain sends N txs with one biometric call. Gate green; commit.

### Task B2: Sensor adapters

**Bureau:** B2, dependsOn B1, parallel with B3/B4. Owns pubspec adds (`sensors_plus flutter_compass`, FIRST commit, verify current APIs). `sensors_plus` accelerometer+gyro → tilt (pitch from gravity vector) + shake detection per Global Constraints; `flutter_compass` → `Stream<double> headingRadians` exposed via a small `CompassPort` (B2 defines port + fake alongside adapter — declared addition). Haptics adapter via `HapticFeedback`. Headless: adapters are thin; test only pure helpers (tilt-from-accel math extracted as a pure function with unit tests). Scoped commits.

### Task B3: Pour experience (pour + catch screens)

**Bureau:** B3, dependsOn B1, parallel with B2/B4. Fakes only. `lib/features/pour/pour_screen.dart` (tilt-driven stream of coins draining — finite particle bursts per tick, orange `CmoColors.orange` reserved for the stream; haptic tick per pinnie; `pour.start`/`pour.stop`/`pour.amount`) and catch mode integrated into the EXISTING receive screen pattern as `lib/features/pour/catch_screen.dart` (`pour.catch.cup` fills by pouredTotal/target). Biometric confirm on finish (existing gate). Widget tests: injected tilt stream pours 10 pinnies → amount shows ᵽ10 → finish → biometric → send called with 10; shake during grace aborts (uses GraceWindow); catch cup renders from out-of-order envelopes correctly.

### Task B4: Make-it-rain + shake-to-cancel surfaces

**Bureau:** B4, dependsOn B1, parallel with B2/B3. Fakes only. `lib/features/rain/rain_screen.dart`: amount entry (`rain.amount`), live-peer count display, shake to trigger (`rain.shake.hint`; button fallback for accessibility/reduced-motion), confetti burst (finite), per-recipient notification text. Grace-window UI component (`lib/features/send/grace_window_widget.dart`, `send.grace.<pendingId>`, 5s countdown ring + "shake to cancel" copy + haptic on abort) built here as a reusable widget, NOT yet wired into QR/mesh confirms (B5 does that). Widget tests: rain with 3 fake peers → 3 sends, shares sum; shake aborts grace → no send; reduced-motion path uses the button.

### Task B5: Integration

**Bureau:** B5, dependsOn B2+B3+B4. Only editor of shared surfaces. Enable `send.method.pour` + `send.method.rain` in the radial menu; routes `/pour`, `/rain`; **wire GraceWindow into the existing QR-send and mesh-send confirm flows** (post-biometric, pre-sign — verify placement against the skeleton's send-at-signing semantics); radar gains compass bearing when `CompassPort` reports headings (peers with shared heading data rotate to bearing; RSSI-only fallback unchanged); real wiring for sensor adapters; e2e: pour 25 pinnies via LoopbackHub to a catch screen (cup fills, final tx ingests, balances move exactly 25); rain across 3 hub peers; shake-cancel in the QR flow leaves the ledger untouched. Web build compile check. Gate green.

### Task B6: Review (gate)

**Bureau:** B6, dependsOn B5. REVIEW ONLY, checklist: money invariants (grep every `send(` call — pour exactly-one-tx, rain N txs one biometric, no signed tx before grace completes); pour payload format conformance; split properties tested; no timers/looping animations in test paths; haptics only via port; name-display rule on any new peer surfaces; check.sh twice from clean; commit audit.

## Plan Self-Review (completed)

Spec §3 coverage: ports→B1/B2, pour→B1/B3/B5, shake→B1/B4/B5 (placement pinned post-biometric pre-sign), rain→B1/B4/B5, compass→B2/B5. Declared additions beyond spec: `CompassPort` (B2), `GraceWindow` helper + widget (B1/B4), pour payload schema (Global Constraints — spec reserved the kind, plan defines it). Money invariants stated once, enforced by B6 grep audit. Keys centralized. B reads A's merged surfaces from the repo rather than this plan restating them — the one intentional difference from Graph A's approach, since A is promoted before B declares.
