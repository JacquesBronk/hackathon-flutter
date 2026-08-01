import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/canonical.dart';
import '../../domain/keys.dart';
import '../../domain/qr_codec.dart';
import '../../domain/transaction.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';

enum _Phase { scan, confirm, code }

class SendFlow extends ConsumerStatefulWidget {
  const SendFlow({super.key});

  @override
  ConsumerState<SendFlow> createState() => _SendFlowState();
}

class _SendFlowState extends ConsumerState<SendFlow> {
  _Phase _phase = _Phase.scan;
  StreamSubscription<String>? _sub;
  ReceiveRequest? _rr;
  Transaction? _tx;
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = ref.read(qrScannerProvider).scans.listen(_onScan);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _onScan(String raw) {
    final QrPayload payload;
    try {
      payload = decodeQr(raw);
    } on QrDecodeException {
      _showSnack('Not a pinnie code');
      return;
    }
    switch (payload) {
      case ReceiveRequest rr:
        ref.read(peerDirectoryProvider).record(rr.addr, rr.name);
        _amountController.text = rr.amount?.toString() ?? '';
        setState(() {
          _rr = rr;
          _phase = _Phase.confirm;
        });
      case SignedTransactionPayload _:
        _showSnack("That's a payment code — use Receive");
      case VoucherPayload _:
        _showSnack("That's a voucher — use NFC to claim it");
    }
  }

  Future<void> _confirm() async {
    final rr = _rr!;
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
      final tx = await ref
          .read(ledgerControllerProvider.notifier)
          .send(to: rr.addr, amount: amount, memo: memo.isEmpty ? null : memo);
      setState(() {
        _tx = tx;
        _phase = _Phase.code;
      });
    } catch (_) {
      _showSnack("Couldn't save — try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.scan:
        return Scaffold(
          appBar: AppBar(title: const Text('Send')),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ref.read(qrScannerProvider).buildPreview(),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: CmoColors.orange, width: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case _Phase.confirm:
        final rr = _rr!;
        return Scaffold(
          appBar: AppBar(title: const Text('Confirm')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: PinnieCoin(size: 72)),
                const SizedBox(height: 16),
                Text(rr.name, textAlign: TextAlign.center),
                Text(truncateAddr(rr.addr), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('send.amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  key: const Key('send.memo'),
                  controller: _memoController,
                  decoration: const InputDecoration(labelText: 'Memo'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('send.confirm'),
                  onPressed: _confirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        );
      case _Phase.code:
        return Scaffold(
          appBar: AppBar(title: const Text('Sent')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QrImageView(data: encodeTransaction(_tx!), size: 260),
                const SizedBox(height: 16),
                const Text('Have them scan this with Receive'),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('send.done'),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text("They scanned it — Done"),
                ),
              ],
            ),
          ),
        );
    }
  }
}
