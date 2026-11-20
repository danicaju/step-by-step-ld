import 'package:flutter/material.dart';

import '../../../core/editor/latex_render_sanitizer.dart';
import '../../../core/formatting/smart_latex_wrapper.dart';
import '../common/responsive_math_formula.dart';

/// Formula de un paso en la LCD: legible (suelo de escala), con salto inteligente de
/// linea y scroll horizontal como red de seguridad.
///
/// Si [originalLatex] viene informado y el paso repite el enunciado seguido de `=`
/// (p. ej. `\int f\,dx = F + C`), se muestra solo `= F + C`: el enunciado ya esta arriba.
class LcdStepFormula extends StatelessWidget {
  final String latex;
  final String? originalLatex;
  final double fontSize;
  final Color color;
  final Color background;
  final bool centered;

  const LcdStepFormula({
    super.key,
    required this.latex,
    required this.fontSize,
    required this.color,
    required this.background,
    this.originalLatex,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final shown = originalLatex == null ? latex : stripLeadingStatement(latex, originalLatex!);
    return ResponsiveMathFormula(
      key: const Key('lcd_step_formula'),
      latex: LatexRenderSanitizer.sanitize(shown),
      alignment: centered ? Alignment.center : Alignment.centerRight,
      backgroundColor: background,
      textStyle: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.w600),
    );
  }
}
