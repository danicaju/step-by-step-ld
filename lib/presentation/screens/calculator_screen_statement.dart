part of 'calculator_screen.dart';

extension _CalculatorScreenStatement on _CalculatorScreenState {
  /// LaTeX del enunciado tal y como lo escribio el alumno (fracciones verticales);
  /// `null` si no hay fracciones que mejorar o no se puede formatear.
  String? _typedStatementTex(String raw) {
    if (!raw.contains('/')) return null;
    try {
      var tex = ExpressionParser.rawToLiveLatex(ExpressionParser.finalizeForEvaluation(raw));
      tex = tex
          .replaceAll('>=', r'\geq ')
          .replaceAll('<=', r'\leq ')
          .replaceAll('≥', r'\geq ')
          .replaceAll('≤', r'\leq ')
          .replaceAll('≠', r'\neq ');
      if (!tex.contains(r'\frac') || tex.contains('\uE000') || tex.contains(r'\square')) return null;
      return tex;
    } catch (_) {
      return null;
    }
  }

  /// Sustituye el enunciado lineal del solver (`a : b`) por el de fracciones verticales.
  StepByStepResolution _withTypedStatement(StepByStepResolution res, String raw) {
    final tex = _typedStatementTex(raw);
    return tex == null ? res : res.withOriginalInput(tex);
  }
}
