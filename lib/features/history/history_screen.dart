import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/keys.dart';
import '../../domain/qr_codec.dart';
import '../../domain/transaction.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(walletKeysProvider).valueOrNull;
    final ledgerState = ref.watch(ledgerControllerProvider).valueOrNull;
    if (keys == null || ledgerState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final myAddr = keys.address;
    final peerDirectory = ref.watch(peerDirectoryProvider);
    final deliveries =
        ref.watch(meshControllerProvider).valueOrNull?.deliveries ?? const {};
    final ordered = [...ledgerState.ordered]
      ..sort((a, b) => b.id.compareTo(a.id));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.builder(
        itemCount: ordered.length,
        itemBuilder: (context, index) {
          final tx = ordered[index];
          final isMint = tx.type == txTypeMint;
          final counterparty = tx.to == myAddr ? tx.from : tx.to;
          final Future<String?>? nameFuture = isMint
              ? null
              : peerDirectory.nameFor(counterparty);
          return FutureBuilder<String?>(
            future: nameFuture,
            builder: (context, snapshot) {
              final name = snapshot.data;
              final title = isMint
                  ? 'Minted'
                  : (name == null
                        ? truncateAddr(counterparty)
                        : '$name · ${truncateAddr(counterparty)}');
              final deliveryStatus =
                  tx.type == txTypeTransfer && tx.from == myAddr
                  ? deliveries[tx.id]
                  : null;
              return ExpansionTile(
                title: Text(title),
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.to == myAddr ? '+ᵽ${tx.amount}' : '−ᵽ${tx.amount}',
                      style: cmoMoneyStyle(),
                    ),
                    if (deliveryStatus != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        key: Key('mesh.status.${tx.id}'),
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          deliveryStatus == MeshDeliveryStatus.delivered
                              ? 'Delivered'
                              : 'Hopping…',
                        ),
                      ),
                    ],
                  ],
                ),
                children: [
                  if (tx.memo != null) ListTile(title: Text(tx.memo!)),
                  ListTile(title: SelectableText('id: ${tx.id}')),
                  ListTile(title: Text('lamportTs: ${tx.lamportTs}')),
                  ListTile(title: SelectableText('from: ${tx.from}')),
                  ListTile(title: SelectableText('to: ${tx.to}')),
                  if (tx.type == txTypeTransfer && tx.from == myAddr)
                    TextButton(
                      key: Key('history.showcode.${tx.id}'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: QrImageView(
                              data: encodeTransaction(tx),
                              size: 240,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Show code'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
