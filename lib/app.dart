import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/root/root_gate.dart';
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
      routes: {'/': (_) => const RootGate()},
      // '/send', '/receive', '/history' are pushed with MaterialPageRoute
      // by feature code (T5/T6) — no additional named-route edits here.
    ),
  );
}
