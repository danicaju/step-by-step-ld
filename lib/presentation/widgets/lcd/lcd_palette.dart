import 'package:flutter/material.dart';

import '../../theme/theme_controller.dart';

/// Temas de la LCD (SETUP 5).
enum LcdTheme { classic, paper, night }

extension LcdThemeLabel on LcdTheme {
  String get label => switch (this) {
        LcdTheme.classic => 'Clásica (Oliva)',
        LcdTheme.paper => 'Papel (Alto Contraste)',
        LcdTheme.night => 'Nocturno',
      };

  LcdTheme get next => LcdTheme.values[(index + 1) % LcdTheme.values.length];
}

/// Paleta monocromática/oliva de la LCD según el tema.
class LcdPalette {
  final Color background;
  final Color inset;
  final Color border;
  final Color formula;
  final Color original;
  final Color title;

  const LcdPalette({
    required this.background,
    required this.inset,
    required this.border,
    required this.formula,
    required this.original,
    required this.title,
  });

  static const classic = LcdPalette(
    background: Color(0xFFC8D6CD),
    inset: Color(0xFFBDCEBE),
    border: Color(0xFF7A8A7E),
    formula: Color(0xFF1A2530),
    original: Color(0xFF3F4F48),
    title: Color(0xFF2E3B36),
  );
  static const paper = LcdPalette(
    background: Color(0xFFF1F3EC),
    inset: Color(0xFFE2E6DA),
    border: Color(0xFF4A524C),
    formula: Color(0xFF000000),
    original: Color(0xFF2B312D),
    title: Color(0xFF000000),
  );
  static const night = LcdPalette(
    background: Color(0xFF111615),
    inset: Color(0xFF0A0D0C),
    border: Color(0xFF27322E),
    formula: Color(0xFFE8F3EE),
    original: Color(0xFF94A3B8),
    title: Color(0xFF94A3B8),
  );

  static LcdPalette of(LcdTheme t) => switch (t) {
        LcdTheme.classic => _classicForHardware(),
        LcdTheme.paper => paper,
        LcdTheme.night => night,
      };

  /// Paleta clasica con el LCD del tema de hardware activo (`Predeterminado` = original).
  static LcdPalette _classicForHardware() {
    final hw = ThemeController.current;
    if (hw.isDefault) return classic;
    return LcdPalette(
      background: hw.lcdBackground,
      inset: hw.lcdInset,
      border: classic.border,
      formula: classic.formula,
      original: classic.original,
      title: classic.title,
    );
  }
}
