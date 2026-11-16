import 'dart:math' as math;
import '../../core/algebraic_latex_formatter.dart';
import '../../models/step_resolution.dart';
import '../../models/inequality_models.dart';
import 'inequality_sign.dart';
import 'inequality_parsing_helper.dart';

class RationalAbsInequalitySolver {
  static final Expando<Inequality1DVisualData> visualDataExpando =
      Expando<Inequality1DVisualData>();

  static StepByStepResolution solveAbsoluteValue(
    String raw, {
    InequalitySign? fallbackSign,
  }) {
    final cleaned = raw
        .replaceAll(r'\left|', '|')
        .replaceAll(r'\right|', '|');

    final split = InequalityParsingHelper.splitByInequalitySign(cleaned, fallbackSign: fallbackSign);
    final lhs = split.lhs;
    final rhs = split.rhs;
    final sign = split.sign;

    final firstBar = lhs.indexOf('|');
    final secondBar = lhs.indexOf('|', firstBar + 1);

    if (firstBar == -1 || secondBar == -1) {
      throw const FormatException('Falta cerrar la barra de valor absoluto |...|.');
    }

    final inside = lhs.substring(firstBar + 1, secondBar);
    final prefix = lhs.substring(0, firstBar);
    final suffix = lhs.substring(secondBar + 1);

    // Multiplicador k y constante d: k|A| + d
    double k = 1.0;
    if (prefix.isNotEmpty && prefix != '+') {
      if (prefix == '-') {
        k = -1.0;
      } else {
        k = double.tryParse(prefix.replaceAll('*', '')) ?? 1.0;
      }
    }

    double extraConst = 0.0;
    if (suffix.isNotEmpty) {
      extraConst = double.tryParse(suffix) ?? 0.0;
    }

    final rhsVal = double.tryParse(rhs) ?? 0.0;
    final isolatedC = (rhsVal - extraConst) / k;
    final effectiveSign = k < 0 ? sign.flipped() : sign;

    final parsedLinear = InequalityParsingHelper.parseLinearExpr(inside);
    final a = parsedLinear.xCoeff;
    final b = parsedLinear.constant;
    final insideLatex = AlgebraicLatexFormatter.linearExpression(a, b);

    final steps = <MathStep>[];
    final originalLatex = '$lhs ${sign.latex} $rhs';

    // Paso 1: Aislar el valor absoluto si había coeficientes fuera
    if (k != 1.0 || extraConst != 0.0) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Aislar el valor absoluto',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)}',
          pedagogicalNote:
              'Dejamos el valor absoluto solo en el primer miembro pasando las sumas restando y dividiendo entre $k. '
              '${k < 0 ? 'Al dividir por un número negativo ($k), el sentido de la desigualdad se invierte.' : ''}',
        ),
      );
    }

    // -------------------------------------------------------------------------
    // CASO 1: |A| < C o |A| <= C
    // -------------------------------------------------------------------------
    if (effectiveSign == InequalitySign.less || effectiveSign == InequalitySign.lessOrEqual) {
      if (isolatedC < 0) {
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Desigualdad imposible (Sin solución)',
            latexExpression: '|$insideLatex| ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)} \\implies \\text{Sin solución} \\quad (\\emptyset)',
            pedagogicalNote:
                'El valor absoluto de cualquier número real es siempre mayor o igual a cero (|A| ≥ 0). Nunca puede ser estrictamente menor ni menor o igual que un número negativo ($isolatedC).',
            warningTrick: 'Un valor absoluto nunca puede ser menor que un número negativo. La solución es el conjunto vacío (∅).',
          ),
        );

        final res = StepByStepResolution(
          originalInputLatex: originalLatex,
          steps: steps,
          exactResultLatex: r'\emptyset',
          decimalApproxLatex: r'\emptyset',
        );
        visualDataExpando[res] = const Inequality1DVisualData(
          criticalPoints: [],
          primaryIntervals: [],
          solutionLatex: r'\emptyset',
        );
        return res;
      }

      final isStrict = effectiveSign.isStrict;
      final leftBracket = isStrict ? '(' : '[';
      final rightBracket = isStrict ? ')' : ']';

      // Propiedad: |A| <= C <=> -C <= A <= C
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Propiedad del valor absoluto (|A| ≤ C)',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)} \\iff -${InequalityParsingHelper.fmt(isolatedC)} ${effectiveSign.latex} $insideLatex ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)}',
          pedagogicalNote:
              'Para cualquier C ≥ 0, la desigualdad |A| ≤ C significa que la expresión A está a una distancia menor o igual que C del origen, es decir, comprendida entre -C y C.',
        ),
      );

      // Resolver las dos ramas:
      // Rama 1: A >= -C <=> ax + b >= -C => ax >= -C - b
      final r1 = (-isolatedC - b) / a;
      // Rama 2: A <= C <=> ax + b <= C => ax <= C - b
      final r2 = (isolatedC - b) / a;

      final minR = math.min(r1, r2);
      final maxR = math.max(r1, r2);
      final minRLatex = InequalityParsingHelper.fmt(minR);
      final maxRLatex = InequalityParsingHelper.fmt(maxR);

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Despejar la incógnita x en la desigualdad doble',
          latexExpression:
              '-${InequalityParsingHelper.fmt(isolatedC)} - $b ${effectiveSign.latex} ${a}x ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)} - $b \\implies '
              '$minRLatex ${effectiveSign.latex} x ${effectiveSign.latex} $maxRLatex',
          pedagogicalNote:
              'Restamos $b en los tres miembros y luego dividimos entre $a para despejar la x.',
        ),
      );

      final solInterval = '$leftBracket$minRLatex, $maxRLatex$rightBracket';
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Solución en notación de intervalos',
          latexExpression: 'x \\in $solInterval',
          pedagogicalNote:
              'La solución es el intervalo acotado que contiene todos los números comprendidos entre $minRLatex y $maxRLatex. '
              '${isStrict ? 'Lleva paréntesis ( ) porque los extremos no se incluyen.' : 'Lleva corchetes [ ] porque los extremos sí se incluyen.'}',
        ),
      );

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: 'x \\in $solInterval',
        decimalApproxLatex: 'x \\in $solInterval',
      );

      final visualData = Inequality1DVisualData(
        criticalPoints: [
          CriticalPoint(value: minR, label: minRLatex, isClosed: !isStrict),
          CriticalPoint(value: maxR, label: maxRLatex, isClosed: !isStrict),
        ],
        primaryIntervals: [
          InequalityInterval(
            start: minR,
            end: maxR,
            includeStart: !isStrict,
            includeEnd: !isStrict,
            startLabel: minRLatex,
            endLabel: maxRLatex,
          ),
        ],
        solutionLatex: solInterval,
      );

      visualDataExpando[res] = visualData;
      return res;
    }

    // -------------------------------------------------------------------------
    // CASO 2: |A| > C o |A| >= C
    // -------------------------------------------------------------------------
    if (isolatedC < 0) {
      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: 'Desigualdad siempre cierta (Todos los reales)',
          latexExpression: '|$insideLatex| ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)} \\implies x \\in (-\\infty, +\\infty) = \\mathbb{R}',
          pedagogicalNote:
              'El valor absoluto de cualquier número real es mayor o igual a cero (|A| ≥ 0). Por tanto, siempre es estrictamente mayor que cualquier número negativo ($isolatedC).',
        ),
      );

      final res = StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: r'(-\infty, +\infty)',
        decimalApproxLatex: r'(-\infty, +\infty)',
      );
      visualDataExpando[res] = const Inequality1DVisualData(
        criticalPoints: [],
        primaryIntervals: [
          InequalityInterval(start: double.negativeInfinity, end: double.infinity)
        ],
        solutionLatex: r'(-\infty, +\infty)',
      );
      return res;
    }

    final isStrict = effectiveSign.isStrict;
    final leftBracket = isStrict ? ')' : ']';
    final rightBracket = isStrict ? '(' : '[';

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Propiedad del valor absoluto (|A| ≥ C)',
        latexExpression: '|$insideLatex| ${effectiveSign.latex} ${InequalityParsingHelper.fmt(isolatedC)} \\iff $insideLatex ${isStrict ? '<' : r'\le'} -${InequalityParsingHelper.fmt(isolatedC)} \\quad \\text{o} \\quad $insideLatex ${isStrict ? '>' : r'\ge'} ${InequalityParsingHelper.fmt(isolatedC)}',
        pedagogicalNote:
            'Para cualquier C ≥ 0, la desigualdad |A| ≥ C significa que la expresión A dista al menos C del origen, es decir, está a la izquierda de -C o a la derecha de C.',
      ),
    );

    // Rama 1: A <= -C
    final r1 = (-isolatedC - b) / a;
    // Rama 2: A >= C
    final r2 = (isolatedC - b) / a;

    final minR = math.min(r1, r2);
    final maxR = math.max(r1, r2);
    final minRLatex = InequalityParsingHelper.fmt(minR);
    final maxRLatex = InequalityParsingHelper.fmt(maxR);

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Resolver ambas ramas independientes',
        latexExpression:
            'x ${isStrict ? '<' : r'\le'} $minRLatex \\quad \\text{o} \\quad x ${isStrict ? '>' : r'\ge'} $maxRLatex',
        pedagogicalNote:
            'Despejamos x en cada una de las dos ramas. La solución total es la unión de ambas semirrectas disjuntas.',
      ),
    );

    final solInterval = '(-\\infty, $minRLatex$leftBracket \\cup $rightBracket$maxRLatex, +\\infty)';
    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Solución en unión de intervalos',
        latexExpression: 'x \\in $solInterval',
        pedagogicalNote:
            'La solución se compone de dos tramos infinitos separados por el hueco central ($minRLatex, $maxRLatex).',
      ),
    );

    final res = StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: 'x \\in $solInterval',
      decimalApproxLatex: 'x \\in $solInterval',
    );

    final visualData = Inequality1DVisualData(
      criticalPoints: [
        CriticalPoint(value: minR, label: minRLatex, isClosed: !isStrict),
        CriticalPoint(value: maxR, label: maxRLatex, isClosed: !isStrict),
      ],
      primaryIntervals: [
        InequalityInterval(
          start: double.negativeInfinity,
          end: minR,
          includeStart: false,
          includeEnd: !isStrict,
          endLabel: minRLatex,
        ),
        InequalityInterval(
          start: maxR,
          end: double.infinity,
          includeStart: !isStrict,
          includeEnd: false,
          startLabel: maxRLatex,
        ),
      ],
      solutionLatex: solInterval,
    );

    visualDataExpando[res] = visualData;
    return res;
  }
}
