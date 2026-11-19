import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_engine/parser/expression_parser.dart';
import '../utils/cell_fraction_editor.dart';
import 'casio_lcd_screen.dart';

/// Renderiza el valor de una celda en las vistas estructuradas de la LCD.
///
/// Cuando el contenido incluye `/` (p. ej. `3/4` o `2/`), lo transforma a LaTeX
/// vertical (`\frac{3}{4}`) mediante `ExpressionParser.rawToLiveLatex`,
/// evitando mostrar barras `/` sin formato.
class CasioCellValueText extends StatelessWidget {
  final String value;
  final String emptyFallback;
  final TextStyle style;
  final TextStyle? fallbackStyle;

  /// Celda activa con fraccion: 0 = se edita el numerador, 1 = el denominador (cursor).
  final int? fractionPart;

  /// Estilo del LaTeX: `display` agranda las fracciones (celdas de coeficientes).
  final MathStyle mathStyle;

  const CasioCellValueText({
    super.key,
    required this.value,
    required this.emptyFallback,
    required this.style,
    this.fallbackStyle,
    this.fractionPart,
    this.mathStyle = MathStyle.text,
  });

  /// `\frac{n}{d}` con huecos `\square` y cursor en la parte activa.
  /// Con [coloredCursor] el cursor lleva el color `#1A2530` (parpadea con `LcdBlink`).
  static String fractionTex(String value, {int? activePart, bool coloredCursor = false}) {
    final parts = CellFractionEditor.parts(value.trim());
    if (parts == null) return ExpressionParser.rawToLiveLatex(value.trim());
    final bar = coloredCursor ? '\\textcolor{#1A2530}{\\mid}' : '\\mid';
    final box = coloredCursor ? '\\textcolor{#1A2530}{\\blacksquare}' : '\\blacksquare';
    String part(String t, bool active) {
      if (t.isEmpty || t == '-') {
        return active ? '$t$box' : '$t\\square';
      }
      return active ? '$t$bar' : t;
    }

    return '\\frac{${part(parts.$1, activePart == 0)}}{${part(parts.$2, activePart == 1)}}';
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return Text(emptyFallback, style: fallbackStyle ?? style);
    }
    if (!trimmed.contains('/')) {
      return Text(value, style: style);
    }

    final rawLatex = fractionTex(trimmed, activePart: fractionPart);
    final sanitized = CasioLcdScreen.sanitizeForMathTex(rawLatex);
    final effectiveSize = (style.fontSize ?? 13.0) * 0.92;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Math.tex(
        sanitized,
        mathStyle: mathStyle,
        textStyle: style.copyWith(
          fontFamily: null,
          fontSize: effectiveSize,
        ),
        onErrorFallback: (_) => Text(value, style: style),
      ),
    );
  }
}
