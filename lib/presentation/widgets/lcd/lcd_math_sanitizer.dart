import '../../../core/editor/latex_render_sanitizer.dart';

/// Normalizador y blindaje de codigo LaTeX para flutter_math_fork en pantallas LCD Casio.
///
/// Delegado en [LatexRenderSanitizer] (reparacion de escapes, balanceo de llaves y
/// `\left`/`\right`, tildes en `\text{}`, saltos de fila fuera de entornos).
class LcdMathSanitizer {
  static String sanitizeForMathTex(String latex) => LatexRenderSanitizer.sanitize(latex);
}
