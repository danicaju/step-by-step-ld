import '../../core/algebraic_latex_formatter.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import 'system_2x2_helpers.dart';

class System2x2SubstitutionSolver {
  /// Método 1: Sustitución
  static StepByStepResolution solve({
    required int a1,
    required int b1,
    required int c1,
    required int a2,
    required int b2,
    required int c2,
    required String systemLatex,
    required Rational xRational,
    required Rational yRational,
  }) {
    final List<MathStep> steps = [];

    // Priorizamos despejar la variable con coeficiente ±1 (evitando coeficientes nulos)
    final bool isolateY1 = b1 != 0 && (b1.abs() == 1 || (a1.abs() != 1 && b2.abs() != 1));

    if (isolateY1 || a1 == 0) {
      // Despejar y en Ec. 1
      final yExprLatex = System2x2Helpers.isolateVariableExpr(
        targetCoeff: b1,
        otherCoeff: a1,
        otherVar: 'x',
        constant: c1,
      );

      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Despejar una incógnita en la ecuación más sencilla',
          latexExpression: 'y = $yExprLatex',
          pedagogicalNote:
              'Despejamos la incógnita con coeficiente más sencillo en la primera ecuación para sustituirla después.',
        ),
      );

      // Sustituir y en Ec. 2
      final xPart = AlgebraicLatexFormatter.monomialTerm(a2, 'x', isFirst: true);
      final ySubLatex = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(
        b2,
        '\\textcolor{#2563EB}{$yExprLatex}',
        isFirst: a2 == 0,
      );
      final eqSub = '$xPart$ySubLatex'.isEmpty ? '0 = $c2' : '$xPart$ySubLatex = $c2';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Sustituir en la otra ecuación',
          latexExpression: eqSub,
          pedagogicalNote:
              'Reemplazamos la expresión de y entre paréntesis en la segunda ecuación, obteniendo una ecuación de 1.º grado con solo x.',
        ),
      );

      steps.addAll(_solveSteps(
        v: 'x',
        start: steps.length + 1,
        // y = k x + m  (de a1 x + b1 y = c1)
        k: Rational(-a1, b1),
        m: Rational(c1, b1),
        // a2 x + b2 y = c2
        own: Rational(a2),
        other: Rational(b2),
        c: Rational(c2),
        value: xRational,
      ));

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: '${steps.length + 1}. Calcular el valor de y',
          latexExpression:
              'y = $yExprLatex = ${yRational.toLatex()}',
          pedagogicalNote:
              'Sustituimos el valor hallado x = ${xRational.toLatex()} en la expresión despejada del Paso 1 para obtener y.',
        ),
      );
    } else {
      // Despejar x en Ec. 1
      final xExprLatex = System2x2Helpers.isolateVariableExpr(
        targetCoeff: a1,
        otherCoeff: b1,
        otherVar: 'y',
        constant: c1,
      );

      steps.add(
        MathStep(
          index: 1,
          shortTitle: '1. Despejar una incógnita en la ecuación más sencilla',
          latexExpression: 'x = $xExprLatex',
          pedagogicalNote:
              'Aislamos la incógnita con coeficiente más sencillo en la primera ecuación.',
        ),
      );

      final xSubLatex = AlgebraicLatexFormatter.signedCoeffTimesParenthesized(
        a2,
        '\\textcolor{#2563EB}{$xExprLatex}',
        isFirst: true,
      );
      final yPart = AlgebraicLatexFormatter.monomialTerm(
        b2,
        'y',
        isFirst: a2 == 0,
      );
      final eqSub = '$xSubLatex$yPart'.isEmpty ? '0 = $c2' : '$xSubLatex$yPart = $c2';

      steps.add(
        MathStep(
          index: 2,
          shortTitle: '2. Sustituir en la otra ecuación',
          latexExpression: eqSub,
          pedagogicalNote:
              'Sustituimos la incógnita despejada en la segunda ecuación para trabajar con una sola variable (y).',
        ),
      );

      steps.addAll(_solveSteps(
        v: 'y',
        start: steps.length + 1,
        // x = k y + m  (de a1 x + b1 y = c1)
        k: Rational(-b1, a1),
        m: Rational(c1, a1),
        // a2 x + b2 y = c2
        own: Rational(b2),
        other: Rational(a2),
        c: Rational(c2),
        value: yRational,
      ));

      steps.add(
        MathStep(
          index: steps.length + 1,
          shortTitle: '${steps.length + 1}. Calcular el valor de x',
          latexExpression:
              'x = $xExprLatex = ${xRational.toLatex()}',
          pedagogicalNote:
              'Sustituimos el valor hallado y = ${yRational.toLatex()} en la expresión de x.',
        ),
      );
    }

    return StepByStepResolution(
      originalInputLatex: systemLatex,
      steps: steps,
      exactResultLatex: 'x = ${xRational.toLatex()}, \\; y = ${yRational.toLatex()}',
      decimalApproxLatex: 'x = ${xRational.toDecimalLatex()}, \\; y = ${yRational.toDecimalLatex()}',
    );
  }

  /// `+ a x - b ...` con los terminos no nulos (`v == ''` es el termino independiente).
  static String _terms(List<(Rational, String)> terms) {
    final buf = StringBuffer();
    for (final (c, v) in terms) {
      if (c.isZero) continue;
      final abs = c.abs();
      final body = v.isEmpty ? abs.toLatex() : (abs == Rational(1) ? v : '${abs.toLatex()}$v');
      if (buf.isEmpty) {
        buf.write(c.isNegative ? '-$body' : body);
      } else {
        buf.write(c.isNegative ? ' - $body' : ' + $body');
      }
    }
    return buf.isEmpty ? '0' : buf.toString();
  }

  /// Sustitucion hecha: `own·v + other·(k v + m) = c` -> quitar parentesis, agrupar y despejar `v`.
  static List<MathStep> _solveSteps({
    required String v,
    required int start,
    required Rational k,
    required Rational m,
    required Rational own,
    required Rational other,
    required Rational c,
    required Rational value,
  }) {
    final expandedVar = other * k;
    final expandedConst = other * m;
    final coef = own + expandedVar;
    final rhs = c - expandedConst;
    final expanded = '${_terms([(own, v), (expandedVar, v), (expandedConst, '')])} = ${c.toLatex()}';
    final grouped = '${_terms([(coef, v), (expandedConst, '')])} = ${c.toLatex()}';
    final moved = '${_terms([(coef, v)])} = ${rhs.toLatex()}';
    return [
      MathStep(
        index: start,
        shortTitle: '$start. Quitar paréntesis',
        latexExpression: expanded,
        pedagogicalNote:
            'Aplicamos la propiedad distributiva: multiplicamos el número de fuera por cada término del paréntesis (cuidado con los signos).',
      ),
      MathStep(
        index: start + 1,
        shortTitle: '${start + 1}. Agrupar y pasar los números al otro miembro',
        latexExpression: '$grouped \\implies $moved',
        pedagogicalNote:
            'Sumamos los términos en $v y pasamos el término independiente al segundo miembro cambiándole el signo.',
      ),
      MathStep(
        index: start + 2,
        shortTitle: '${start + 2}. Despejar $v',
        latexExpression: '$v = \\frac{${rhs.toLatex()}}{${coef.toLatex()}} = ${value.toLatex()}',
        pedagogicalNote: 'Dividimos los dos miembros entre el coeficiente de $v.',
      ),
    ];
  }
}
