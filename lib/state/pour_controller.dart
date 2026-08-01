import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:uuid/uuid.dart';

import '../domain/mesh/envelope.dart';
import '../providers.dart';

const _uuid = Uuid();
const _tickInterval = Duration(milliseconds: 250); // 4Hz sampling

/// Pour rate in pinnies/sec from a raw tilt reading (spec Global
/// Constraints): clamp((tilt - 0.35) / 1.2, 0, 1) * 25. Tilting back below
/// the 0.35 rad threshold naturally zeroes the rate — that's the "pause".
double pourRatePerSecond(double tiltRadians) =>
    ((tiltRadians - 0.35) / 1.2).clamp(0.0, 1.0) * 25;

/// Pure 4Hz-tick accumulator. Keeps an exact running total internally so
/// fractional pinnies-per-tick carry over instead of being lost to
/// per-tick rounding; [pouredTotal] is always the floored integer.
class PourAccumulator {
  double _exact = 0;
  int get pouredTotal => _exact.floor();

  /// Advances by one tick interval at [tiltRadians]; returns the number of
  /// whole pinnies gained this tick (drives per-pinnie haptic ticks).
  int tick(double tiltRadians) {
    final before = pouredTotal;
    _exact +=
        pourRatePerSecond(tiltRadians) * _tickInterval.inMilliseconds / 1000;
    return pouredTotal - before;
  }
}

class PourSessionState {
  const PourSessionState({
    required this.sessionId,
    required this.to,
    required this.pouredTotal,
    required this.active,
  });
  final String sessionId;
  final String to;
  final int pouredTotal;
  final bool active;
}

/// Catch-side render state, folded from the highest-`seq` pour envelope
/// seen per session (out-of-order relay delivery safe).
class PourCatchState {
  const PourCatchState({
    required this.sessionId,
    required this.seq,
    required this.pouredTotal,
    required this.state,
    this.txId,
  });
  final String sessionId;
  final int seq;
  final int pouredTotal;
  final String state; // pourStatePouring | pourStateStopped | pourStateFinal
  final String? txId;
}

/// Pure fold: applies an incoming pour envelope to the current catch state.
/// A different `sessionId` always supersedes (a new pour started); the same
/// session only advances on a strictly higher `seq`. Throws (via
/// [parsePourPayload]) on a malformed payload — callers must catch and drop
/// silently, matching [MeshController]'s handling of untrusted wire data.
PourCatchState applyPourFrame(PourCatchState? current, MeshEnvelope envelope) {
  final parsed = parsePourPayload(envelope.payload);
  if (current != null &&
      current.sessionId == parsed.sessionId &&
      parsed.seq <= current.seq) {
    return current;
  }
  return PourCatchState(
    sessionId: parsed.sessionId,
    seq: parsed.seq,
    pouredTotal: parsed.pouredTotal,
    state: parsed.state,
    txId: parsed.txId,
  );
}

class PourState {
  const PourState({this.outgoing, this.catchState});
  final PourSessionState? outgoing;
  final PourCatchState? catchState;
}

/// Pour-to-pay: a session streams cosmetic `pour`-kind envelopes over the
/// mesh while accumulating from tilt at 4Hz; the money itself is exactly
/// one signed tx (via [MeshController.sendMeshTx]) sent at [finishPour].
/// Catch-side state folds incoming pour envelopes from [MeshController.
/// pourFrames] regardless of whether this device is also pouring.
class PourController extends AsyncNotifier<PourState> {
  StreamSubscription<MeshEnvelope>? _pourFrameSub;
  StreamSubscription<double>? _tiltSub;
  StreamSubscription<void>? _tickerSub;
  String? _selfAddr;

  String? _sessionId;
  String? _to;
  int _seq = 0;
  double _lastTilt = 0;
  final _accumulator = PourAccumulator();

  @override
  Future<PourState> build() async {
    await ref.read(meshControllerProvider.future);
    _selfAddr = (await ref.read(walletKeysProvider.future))?.address;
    _pourFrameSub = ref
        .read(meshControllerProvider.notifier)
        .pourFrames
        .listen(_onPourFrame);
    ref.onDispose(() {
      unawaited(_pourFrameSub?.cancel());
      unawaited(_tiltSub?.cancel());
      unawaited(_tickerSub?.cancel());
    });
    return const PourState();
  }

  void _onPourFrame(MeshEnvelope envelope) {
    try {
      final next = applyPourFrame(state.valueOrNull?.catchState, envelope);
      _setCatch(next);
    } catch (_) {
      // malformed payload — silent drop, mirrors MeshController.
    }
  }

  /// Starts a pour session to [to]. [ticker] is test-injectable (fires once
  /// per 4Hz sample); defaults to a real periodic timer for production use.
  Future<void> startPour({required String to, Stream<void>? ticker}) async {
    await future;
    _sessionId = _uuid.v7();
    _to = to;
    _seq = 0;
    _lastTilt = 0;
    _accumulator._exact = 0;
    _setOutgoing(active: true);

    _tiltSub = ref.read(motionSensorProvider).tiltRadians.listen((t) {
      _lastTilt = t;
    });
    _tickerSub = (ticker ?? Stream<void>.periodic(_tickInterval)).listen(
      (_) => _onTick(),
    );
  }

  void _onTick() {
    if (_sessionId == null) return;
    final gained = _accumulator.tick(_lastTilt);
    if (gained > 0) {
      final haptics = ref.read(hapticsProvider);
      for (var i = 0; i < gained; i++) {
        unawaited(haptics.tick());
      }
    }
    _emitEnvelope(pourStatePouring);
    _setOutgoing(active: true);
  }

  /// Stops accumulation and announces `state: "stopped"`. No money has
  /// moved — [finishPour] is the only path that signs a tx.
  Future<void> stopPour() async {
    await future;
    _cancelSensors();
    _emitEnvelope(pourStateStopped);
    _setOutgoing(active: false);
  }

  /// Biometric gate → exactly one signed tx for the accumulated total →
  /// `state: "final"` envelope announcing the tx id. Returns `false` (no
  /// tx sent) if there's nothing accumulated or biometrics are denied.
  Future<bool> finishPour() async {
    await future;
    _cancelSensors();
    final to = _to;
    final total = _accumulator.pouredTotal;
    if (to == null || total <= 0) {
      _setOutgoing(active: false);
      return false;
    }
    final approved = await ref
        .read(biometricGateProvider)
        .authenticate('Confirm sending ᵽ$total');
    if (!approved) {
      _setOutgoing(active: false);
      return false;
    }
    final txId = await ref
        .read(meshControllerProvider.notifier)
        .sendMeshTx(to: to, amount: total);
    _emitEnvelope(pourStateFinal, txId: txId);
    _setOutgoing(active: false);
    return true;
  }

  // Fire-and-forget, matching MeshController/RadarScreen's convention: a
  // cancelled subscription stops delivering events synchronously (the
  // returned Future only tracks an onCancel callback, which these streams
  // never register), and awaiting it here previously deadlocked under
  // testWidgets (LESSON — see plan handoff).
  void _cancelSensors() {
    unawaited(_tiltSub?.cancel());
    unawaited(_tickerSub?.cancel());
    _tiltSub = null;
    _tickerSub = null;
  }

  void _emitEnvelope(String pourState, {String? txId}) {
    final sessionId = _sessionId, to = _to, selfAddr = _selfAddr;
    if (sessionId == null || to == null || selfAddr == null) return;
    final envelope = MeshEnvelope(
      msgId: _uuid.v7(),
      kind: envKindPour,
      origin: selfAddr,
      target: to,
      ttl: meshInitialTtl,
      path: const [],
      payload: pourPayload(
        sessionId: sessionId,
        seq: _seq,
        pouredTotal: _accumulator.pouredTotal,
        state: pourState,
        txId: txId,
      ),
    );
    _seq++;
    unawaited(
      ref.read(meshControllerProvider.notifier).sendPourFrame(envelope),
    );
  }

  void _setOutgoing({required bool active}) {
    final current = state.valueOrNull;
    final sessionId = _sessionId, to = _to;
    state = AsyncData(
      PourState(
        outgoing: (sessionId == null || to == null)
            ? current?.outgoing
            : PourSessionState(
                sessionId: sessionId,
                to: to,
                pouredTotal: _accumulator.pouredTotal,
                active: active,
              ),
        catchState: current?.catchState,
      ),
    );
  }

  void _setCatch(PourCatchState next) {
    final current = state.valueOrNull;
    state = AsyncData(PourState(outgoing: current?.outgoing, catchState: next));
  }
}
