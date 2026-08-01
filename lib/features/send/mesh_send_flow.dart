import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/canonical.dart';
import '../../domain/keys.dart';
import '../../providers.dart';

enum _Phase { pick, amount, status }

/// Mesh-send flow: peer picker (live mesh peers, unauthenticated names
/// always paired with the truncated address) → amount/memo → existing
/// biometric gate → [MeshController.sendMeshTx] → delivery-status screen
/// keyed by transaction id (`mesh.status.<txId>`), animating hopping →
/// delivered as receipts arrive.
class MeshSendFlow extends ConsumerStatefulWidget {
  const MeshSendFlow({super.key, this.initialPeerAddr});

  /// Pre-selects a peer and starts at the amount phase — set when arriving
  /// from a radar blip tap (spec §2.4). The name is resolved from
  /// [PeerDirectory]; unauthenticated-name display rules still apply.
  final String? initialPeerAddr;

  @override
  ConsumerState<MeshSendFlow> createState() => _MeshSendFlowState();
}

class _MeshSendFlowState extends ConsumerState<MeshSendFlow> {
  late _Phase _phase;
  MeshPeer? _peer;
  String? _peerName;
  String? _txId;
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialAddr = widget.initialPeerAddr;
    if (initialAddr == null) {
      _phase = _Phase.pick;
    } else {
      _phase = _Phase.amount;
      _peer = MeshPeer(
        addr: initialAddr,
        name: null,
        rssi: -127,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      );
      unawaited(_resolveInitialPeerName(initialAddr));
    }
  }

  Future<void> _resolveInitialPeerName(String addr) async {
    final name = await ref.read(peerDirectoryProvider).nameFor(addr);
    if (!mounted || name == null) return;
    setState(() => _peerName = name);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _pickPeer(MeshPeer peer, String? name) {
    setState(() {
      _peer = peer;
      _peerName = name;
      _phase = _Phase.amount;
    });
  }

  Future<void> _confirm() async {
    final peer = _peer!;
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount < 1 || amount > maxAmount) {
      _showSnack("That's not a real amount of pinnies");
      return;
    }
    final approved = await ref
        .read(biometricGateProvider)
        .authenticate('Confirm sending ᵽ$amount');
    if (!approved) {
      _showSnack('Biometric check failed');
      return;
    }
    try {
      final memo = _memoController.text.trim();
      final txId = await ref
          .read(meshControllerProvider.notifier)
          .sendMeshTx(
            to: peer.addr,
            amount: amount,
            memo: memo.isEmpty ? null : memo,
          );
      if (!mounted) return;
      setState(() {
        _txId = txId;
        _phase = _Phase.status;
      });
    } catch (_) {
      _showSnack("Couldn't send — try again");
    }
  }

  String _displayName(String addr, String? name) =>
      name == null ? truncateAddr(addr) : '$name · ${truncateAddr(addr)}';

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.pick:
        return _buildPicker(context);
      case _Phase.amount:
        return _buildAmount(context);
      case _Phase.status:
        return _buildStatus(context);
    }
  }

  Widget _buildPicker(BuildContext context) {
    final meshAsync = ref.watch(meshControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Send via mesh')),
      body: meshAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text("Couldn't load nearby phones")),
        // Spec §2.4: the picker is the UNION of live mesh peers (badged
        // 'live') and every PeerDirectory entry ever seen — offline peers
        // are pickable; delivery then rides the store-and-forward outbox.
        data: (mesh) => FutureBuilder<List<({String addr, String name})>>(
          future: ref.read(peerDirectoryProvider).entries(),
          builder: (context, snapshot) {
            final live = mesh.livePeers;
            final liveAddrs = {for (final p in live) p.addr};
            final known = (snapshot.data ?? const [])
                .where((e) => !liveAddrs.contains(e.addr))
                .toList();
            if (live.isEmpty && known.isEmpty) {
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
                for (final peer in live)
                  FutureBuilder<String?>(
                    future: ref.read(peerDirectoryProvider).nameFor(peer.addr),
                    builder: (context, snap) {
                      final name = snap.data ?? peer.name;
                      return ListTile(
                        key: Key('mesh.peer.${peer.addr}'),
                        title: Text(_displayName(peer.addr, name)),
                        trailing: const Chip(label: Text('live')),
                        onTap: () => _pickPeer(peer, name),
                      );
                    },
                  ),
                for (final e in known)
                  ListTile(
                    key: Key('mesh.peer.${e.addr}'),
                    title: Text(_displayName(e.addr, e.name)),
                    trailing: const Chip(label: Text('known')),
                    onTap: () => _pickPeer(
                      MeshPeer(
                        addr: e.addr,
                        name: e.name,
                        rssi: -127,
                        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
                      ),
                      e.name,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAmount(BuildContext context) {
    final peer = _peer!;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _displayName(peer.addr, _peerName),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('mesh.send.amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              key: const Key('mesh.send.memo'),
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'Memo'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('mesh.send.confirm'),
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final status =
        ref.watch(meshControllerProvider).valueOrNull?.deliveries[_txId] ??
        MeshDeliveryStatus.hopping;
    final delivered = status == MeshDeliveryStatus.delivered;
    return Scaffold(
      appBar: AppBar(title: const Text('Sent')),
      body: Center(
        child: Chip(
          key: Key('mesh.status.$_txId'),
          avatar: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              delivered ? Icons.check_circle : Icons.wifi_tethering,
              key: ValueKey(delivered),
            ),
          ),
          label: Text(delivered ? 'Delivered' : 'Hopping…'),
        ),
      ),
    );
  }
}
