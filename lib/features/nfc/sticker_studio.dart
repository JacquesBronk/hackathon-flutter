import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/canonical.dart';
import '../../providers.dart';
import '../../theme/coin.dart';
import '../../theme/tokens.dart';

/// Sticker studio: write NTAG payment-request stickers and claimable voucher
/// stickers ("stick ᵽ50 under a chair" — spec §4). Also surfaces the
/// coin-flip banner when any NFC read claims a voucher, since
/// [NfcController] listens for tag reads as soon as it's built, independent
/// of which button the user tapped.
class StickerStudio extends ConsumerStatefulWidget {
  const StickerStudio({super.key});

  @override
  ConsumerState<StickerStudio> createState() => _StickerStudioState();
}

class _StickerStudioState extends ConsumerState<StickerStudio> {
  final _requestAmountController = TextEditingController();
  final _voucherAmountController = TextEditingController();
  int? _claimAmount;
  int _claimEventId = 0;

  @override
  void dispose() {
    _requestAmountController.dispose();
    _voucherAmountController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _writeRequestTag() async {
    final amount = int.tryParse(_requestAmountController.text);
    await ref
        .read(nfcControllerProvider.notifier)
        .writeRequestTag(amount: amount);
    _showSnack('Request sticker written — tap a tag to save it');
  }

  Future<void> _writeVoucherTag() async {
    final amount = int.tryParse(_voucherAmountController.text);
    if (amount == null || amount < 1 || amount > maxAmount) {
      _showSnack("That's not a real amount of pinnies");
      return;
    }
    final wrote = await ref
        .read(nfcControllerProvider.notifier)
        .writeVoucherTag(amount);
    if (!mounted) return;
    _showSnack(
      wrote ? 'Voucher sticker written — first to sync wins' : 'Biometric check failed',
    );
  }

  /// A read of ANY kind can arrive here — only voucher claims move
  /// [NfcState.lastClaimAmount]. Compares against the previous value so an
  /// unrelated state change (e.g. tap-mode toggling elsewhere) doesn't
  /// replay the banner for a claim already shown.
  void _onNfcState(AsyncValue<NfcState>? previous, AsyncValue<NfcState> next) {
    final amount = next.valueOrNull?.lastClaimAmount;
    if (amount == null) return;
    if (previous?.valueOrNull?.lastClaimAmount == amount) return;
    setState(() {
      _claimAmount = amount;
      _claimEventId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nfcControllerProvider, _onNfcState);
    return Scaffold(
      appBar: AppBar(title: const Text('Sticker studio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_claimAmount != null) ...[
              _buildClaimBanner(),
              const SizedBox(height: 24),
            ],
            Text(
              'Payment request sticker',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Anyone who taps pays you — like your QR code, but on a tag.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sticker.request.amount'),
              controller: _requestAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('nfc.write.request'),
              onPressed: _writeRequestTag,
              child: const Text('Write request sticker'),
            ),
            const Divider(height: 48),
            Text(
              'Voucher sticker',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Anyone who taps can claim — first to sync wins, chaos is '
              'the point.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('nfc.voucher.amount'),
              controller: _voucherAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('nfc.write.voucher'),
              onPressed: _writeVoucherTag,
              child: const Text('Write voucher sticker'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimBanner() => Container(
    key: const Key('nfc.claim.result'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: CmoColors.green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PinnieCoin(key: ValueKey(_claimEventId), size: 48, flipOnBuild: true),
        const SizedBox(width: 12),
        Text(
          '+ᵽ$_claimAmount',
          style: cmoAmountStyle(color: CmoColors.green, size: 28),
        ),
      ],
    ),
  );
}
