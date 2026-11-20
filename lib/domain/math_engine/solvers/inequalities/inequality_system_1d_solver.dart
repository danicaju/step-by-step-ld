import '../../models/step_resolution.dart';
import '../../models/inequality_models.dart';
import 'universal/inequality_interval_ops.dart';

class InequalitySystem1DSolver {
  static final Expando<Inequality1DVisualData> visualDataExpando =
      Expando<Inequality1DVisualData>();

  static ({StepByStepResolution resolution, Inequality1DVisualData visualData}) solveSystem1D(
    List<String> rawInequalities, {
    required StepByStepResolution Function(String raw) solveSingle,
    required Inequality1DVisualData? Function(StepByStepResolution res) getVisual,
  }) {
    if (rawInequalities.isEmpty) {
      throw const FormatException('Introduce al menos una inecuación para el sistema.');
    }

    final singleResolutions = <StepByStepResolution>[];
    final visualDataList = <Inequality1DVisualData>[];

    for (final raw in rawInequalities) {
      final res = solveSingle(raw);
      singleResolutions.add(res);
      final v = getVisual(res);
      if (v != null) visualDataList.add(v);
    }

    final steps = <MathStep>[];

    // Paso 1 y Paso 2: Resolución de cada inecuación por separado
    for (int i = 0; i < singleResolutions.length; i++) {
      final r = singleResolutions[i];
      final ineqName = '(${i + 1})';
      final solText = r.exactResultLatex;
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Resolver inecuación $ineqName',
          latexExpression: '${r.originalInputLatex} \\implies S_{${i + 1}} = $solText',
          pedagogicalNote:
              'Resolvemos la inecuación $ineqName por separado. Si en algún despeje se multiplica o divide por un número negativo, se invierte el sentido de la desigualdad.',
          warningTrick:
              'Recuerda: al dividir o multiplicar por un número negativo se cambia el sentido de la desigualdad (< pasa a > y ≤ pasa a ≥).',
        ),
      );
    }

    // Intersección exacta de los intervalos solución de todas las filas
    if (visualDataList.length != singleResolutions.length) {
      throw const FormatException('No se puede representar una de las inecuaciones del sistema.');
    }
    final intervals1 = visualDataList[0].primaryIntervals;
    final intervals2 = visualDataList.length > 1 ? visualDataList[1].primaryIntervals : <InequalityInterval>[];
    var intersection = intervals1;
    for (var i = 1; i < visualDataList.length; i++) {
      intersection = IntervalOps.intersect(intersection, visualDataList[i].primaryIntervals);
    }

    final k = singleResolutions.length;
    final sLatex = [for (final r in singleResolutions) r.exactResultLatex];
    final sfLatex = IntervalOps.latexOf(intersection);
    final capLatex = [for (var i = 1; i <= k; i++) 'S_{$i}'].join(r' \cap ');
    const hatch = [
      r'\text{rayado } / / /',
      r'\text{rayado } \backslash \backslash \backslash',
      r'\text{rayado horizontal}',
      r'\text{rayado vertical}',
    ];

    // Paso de representación en la recta e intersección con rayado
    final repLatex = [
      for (var i = 0; i < k; i++) 'S_{${i + 1}} = ${sLatex[i]} \\quad (${hatch[i]})',
      'S_{f} = $capLatex = $sfLatex',
    ].join(' \\\\\n');

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Intersección en la recta real',
        latexExpression: repLatex,
        pedagogicalNote:
            'Dibujamos sobre la recta real los puntos críticos ordenados. Trazamos cada solución con su rayado correspondiente. '
            'La solución final es la zona común donde todos los rayados coinciden.',
        showsNumberLine: true,
      ),
    );

    // Paso final: Solución final
    final isNone = intersection.isEmpty;
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Solución final del sistema',
        latexExpression: isNone
            ? '$capLatex = \\emptyset \\quad (\\text{Sin solucion})'
            : 'x \\in S_{f} = $sfLatex',
        pedagogicalNote: isNone
            ? 'Los intervalos no tienen ningún punto en común: el sistema de inecuaciones es incompatible y no tiene solución (conjunto vacío ∅).'
            : 'Cualquier número real dentro del intervalo solución cumple simultáneamente todas las inecuaciones del sistema.',
      ),
    );

    // Recoger todos los puntos críticos de todas las inecuaciones
    final allCritPoints = <CriticalPoint>[];
    for (final v in visualDataList) {
      allCritPoints.addAll(v.criticalPoints);
    }
    allCritPoints.sort((a, b) => a.value.compareTo(b.value));

    final originalLatex = rawInequalities.join(r' \quad \text{y} \quad ');

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'S_{f} = $sfLatex',
      decimalApproxLatex: 'S_{f} = $sfLatex',
    );

    final visualData = Inequality1DVisualData(
      criticalPoints: allCritPoints,
      primaryIntervals: intervals1,
      secondaryIntervals: intervals2,
      intersectionIntervals: intersection,
      solutionLatex: '$capLatex = $sfLatex',
      label1: 'S_{1}',
      label2: 'S_{2}',
    );

    visualDataExpando[res] = visualData;
    return (resolution: res, visualData: visualData);
  }
}
