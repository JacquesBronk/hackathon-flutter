import 'dart:async';

import 'package:cash_me_outside/state/grace_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completes true when the scheduled timeout fires before abort',
    () async {
      final timeout = Completer<void>();
      final gw = GraceWindow(scheduler: (_) => timeout.future);
      final abort = StreamController<void>.broadcast();

      final result = gw.run(
        window: const Duration(seconds: 5),
        abortSignal: abort.stream,
      );
      timeout.complete();
      expect(await result, isTrue);

      await abort.close();
    },
  );

  test('completes false when abortSignal fires before the timeout', () async {
    final timeout = Completer<void>(); // never completes
    final gw = GraceWindow(scheduler: (_) => timeout.future);
    final abort = StreamController<void>.broadcast();

    final result = gw.run(
      window: const Duration(seconds: 5),
      abortSignal: abort.stream,
    );
    abort.add(null);
    expect(await result, isFalse);

    await abort.close();
  });

  test('a late abort after the timeout already fired has no effect', () async {
    final timeout = Completer<void>();
    final gw = GraceWindow(scheduler: (_) => timeout.future);
    final abort = StreamController<void>.broadcast();

    final result = gw.run(
      window: const Duration(seconds: 5),
      abortSignal: abort.stream,
    );
    timeout.complete();
    expect(await result, isTrue);
    abort.add(
      null,
    ); // late — must not throw or change the already-resolved result

    await abort.close();
  });

  test('passes the requested window to the scheduler', () async {
    Duration? requested;
    final gw = GraceWindow(
      scheduler: (d) {
        requested = d;
        return Completer<void>().future; // never fires — abort resolves it
      },
    );
    final abort = StreamController<void>.broadcast();
    final result = gw.run(
      window: const Duration(seconds: 7),
      abortSignal: abort.stream,
    );
    abort.add(null);
    await result;
    expect(requested, const Duration(seconds: 7));

    await abort.close();
  });
}
