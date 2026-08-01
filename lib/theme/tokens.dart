import 'package:flutter/material.dart';

abstract final class CmoColors {
  static const green = Color(0xFF3E6B4F);
  static const cream = Color(0xFFF2EBD9);
  static const orange = Color(0xFFFF5A1F); // money-in-motion ONLY
  static const navy = Color(0xFF1E2733);
  static const brass = Color(0xFFC9A54A);
}

/// Slab display style for amounts/headers. Tabular figures everywhere numbers appear.
TextStyle cmoAmountStyle({double size = 40, Color color = CmoColors.navy}) =>
    TextStyle(
      fontFamily: 'AlfaSlabOne',
      fontSize: size,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Inter with tabular figures — for every NON-hero amount string ('+ᵽ12'
/// activity rows, history amounts). Spec §2.6: tabular figures wherever
/// numbers appear, not just the balance hero.
TextStyle cmoMoneyStyle({
  double size = 14,
  Color color = CmoColors.navy,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  color: color,
  fontWeight: weight,
  fontFeatures: const [FontFeature.tabularFigures()],
);

ThemeData buildCmoTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: CmoColors.green,
      primary: CmoColors.green,
      surface: CmoColors.cream,
    ),
    scaffoldBackgroundColor: CmoColors.cream,
    fontFamily: 'Inter',
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CmoColors.navy,
      displayColor: CmoColors.navy,
    ),
  );
}
