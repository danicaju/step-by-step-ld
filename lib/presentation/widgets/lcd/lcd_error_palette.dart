import 'package:flutter/material.dart';

import '../../theme/calculator_themes.dart';
import '../../theme/theme_contrast.dart';

/// Colores de la pantalla de error de la LCD, con contraste garantizado (WCAG) tanto con el
/// interior de la LCD claro como oscuro (icono de la media luna) y en los 5 temas de hardware.
class LcdErrorPalette {
  /// Fondo de la LCD.
  final Color bg;

  /// Fondo de la tarjeta (diferenciable del fondo).
  final Color card;

  /// Fondo de la cabecera con el tipo de error.
  final Color header;

  /// Titulo `Math ERROR` (sobre [header]).
  final Color title;

  /// Icono de la cabecera (sobre [header]).
  final Color icon;

  /// Texto del mensaje (sobre [card]).
  final Color body;

  /// Texto de la sugerencia (sobre [card]).
  final Color hint;

  /// Icono de la bombilla de la sugerencia (sobre [card]).
  final Color hintIcon;

  const LcdErrorPalette._({
    required this.bg,
    required this.card,
    required this.header,
    required this.title,
    required this.icon,
    required this.body,
    required this.hint,
    required this.hintIcon,
  });

  static const Color _ink = Color(0xFF1A2530);
  static const Color _shift = Color(0xFFE5A93C);
  static const Color _alpha = Color(0xFFE05D5D);

  /// Contraste minimo objetivo del titulo y del cuerpo.
  static const double minTitle = 7.0;

  static LcdErrorPalette of(CalculatorHardwareTheme hw, {required bool dark}) {
    if (dark) {
      const bg = Color(0xFF111615);
      const card = Color(0xFF1F2A26);
      const header = Color(0xFF2A1A19);
      return LcdErrorPalette._(
        bg: bg,
        card: card,
        header: header,
        title: ThemeContrast.ensure(const Color(0xFFFF8A80), header, minTitle),
        icon: ThemeContrast.ensure(_shift, header, ThemeContrast.text),
        body: ThemeContrast.ensure(const Color(0xFFE6ECE8), card, minTitle),
        hint: ThemeContrast.ensure(const Color(0xFFCBD5CE), card, ThemeContrast.text),
        hintIcon: ThemeContrast.ensure(_shift, card, ThemeContrast.text),
      );
    }
    final bg = hw.lcdBackground;
    final card = hw.lcdInset;
    final header = Color.alphaBlend(_alpha.withValues(alpha: 0.22), card);
    return LcdErrorPalette._(
      bg: bg,
      card: card,
      header: header,
      title: ThemeContrast.ensure(_ink, header, minTitle),
      icon: ThemeContrast.ensure(_alpha, header, ThemeContrast.text),
      body: ThemeContrast.ensure(_ink, card, minTitle),
      hint: ThemeContrast.ensure(_ink, card, minTitle),
      hintIcon: ThemeContrast.ensure(_alpha, card, ThemeContrast.text),
    );
  }
}
