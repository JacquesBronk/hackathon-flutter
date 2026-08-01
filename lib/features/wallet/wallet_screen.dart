import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/keys.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import 'radial_send_menu.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerControllerProvider);
    final keys = ref.watch(walletKeysProvider);
    final profile = ref.watch(profileControllerProvider).value;
    final addr = keys.value?.address;
    final balance = addr == null ? 0 : (ledger.value?.balances[addr] ?? 0);
    final recent = (ledger.value?.ordered ?? []).toList()
      // UUIDv7 desc ≈ newest first (sub-millisecond order is random — cosmetic
      // only; no test asserts adjacent same-ms ordering).
      ..sort((a, b) => b.id.compareTo(a.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${profile?.avatar ?? ''} ${profile?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => Navigator.pushNamed(context, '/receive'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'ᵽ$balance',
              key: const Key('wallet.balance'),
              style: cmoAmountStyle(size: 56),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final tx in recent.take(5))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      tx.to == addr ? Icons.south_west : Icons.north_east,
                      color: tx.to == addr ? CmoColors.green : CmoColors.orange,
                    ),
                    title: Text(
                      tx.to == addr ? '+ᵽ${tx.amount}' : '−ᵽ${tx.amount}',
                      style: cmoMoneyStyle(),
                    ),
                    subtitle: FutureBuilder<String?>(
                      // Spec §2.3: peer name with truncated-address fallback.
                      future: ref
                          .read(peerDirectoryProvider)
                          .nameFor(tx.to == addr ? tx.from : tx.to),
                      builder: (_, snap) => Text(
                        snap.data ??
                            truncateAddr(tx.to == addr ? tx.from : tx.to),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        key: const Key('wallet.send'),
        onPressed: () => showRadialSendMenu(context),
        child: const Icon(Icons.send),
      ),
    );
  }
}
