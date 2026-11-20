import 'package:flutter/material.dart';

import '../theme/theme_contrast.dart';
import '../widgets/lcd/lcd_palette.dart';

/// Paleta de la recta real de signos: sale de la LCD activa (clara u oscura) y de la paleta
/// Casio (SHIFT ambar, ALPHA rojo). Sin azul, cian ni morado.
class NumberLinePalette {
  final Color panel;
  final Color border;
  final Color ink;
  final Color axis;
  final Color accent;
  final Color alpha;
  final Color yesBg;
  final Color yesFg;
  final Color noBg;
  final Color noFg;

  const NumberLinePalette._({
    required this.panel,
    required this.border,
    required this.ink,
    required this.axis,
    required this.accent,
    required this.alpha,
    required this.yesBg,
    required this.yesFg,
    required this.noBg,
    required this.noFg,
  });

  static const Color _shift = Color(0xFFE5A93C);
  static const Color _alpha = Color(0xFFE05D5D);

  factory NumberLinePalette.of({required bool dark}) {
    final pal = LcdPalette.of(dark ? LcdTheme.night : LcdTheme.classic);
    final ink = pal.formula;
    final accent = dark ? _shift : ink;
    final alpha = dark ? _alpha : ThemeContrast.ensure(_alpha, pal.inset, ThemeContrast.large);
    return NumberLinePalette._(
      panel: pal.inset,
      border: pal.border,
      ink: ink,
      axis: ink.withValues(alpha: 0.85),
      accent: accent,
      alpha: alpha,
      yesBg: accent,
      yesFg: ThemeContrast.onColor(accent),
      noBg: alpha,
      noFg: ThemeContrast.onColor(alpha),
    );
  }

  /// Color del titulo `RECTA REAL DE SIGNOS` (ambar en LCD oscuro, tinta en LCD claro).
  Color get title => accent;
}
