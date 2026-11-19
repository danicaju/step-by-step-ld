import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'blinking_cursor_builder.dart';

/// Formula principal de la LCD con el cursor parpadeante aislado.
///
/// Solo este `Math.tex` (dentro de un `RepaintBoundary`) se reconstruye en cada tick de
/// [LcdBlink.period]; la barra de estado, los selectores de cabecera y el resto de la LCD
/// no se tocan. Sin cursor en el LaTeX (resultados, pasos) no hay `Timer` activo.
class LcdBlinkingLatex extends StatelessWidget {
  final String latex;
  final bool isOledDark;
  final TextStyle textStyle;
  final OnErrorFallback? onErrorFallback;

  const LcdBlinkingLatex({
    super.key,
    required this.latex,
    required this.isOledDark,
    required this.textStyle,
    this.onErrorFallback,
  });

  static const String _cursorColor = '#1A2530';

  Widget _math(String tex) => Math.tex(tex, textStyle: textStyle, onErrorFallback: onErrorFallback ?? _defaultFallback);

  static Widget _defaultFallback(FlutterMathException e) => Text(e.message);

  @override
  Widget build(BuildContext context) {
    if (!latex.contains(_cursorColor)) {
      return _math(LcdBlink.apply(latex, on: true, dark: isOledDark));
    }
    return RepaintBoundary(
      child: BlinkingCursorBuilder(
        builder: (context, on) => _math(LcdBlink.apply(latex, on: on, dark: isOledDark)),
      ),
    );
  }
}
