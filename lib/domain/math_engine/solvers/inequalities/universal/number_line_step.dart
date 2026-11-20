import '../../../models/inequality_models.dart';
import '../../../models/step_resolution.dart';

/// Inserta el paso exclusivo de la recta real (`Estudio de signos en la recta real`) justo antes
/// del paso final, que queda limpio con el intervalo solucion.
abstract final class NumberLineStep {
  static const String signsTitle = 'Estudio de signos en la recta real';
  static const String intersectionTitle = 'Intersección en la recta real';

  /// Devuelve [res] con el paso de la recta; no hace nada si ya existe o no hay datos visuales.
  static StepByStepResolution inject(StepByStepResolution res, Inequality1DVisualData? visual) {
    if (visual == null || res.steps.isEmpty || res.steps.any((s) => s.showsNumberLine)) return res;
    final steps = [...res.steps];
    final last = steps.removeLast();
    final labels = [for (final p in visual.criticalPoints) p.label];
    final shown = labels.length > 6 ? [...labels.take(6), r'\ldots'] : labels;
    final line = MathStep(
      index: 0,
      shortTitle: signsTitle,
      latexExpression: shown.isEmpty
          ? r'\text{Sin puntos criticos: el signo es el mismo en toda la recta}'
          : [for (var i = 0; i < shown.length; i++) shown[i] == r'\ldots' ? r'\ldots' : 'x = ${shown[i]}']
              .join(r',\;\; '),
      pedagogicalNote:
          'La recta real muestra con carteles SÍ y NO dónde se cumple la desigualdad. Los puntos llenos están incluidos en la solución y los huecos no.',
      showsNumberLine: true,
    );
    final cleanLast = _cleanFinal(last);
    final all = [...steps, line, cleanLast];
    return StepByStepResolution(
      originalInputLatex: res.originalInputLatex,
      steps: [for (var i = 0; i < all.length; i++) _renumber(all[i], i + 1)],
      exactResultLatex: res.exactResultLatex,
      decimalApproxLatex: res.decimalApproxLatex,
    );
  }

  /// El paso final solo muestra el intervalo: se quita "recta real"/"estudio" del titulo.
  static MathStep _cleanFinal(MathStep s) {
    final t = s.shortTitle;
    final mixed = t.contains('recta real') || t.startsWith('Estudio de');
    return MathStep(
      index: s.index,
      shortTitle: mixed ? 'Solución final' : t,
      latexExpression: s.latexExpression,
      pedagogicalNote: s.pedagogicalNote,
      warningTrick: s.warningTrick,
    );
  }

  static MathStep _renumber(MathStep s, int i) => MathStep(
        index: i,
        shortTitle: s.shortTitle,
        latexExpression: s.latexExpression,
        pedagogicalNote: s.pedagogicalNote,
        warningTrick: s.warningTrick,
        showsNumberLine: s.showsNumberLine,
      );
}
