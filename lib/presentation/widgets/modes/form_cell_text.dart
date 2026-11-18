import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../domain/math_engine/parser/live_latex_formatter.dart';
import '../casio_cell_value_text.dart';
import '../casio_lcd_screen.dart';

/// Contenido de una celda de formulario.
///
/// Las celdas de expresion (`expr`) se pintan como LaTeX en vivo (`x^{2}`, fracciones
/// verticales, raices...) con un cursor al final cuando estan activas; las numericas
/// se quedan en monoespaciado. Nunca se muestra el texto crudo `x^2`.
class FormCellText extends StatelessWidget {
  final String text;
  final bool active;
  final bool latex;
  final Color color;
  final double fontSize;

  /// Campo numerico con fraccion activa: `true` = cursor en el numerador.
  final bool fracNumerator;

  const FormCellText({
    super.key,
    required this.text,
    required this.active,
    required this.latex,
    required this.color,
    this.fontSize = 14,
    this.fracNumerator = false,
  });

  /// LaTeX de la celda; el cursor usa [color] para verse tambien sobre fondo oscuro.
  static String texOf(String text, {required bool active, required Color color}) {
    final tex = LiveLatexFormatter.rawToLiveLatex(text, cursorPos: active ? text.length : null);
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return tex.replaceAll('#1A2530', hex);
  }

  @override
  Widget build(BuildContext context) {
    final mono = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      fontFamily: 'monospace',
    );
    if (!latex && text.contains('/')) {
      // Fraccion numerica (a/b): se pinta vertical, con el cursor en la parte activa.
      final tex = CasioCellValueText.fractionTex(text, activePart: active ? (fracNumerator ? 0 : 1) : null);
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.text,
          textStyle: TextStyle(color: color, fontSize: fontSize + 2, fontWeight: FontWeight.w700),
          onErrorFallback: (_) => Text(text + (active ? '_' : ''), style: mono),
        ),
      );
    }
    if (!latex) return Text(text + (active ? '_' : ''), style: mono);
    if (text.isEmpty && !active) return SizedBox(height: fontSize * 1.3);
    final tex = CasioLcdScreen.sanitizeForMathTex(texOf(text, active: active, color: color));
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Math.tex(
        tex,
        mathStyle: MathStyle.text,
        textStyle: TextStyle(color: color, fontSize: fontSize + 2, fontWeight: FontWeight.w700),
        onErrorFallback: (_) => Text(text + (active ? '_' : ''), style: mono),
      ),
    );
  }
}
