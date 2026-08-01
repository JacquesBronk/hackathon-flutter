import 'dart:async';

/// Post-biometric, pre-sign cancellation window (spec §3, decisions log):
/// once a `send()` has actually signed+ingested a tx, the grow-only ledger
/// makes cancellation impossible, so this window MUST run before that call.
/// Shared by shake-to-cancel (B4) and wired into QR/mesh send confirms (B5).
class GraceWindow {
  const GraceWindow({Future<void> Function(Duration)? scheduler})
    : _scheduler = scheduler ?? Future<void>.delayed;

  final Future<void> Function(Duration) _scheduler;

  /// Completes `true` if [window] elapses undisturbed, `false` if
  /// [abortSignal] fires first. The timeout delay is scheduled via the
  /// injected `scheduler` (defaults to a real timer) so tests can control it
  /// without waiting on wall-clock time or real periodic timers.
  Future<bool> run({
    required Duration window,
    required Stream<void> abortSignal,
  }) async {
    final completer = Completer<bool>();
    final sub = abortSignal.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
    });
    unawaited(
      _scheduler(window).then((_) {
        if (!completer.isCompleted) completer.complete(true);
      }),
    );
    final result = await completer.future;
    unawaited(sub.cancel());
    return result;
  }
}
