import 'package:flutter/material.dart';

import 'calculator_themes.dart';

/// Utilidades de contraste WCAG 2.x para los temas de hardware.
abstract final class ThemeContrast {
  /// Minimos usados en la app y en `theme_contrast_audit_test`.
  static const double text = 4.5; // texto principal y leyendas pequenas
  static const double large = 3.0; // etiquetas grandes, iconos y teclas

  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// [fg] si ya cumple [min] sobre [bg]; si no, el mismo tono aclarado u oscurecido
  /// hasta cumplirlo (o blanco / tinta si el tono no llega).
  static Color ensure(Color fg, Color bg, double min) {
    if (ratio(fg, bg) >= min) return fg;
    const white = Color(0xFFFFFFFF);
    const ink = Color(0xFF14181F);
    final lighten = ratio(white, bg) >= ratio(ink, bg);
    final hsl = HSLColor.fromColor(fg);
    for (var i = 1; i <= 50; i++) {
      final l = (hsl.lightness + (lighten ? i : -i) * 0.02).clamp(0.0, 1.0);
      final c = hsl.withLightness(l).toColor();
      if (ratio(c, bg) >= min) return c;
    }
    return lighten ? white : ink;
  }

  /// Color legible (blanco o tinta) para un texto sobre [bg].
  static Color onColor(Color bg, {double min = text}) =>
      ensure(bg.computeLuminance() < 0.35 ? const Color(0xFFFFFFFF) : const Color(0xFF14181F), bg, min);
}

/// Colores derivados del tema con contraste garantizado (leyendas sobre teclas,
/// botones de accion del panel y hojas modales). `Predeterminado` solo se corrige
/// cuando una pareja cae por debajo de 3:1 (ilegible).
extension HardwareThemeContrast on CalculatorHardwareTheme {
  double get _minLegend => isDefault ? ThemeContrast.large : ThemeContrast.text;

  /// Leyenda SHIFT (ambar) o ALPHA (rojo) impresa DENTRO de una tecla de fondo [keyBg]
  /// (SETUP/OPTN sobre MODE/CALC y caras SHIFT/ALPHA activas).
  Color shiftLegendOn(Color keyBg) => ThemeContrast.ensure(
      keyBg.computeLuminance() < 0.35 ? shiftKey : shiftLegend, keyBg, _minLegend);

  Color alphaLegendOn(Color keyBg) => ThemeContrast.ensure(
      keyBg.computeLuminance() < 0.35 ? (isDefault ? legendAlpha : alphaKey) : alphaLegend,
      keyBg,
      _minLegend);

  // --- Panel derecho y hojas modales -------------------------------------------------
  static const Color _teal = Color(0xFF0F766E);

  /// Boton de accion principal (EXPORTAR PNG, Exportar PNG Transparente).
  Color get actionBg => isDefault ? _teal : panelText;
  Color get actionFg => ThemeContrast.ensure(isDefault ? Colors.white : panelBg, actionBg, ThemeContrast.text);

  /// Boton de accion secundario (COPIAR LaTeX, LaTeX).
  Color get action2Bg => panelAccent;
  Color get action2Fg =>
      ThemeContrast.ensure(isDefault ? const Color(0xFF1A2530) : panelBg, action2Bg, ThemeContrast.text);

  /// Texto de acento sobre el panel (insignias, iconos de cabecera).
  Color get panelAccentText => ThemeContrast.ensure(
      ThemeContrast.ensure(panelAccent, panelBg, ThemeContrast.text), panelTabBar, ThemeContrast.text);

  /// Tinta para el PNG exportado (papel claro/transparente): el acento del tema oscurecido.
  Color get inkOnPaper => ThemeContrast.ensure(panelAccent, const Color(0xFFFAF8F4), ThemeContrast.text);
}
