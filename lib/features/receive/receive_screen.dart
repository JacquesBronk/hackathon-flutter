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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _scanning
            ? _buildScanning()
            : _buildShowQr(keys.address, profile.name),
      ),
    );
  }

  Widget _buildShowQr(String addr, String name) {
    final received = _received;
    if (received != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
