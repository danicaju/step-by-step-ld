import 'package:flutter/material.dart';

import '../../../core/editor/lcd_cursor_tokens.dart';
import '../safe_math.dart';
import 'blinking_cursor_builder.dart';

/// Formula principal de la LCD con el cursor parpadeante aislado.
///
/// Solo este `SafeMath.tex` (dentro de un `RepaintBoundary`) se reconstruye en cada tick de
/// [LcdBlink.period]; la barra de estado, los selectores de cabecera y el resto de la LCD
/// no se tocan. Sin cursor en el LaTeX (resultados, pasos) no hay `Timer` activo.
/// El fallback ante un error de parseo es texto plano: nunca LaTeX crudo.
class LcdBlinkingLatex extends StatelessWidget {
  final String latex;
  final bool isOledDark;
  final TextStyle textStyle;

  const LcdBlinkingLatex({
    super.key,
    required this.latex,
    required this.isOledDark,
    required this.textStyle,
  });

  Widget _math(String tex) => SafeMath.tex(tex, textStyle: textStyle);

  @override
  Widget build(BuildContext context) {
    if (!latex.contains(LcdCursor.ink)) {
      return _math(LcdBlink.apply(latex, on: true, dark: isOledDark));
    }
    return RepaintBoundary(
      child: BlinkingCursorBuilder(
        builder: (context, on) => _math(LcdBlink.apply(latex, on: on, dark: isOledDark)),
      ),
    );
  }
}
