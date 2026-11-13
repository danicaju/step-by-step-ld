import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../domain/math_engine/parser/expression_parser.dart';
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

  const CasioCellValueText({
    super.key,
    required this.value,
    required this.emptyFallback,
    required this.style,
    this.fallbackStyle,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return Text(emptyFallback, style: fallbackStyle ?? style);
    }
    if (!trimmed.contains('/')) {
      return Text(value, style: style);
    }

    final rawLatex = ExpressionParser.rawToLiveLatex(trimmed);
    final sanitized = CasioLcdScreen.sanitizeForMathTex(rawLatex);
    final effectiveSize = (style.fontSize ?? 13.0) * 0.92;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Math.tex(
        sanitized,
        mathStyle: MathStyle.text,
        textStyle: style.copyWith(
          fontFamily: null,
          fontSize: effectiveSize,
        ),
        onErrorFallback: (_) => Text(value, style: style),
      ),
    );
  }
}
