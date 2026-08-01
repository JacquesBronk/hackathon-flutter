import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/ledger.dart';
import '../../domain/qr_codec.dart';
import '../../domain/transaction.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool _scanning = false;
  StreamSubscription<String>? _sub;
  final _amountController = TextEditingController();
  Transaction? _received;

  @override
  void dispose() {
    _sub?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Real-hardware note (C3): HCE has no maintained Flutter plugin yet, so
  /// this throws on-device — caught here rather than left to crash the
  /// toggle. Sticker read/write are unaffected.
  Future<void> _enableTapMode(int? amount) async {
    try {
      await ref
          .read(nfcControllerProvider.notifier)
          .enableTapMode(amount: amount);
    } catch (_) {
      _showSnack("Tap mode isn't available on this phone");
    }
  }

  Future<void> _disableTapMode() async {
    await ref.read(nfcControllerProvider.notifier).disableTapMode();
  }

  void _startScanning() {
    setState(() {
      _scanning = true;
      _received = null;
    });
    _sub ??= ref.read(qrScannerProvider).scans.listen(_onScan);
  }

  void _stopScanning() {
    setState(() => _scanning = false);
  }

  Future<void> _onScan(String raw) async {
    final QrPayload payload;
    try {
      payload = decodeQr(raw);
    } on QrDecodeException {
      _showSnack('Not a pinnie code');
      return;
    }
    switch (payload) {
      case SignedTransactionPayload stp:
        final result = await ref
            .read(ledgerControllerProvider.notifier)
            .ingestExternal(stp.transaction);
        switch (result.status) {
          case IngestStatus.added:
            setState(() {
              _scanning = false;
              _received = stp.transaction;
            });
          case IngestStatus.rejected:
            _showSnack('Counterfeit pinnies rejected');
          case IngestStatus.duplicate:
            _showSnack('Already got those');
        }
      case ReceiveRequest _:
        _showSnack("That's a request code — use Send");
      case VoucherPayload _:
        _showSnack("That's a voucher — use NFC to claim it");
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(walletKeysProvider).valueOrNull;
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    if (keys == null || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: _scanning
          ? Padding(padding: const EdgeInsets.all(24), child: _buildScanning())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildShowQr(keys.address, profile.name),
            ),
    );
  }

  Widget _buildShowQr(String addr, String name) {
    final received = _received;
    if (received != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PinnieCoin(flipOnBuild: true),
          const SizedBox(height: 16),
          Text(
            '+ᵽ${received.amount}',
            style: cmoAmountStyle(color: CmoColors.green),
          ),
        ],
      );
    }
    final amount = int.tryParse(_amountController.text);
    final data = encodeReceiveRequest(
      ReceiveRequest(addr: addr, name: name, amount: amount),
    );
    final tapModeActive =
        ref.watch(nfcControllerProvider).valueOrNull?.tapModeActive ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(data: data, size: 260),
        const SizedBox(height: 16),
        TextField(
          key: const Key('receive.amount'),
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (optional)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('receive.scan'),
          onPressed: _startScanning,
          child: const Text("Scan sender's code"),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tap mode'),
            Switch(
              key: const Key('nfc.tapmode.toggle'),
              value: tapModeActive,
              onChanged: (active) =>
                  active ? _enableTapMode(amount) : _disableTapMode(),
            ),
          ],
        ),
        // NFC-active indicator (README §5).
        if (tapModeActive)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc, color: CmoColors.orange),
                SizedBox(width: 8),
                Text('NFC active — tap to pay'),
              ],
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('nfc.stickerStudio'),
          onPressed: () => Navigator.pushNamed(context, '/nfc'),
          child: const Text('Write NFC stickers'),
        ),
      ],
    );
  }

  Widget _buildScanning() {
    return Column(
      children: [
        Expanded(child: ref.read(qrScannerProvider).buildPreview()),
        const SizedBox(height: 16),
        TextButton(
          key: const Key('receive.showqr'),
          onPressed: _stopScanning,
          child: const Text('Show my code'),
        ),
      ],
    );
  }
}
