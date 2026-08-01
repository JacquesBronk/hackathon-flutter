import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/history/history_screen.dart';
import 'features/receive/receive_screen.dart';
import 'features/root/root_gate.dart';
import 'features/send/send_flow.dart';
import 'theme/tokens.dart';

class CashMeOutsideApp extends StatelessWidget {
  const CashMeOutsideApp({super.key, this.overrides = const []});
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      title: 'Cash Me Outside',
      theme: buildCmoTheme(),
      routes: {
        '/': (_) => const RootGate(),
        '/send': (_) => const SendFlow(),
        '/receive': (_) => const ReceiveScreen(),
        '/history': (_) => const HistoryScreen(),
      },
    ),
  );
}
