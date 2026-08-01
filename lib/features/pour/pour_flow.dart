import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;

import '../../domain/keys.dart';
import '../../providers.dart';
import 'pour_screen.dart';

/// Entry point for the `Pour` radial-menu method: pick a live mesh peer
/// (pour is an in-person tilt gesture — same live-peer requirement as the
/// rain screen), then hand off to [PourScreen]. Also offers a way into
/// catch mode (reached via `/pour/catch`) for the other side of the
/// gesture, since neither this menu entry nor the plan wires a separate
/// radial-menu slot for receiving a pour.
class PourFlow extends ConsumerWidget {
  const PourFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meshAsync = ref.watch(meshControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pour'),
        actions: [
          TextButton(
            key: const Key('pour.catch.open'),
            onPressed: () => Navigator.pushNamed(context, '/pour/catch'),
            child: const Text('Catch'),
          ),
        ],
      ),
      body: meshAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text("Couldn't load nearby phones")),
        data: (mesh) {
          final peers = mesh.livePeers;
          if (peers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No phones nearby yet — move closer to a friend!',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final peer in peers)
                FutureBuilder<String?>(
                  future: ref.read(peerDirectoryProvider).nameFor(peer.addr),
                  builder: (context, snap) {
                    final name = snap.data ?? peer.name;
                    final label = name == null
                        ? truncateAddr(peer.addr)
                        : '$name · ${truncateAddr(peer.addr)}';
                    return ListTile(
                      key: Key('pour.peer.${peer.addr}'),
                      title: Text(label),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PourScreen(to: peer.addr, toName: name),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
