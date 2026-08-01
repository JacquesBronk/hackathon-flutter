import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/keys.dart';
import 'features/history/history_screen.dart';
import 'features/nfc/sticker_studio.dart';
import 'features/radar/radar_screen.dart';
import 'features/receive/receive_screen.dart';
import 'features/root/root_gate.dart';
import 'features/send/mesh_send_flow.dart';
import 'features/send/send_flow.dart';
import 'providers.dart';
import 'theme/tokens.dart';

class CashMeOutsideApp extends StatelessWidget {
  const CashMeOutsideApp({
    super.key,
    this.overrides = const [],
    this.enableMeshRealWiring = false,
  });
  final List<Override> overrides;

  /// Starts the BLE transport + 30s presence timer once a wallet exists.
  /// Real (non-`FAKE_HARDWARE`) runs only — periodic timers must never fire
  /// under widget tests (Global Constraints: no auto-starting timers).
  final bool enableMeshRealWiring;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      title: 'Cash Me Outside',
      theme: buildCmoTheme(),
      builder: (context, child) =>
          enableMeshRealWiring ? _MeshRealWiring(child: child!) : child!,
      routes: {
        '/': (_) => const RootGate(),
        '/send': (_) => const SendFlow(),
        '/receive': (_) => const ReceiveScreen(),
        '/history': (_) => const HistoryScreen(),
        '/nfc': (_) => const StickerStudio(),
        '/send-mesh': (context) => MeshSendFlow(
          initialPeerAddr:
              ModalRoute.of(context)?.settings.arguments as String?,
        ),
        '/radar': (_) => Consumer(
          builder: (context, ref, _) {
            final mesh = ref.watch(meshControllerProvider);
            if (!mesh.hasValue) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return RadarScreen(
              relayEvents: ref.read(meshControllerProvider.notifier).relays,
            );
          },
        ),
      },
    ),
  );
}

/// Real-hardware-only bootstrap: once a wallet exists, starts the mesh
/// transport and broadcasts presence on start + every 30s (spec §2.2 rule
/// 7). `MeshController` itself exposes only one-shot methods — this is the
/// sole place periodic timers live (Global Constraints).
class _MeshRealWiring extends ConsumerStatefulWidget {
  const _MeshRealWiring({required this.child});
  final Widget child;

  @override
  ConsumerState<_MeshRealWiring> createState() => _MeshRealWiringState();
}

class _MeshRealWiringState extends ConsumerState<_MeshRealWiring> {
  Timer? _presenceTimer;
  bool _starting = false;

  Future<void> _maybeStart(WalletKeys? keys) async {
    if (_starting || keys == null) return;
    _starting = true;
    await ref.read(meshControllerProvider.future);
    await ref.read(meshTransportProvider).start();
    await ref.read(meshControllerProvider.notifier).broadcastPresenceOnce();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.read(meshControllerProvider.notifier).broadcastPresenceOnce(),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(walletKeysProvider).valueOrNull;
    unawaited(_maybeStart(keys));
    return widget.child;
  }
}
