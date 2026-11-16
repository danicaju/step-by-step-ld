import '../../models/step_resolution.dart';
import '../../models/inequality_models.dart';
import 'inequality_parsing_helper.dart';

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

    // Calcular la intersección de intervalos
    final intervals1 = visualDataList.isNotEmpty ? visualDataList[0].primaryIntervals : <InequalityInterval>[];
    final intervals2 = visualDataList.length > 1 ? visualDataList[1].primaryIntervals : <InequalityInterval>[];
    var intersection = InequalityParsingHelper.intersectIntervalLists(intervals1, intervals2);
    if (visualDataList.length > 2) {
      final intervals3 = visualDataList[2].primaryIntervals;
      intersection = InequalityParsingHelper.intersectIntervalLists(intersection, intervals3);
    }

    final s1Latex = singleResolutions[0].exactResultLatex;
    final s2Latex = singleResolutions.length > 1 ? singleResolutions[1].exactResultLatex : '';
    final s3Latex = singleResolutions.length > 2 ? singleResolutions[2].exactResultLatex : '';
    final sfLatex = intersection.isEmpty
        ? r'\emptyset'
        : intersection.map((i) => i.toIntervalLatex()).join(r' \cup ');

    final capLatex = singleResolutions.length > 2
        ? r'S_{1} \cap S_{2} \cap S_{3}'
        : r'S_{1} \cap S_{2}';

    // Paso de representación en la recta e intersección con rayado
    final repLatex = singleResolutions.length > 2
        ? 'S_{1} = $s1Latex \\quad (\\text{rayado } / / /) \\\\\n'
          'S_{2} = $s2Latex \\quad (\\text{rayado } \\backslash \\backslash \\backslash) \\\\\n'
          'S_{3} = $s3Latex \\quad (\\text{rayado horizontal}) \\\\\n'
          'S_{f} = $capLatex = $sfLatex'
        : 'S_{1} = $s1Latex \\quad (\\text{rayado } / / /) \\\\\n'
          'S_{2} = $s2Latex \\quad (\\text{rayado } \\backslash \\backslash \\backslash) \\\\\n'
          'S_{f} = $capLatex = $sfLatex \\quad (\\text{zona en malla XXX})';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Representación en la recta e intersección',
        latexExpression: repLatex,
        pedagogicalNote:
            'Dibujamos sobre la recta real los puntos críticos ordenados. Trazamos cada solución con su rayado correspondiente. '
            'La solución final es la zona común donde todos los rayados coinciden.',
      ),
    );

    // Paso final: Solución final
    final isNone = intersection.isEmpty;
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Solución final del sistema',
        latexExpression: isNone
            ? '$capLatex = \\emptyset \\quad (\\text{Sin solución})'
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
