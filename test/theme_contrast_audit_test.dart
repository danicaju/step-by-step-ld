@Tags(['slow'])
library;

import 'package:casio_tutor_calc/main.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auditoria WCAG de TODOS los pares (primer plano, fondo) de los 5 temas de hardware.
///
/// Minimos: 4.5:1 en texto principal y leyendas pequenas; 3.0:1 en etiquetas grandes,
/// iconos y teclas. `Predeterminado` conserva su paleta original: solo se le exige
/// 3.0:1 en las caras de tecla (ALPHA rojo sobre gris, etc.), nunca por debajo.
const double _text = ThemeContrast.text;
const double _large = ThemeContrast.large;

typedef _Key = (String label, Color? bg, Color? text);

const List<_Key> _keys = [
  ('7', null, null), // numerica
  ('sin', Color(0xFF1F2227), null), // cientifica
  ('x²', Color(0xFF4A4F5C), null), // operacion
  ('DEL', Color(0xFF4A4F5C), null),
  ('AC', Color(0xFF4A4F5C), null),
  ('SHIFT', Color(0xFFE5A93C), Colors.black),
  ('ALPHA', Color(0xFFE05252), Colors.white),
  ('MODE', Color(0xFF2E5A50), Colors.white),
  ('CALC', Color(0xFF1F2227), Colors.white),
];

void main() {
  test('contraste WCAG de los 5 temas: ningun par por debajo del minimo', () {
    expect(HardwareThemes.all.length, 5);
    final fails = <String>[];

    void check(CalculatorHardwareTheme hw, String pair, Color fg, Color bg, double min) {
      final r = ThemeContrast.ratio(fg, bg);
      if (r < min) {
        fails.add('${hw.name} · $pair: ${r.toStringAsFixed(2)} < $min');
      }
    }

    for (final hw in HardwareThemes.all) {
      final keyMin = hw.isDefault ? _large : _text;

      // Teclas: etiqueta principal sobre su fondo + leyendas SHIFT/ALPHA (cara activa).
      for (final (label, ob, ot) in _keys) {
        final st = hw.keyStyle(label, ob, ot);
        check(hw, 'tecla $label', st.text, st.background, keyMin);
        check(hw, 'cara SHIFT sobre $label', hw.shiftLegendOn(st.background), st.background, keyMin);
        check(hw, 'cara ALPHA sobre $label', hw.alphaLegendOn(st.background), st.background, keyMin);
      }
      // SETUP sobre MODE y OPTN / `=` sobre CALC (leyendas de 7-8.5 px).
      final mode = hw.keyStyle('MODE', const Color(0xFF2E5A50), Colors.white);
      final calc = hw.keyStyle('CALC', const Color(0xFF1F2227), Colors.white);
      check(hw, 'SETUP sobre MODE', hw.shiftLegendOn(mode.background), mode.background, keyMin);
      check(hw, 'OPTN sobre CALC', hw.shiftLegendOn(calc.background), calc.background, keyMin);
      check(hw, '= (ALPHA) sobre CALC', hw.alphaLegendOn(calc.background), calc.background, keyMin);

      // Leyendas SHIFT / ALPHA impresas sobre el chasis (todo el degradado).
      for (final (n, c) in [('arriba', hw.chassisTop), ('centro', hw.chassisMid), ('abajo', hw.chassisBottom)]) {
        check(hw, 'leyenda SHIFT sobre chasis $n', hw.legendShift, c, keyMin);
        check(hw, 'leyenda ALPHA sobre chasis $n', hw.legendAlpha, c, keyMin);
      }

      // D-Pad.
      check(hw, 'icono D-Pad', hw.dpadIcon, hw.dpadBody, _large);

      // LCD y pantalla Syntax/Math ERROR (tinta Casio sobre fondo y tarjeta).
      const ink = Color(0xFF1A2530);
      check(hw, 'LCD tinta/fondo', ink, hw.lcdBackground, _text);
      check(hw, 'LCD tinta/inset', ink, hw.lcdInset, _text);
      check(hw, 'ERROR titulo (LCD sobre cabecera)', hw.lcdBackground, ink, _text);
      check(hw, 'ERROR "Como solucionarlo" (tarjeta)', ink, hw.lcdInset, _text);
      check(hw, 'ERROR icono pista', ThemeContrast.ensure(const Color(0xFFE5A93C), hw.lcdInset, _large),
          hw.lcdInset, _large);

      // Barra superior.
      check(hw, 'AppBar titulo', hw.appBarTitle, hw.appBarBg, _text);
      check(hw, 'AppBar acento (icono)', hw.appBarAccent, hw.appBarBg, _large);
      check(hw, 'Botones TEMA/HIST/PNG/TEX', hw.barButtonText, hw.barButtonBg, _text);

      // Panel derecho, hojas modales (PNG, LaTeX/OPTN, resumen, HIST, TEMA).
      for (final (n, bg) in [('panelBg', hw.panelBg), ('panelCard', hw.panelCard), ('panelTabBar', hw.panelTabBar)]) {
        check(hw, 'panelText/$n', hw.panelText, bg, _text);
        check(hw, 'panelAccentText/$n', hw.panelAccentText, bg, _text);
      }
      check(hw, 'panelMuted/panelBg', hw.panelMuted, hw.panelBg, _text);
      check(hw, 'panelMuted/panelCard', hw.panelMuted, hw.panelCard, _text);
      check(hw, 'icono cerrar X / panelBg', hw.panelText, hw.panelBg, _large);
      check(hw, 'EXPORTAR PNG', hw.actionFg, hw.actionBg, _text);
      check(hw, 'COPIAR LaTeX', hw.action2Fg, hw.action2Bg, _text);
      check(hw, 'PNG exportado: Paso N / blanco', hw.inkOnPaper, Colors.white, _text);
      check(hw, 'PNG exportado: Paso N / papel', hw.inkOnPaper, const Color(0xFFFAF8F4), _text);

      // SnackBar y tooltips con el tema activo.
      final t = casioTheme(hw: hw);
      check(hw, 'SnackBar texto', t.snackBarTheme.contentTextStyle!.color!, t.snackBarTheme.backgroundColor!, _text);
      check(hw, 'SnackBar accion', t.snackBarTheme.actionTextColor!, t.snackBarTheme.backgroundColor!, _text);
    }

    expect(fails, isEmpty, reason: 'Pares bajo el minimo:\n${fails.join('\n')}');
  });

  test('Predeterminado conserva su paleta original', () {
    const d = HardwareThemes.defaultTheme;
    expect(d.lcdBackground, const Color(0xFFC8D6CD));
    expect(d.lcdInset, const Color(0xFFBDCEBE));
    expect(d.chassisMid, const Color(0xFF1C1E22));
    expect(d.legendShift, const Color(0xFFE5A93C));
    expect(d.legendAlpha, const Color(0xFFE05D5D));
    expect(d.keyStyle('7', null, null).background, const Color(0xFF3B4049));
    expect(d.keyStyle('sin', const Color(0xFF1F2227), null).background, const Color(0xFF1F2227));
  });

  test('ensure() conserva un color valido y corrige el que no cumple', () {
    const ok = Color(0xFF000000);
    expect(ThemeContrast.ensure(ok, Colors.white, _text), ok);
    final fixed = ThemeContrast.ensure(const Color(0xFFE5A93C), Colors.white, _text);
    expect(ThemeContrast.ratio(fixed, Colors.white), greaterThanOrEqualTo(_text));
  });
}
