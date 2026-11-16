import 'dart:math' as math;
import '../../ast/ast_nodes.dart';
import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart';

export 'notable_trig_table.dart';

class ExactTrigSolver {
  static const Map<int, NotableFirstQuadEntry> firstQuadTable = NotableTrigTable.table;

  /// Resuelve razones trigonométricas directas e inversas con valores exactos notables de ESO/Bachillerato.
  static StepByStepResolution solveTrig({
    required TrigFunction function,
    required ExprNode argNode,
    required AngleUnit unit,
    required double? evaluatedNumericArg,
    Rational? exactRationalArg,
    Rational? piMultipleRational,
  }) {
    final trigExprLatex = TrigNode(
      function,
      argNode,
      showDegSymbol: unit == AngleUnit.deg &&
          function != TrigFunction.asin &&
          function != TrigFunction.acos &&
          function != TrigFunction.atan &&
          piMultipleRational == null,
    ).toLatex();

    return switch (function) {
      TrigFunction.sin || TrigFunction.cos || TrigFunction.tan => solveDirectTrig(
          function: function,
          trigExprLatex: trigExprLatex,
          argNode: argNode,
          unit: unit,
          evaluatedNumericArg: evaluatedNumericArg,
          exactRationalArg: exactRationalArg,
          piMultipleRational: piMultipleRational,
        ),
      TrigFunction.asin ||
      TrigFunction.acos ||
      TrigFunction.atan =>
        solveInverseTrig(
          function: function,
          trigExprLatex: trigExprLatex,
          argNode: argNode,
          unit: unit,
          evaluatedNumericArg: evaluatedNumericArg,
          exactRationalArg: exactRationalArg,
        ),
    };
  }

  static StepByStepResolution solveDirectTrig({
    required TrigFunction function,
    required String trigExprLatex,
    required ExprNode argNode,
    required AngleUnit unit,
    required double? evaluatedNumericArg,
    Rational? exactRationalArg,
    Rational? piMultipleRational,
  }) {
    final fnName = switch (function) {
      TrigFunction.sin => r'\sin',
      TrigFunction.cos => r'\cos',
      TrigFunction.tan => r'\tan',
      _ => r'\sin',
    };
    final fnSpanish = switch (function) {
      TrigFunction.sin => 'seno',
      TrigFunction.cos => 'coseno',
      TrigFunction.tan => 'tangente',
      _ => 'seno',
    };

    int? exactDeg;
    final List<MathStep> steps = [];
    int stepIdx = 1;

    if (piMultipleRational != null) {
      final degRat = piMultipleRational * Rational(180);
      if (degRat.isInteger) {
        exactDeg = degRat.numerator;
        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Conversión de radianes a grados',
            latexExpression:
                '${argNode.toLatex()}\\text{ rad} = $exactDeg^\\circ',
            pedagogicalNote:
                'Equivalencia fundamental: π radianes son 180°, así que podemos usar la tabla notable en grados.',
          ),
        );
      }
    } else if (unit == AngleUnit.deg && exactRationalArg != null && exactRationalArg.isInteger) {
      exactDeg = exactRationalArg.numerator;
    } else if (argNode is DmsNode && argNode.minutes == 0 && argNode.seconds == 0) {
      exactDeg = argNode.isNegative ? -argNode.degrees : argNode.degrees;
    }

    if (exactDeg != null) {
      int normalized = ((exactDeg % 360) + 360) % 360;
      if (exactDeg != normalized) {
        final turns = (exactDeg - normalized) ~/ 360;
        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Ángulo coterminal en [0°, 360°)',
            latexExpression:
                '$fnName\\left($exactDeg^\\circ\\right) = $fnName\\left($normalized^\\circ\\right)',
            pedagogicalNote:
                'Restamos o sumamos vueltas completas de 360° ($turns vueltas) hasta situar el ángulo en la primera vuelta.',
          ),
        );
      }

      final reduction = reduceToFirstQuadrant(normalized, function);
      final entry = firstQuadTable[reduction.refDeg];
      if (entry != null) {
        if (reduction.quadFormula != null) {
          final signStr = reduction.sign < 0 ? '-' : '';
          steps.add(
            MathStep(
              index: stepIdx++,
              shortTitle: 'Reducción al 1.er cuadrante',
              latexExpression:
                  '$fnName\\left($normalized^\\circ\\right) = $fnName\\left(${reduction.quadFormula}\\right) = $signStr$fnName\\left(${reduction.refDeg}^\\circ\\right)',
              pedagogicalNote: reduction.quadNote!,
            ),
          );
        }

        final String? baseLatex = switch (function) {
          TrigFunction.sin => entry.sinLatex,
          TrigFunction.cos => entry.cosLatex,
          TrigFunction.tan => entry.tanLatex,
          _ => null,
        };
        final String? rawUnrationalized = switch (function) {
          TrigFunction.sin => entry.sinRawUnrationalized,
          TrigFunction.cos => entry.cosRawUnrationalized,
          TrigFunction.tan => entry.tanRawUnrationalized,
          _ => null,
        };
        final double? numericVal = switch (function) {
          TrigFunction.sin => entry.sinVal,
          TrigFunction.cos => entry.cosVal,
          TrigFunction.tan => entry.tanVal,
          _ => null,
        };

        if (baseLatex == null || numericVal == null) {
          steps.add(
            MathStep(
              index: stepIdx++,
              shortTitle: 'Tangente indefinida',
              latexExpression: '$trigExprLatex \\implies \\text{No definido}',
              pedagogicalNote:
                  'En $normalized°, el coseno vale 0 y la tangente es sen/cos: no se puede dividir entre 0.',
              warningTrick:
                  'La tangente de 90° y 270° no existe (asíntota vertical).',
            ),
          );
          return StepByStepResolution(
            originalInputLatex: trigExprLatex,
            steps: steps,
            exactResultLatex: r'\text{No definido}',
            decimalApproxLatex: r'\text{No definido}',
          );
        }

        final signedExact = applySignToLatex(baseLatex, reduction.sign);
        final signedNumeric = reduction.sign * numericVal;

        if (rawUnrationalized != null) {
          final signedRaw = applySignToLatex(rawUnrationalized, reduction.sign);
          steps.add(
            MathStep(
              index: stepIdx++,
              shortTitle: 'Valor notable y racionalización',
              latexExpression: '$signedRaw = $signedExact',
              pedagogicalNote:
                  'Eliminamos la raíz del denominador multiplicando numerador y denominador por la misma raíz.',
              warningTrick:
                  'En exámenes de 4.º ESO se exige dejar el radical racionalizado en el numerador.',
            ),
          );
        }

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Valor exacto del $fnSpanish',
            latexExpression: '$trigExprLatex = $signedExact',
            pedagogicalNote:
                'Resultado exacto de tabla trigonométrica notable (${reduction.refDeg}° en el 1.er cuadrante).',
          ),
        );

        return StepByStepResolution(
          originalInputLatex: trigExprLatex,
          steps: steps,
          exactResultLatex: signedExact,
          decimalApproxLatex: formatDouble(signedNumeric),
        );
      }
    }

    final double numericAngle = evaluatedNumericArg ?? 0.0;
    final double radians = unit == AngleUnit.deg
        ? numericAngle * math.pi / 180.0
        : numericAngle;

    if (function == TrigFunction.tan && math.cos(radians).abs() < 1e-12) {
      return StepByStepResolution(
        originalInputLatex: trigExprLatex,
        steps: [
          ...steps,
          MathStep(
            index: stepIdx,
            shortTitle: 'Tangente indefinida',
            latexExpression: '$trigExprLatex \\implies \\text{No definido}',
            pedagogicalNote: 'El coseno de este ángulo vale 0.',
            warningTrick: 'División por cero en tan(x) = sen(x)/cos(x).',
          ),
        ],
        exactResultLatex: r'\text{No definido}',
        decimalApproxLatex: r'\text{No definido}',
      );
    }

    final result = switch (function) {
      TrigFunction.sin => math.sin(radians),
      TrigFunction.cos => math.cos(radians),
      TrigFunction.tan => math.tan(radians),
      _ => 0.0,
    };
    final approx = formatDouble(result);

    steps.add(
      MathStep(
        index: stepIdx,
        shortTitle: 'Cálculo trigonométrico (${unit == AngleUnit.deg ? "DEG" : "RAD"})',
        latexExpression: '$trigExprLatex \\approx $approx',
        pedagogicalNote:
            'El ángulo no corresponde a un ángulo notable estándar; calculamos su aproximación en modo ${unit == AngleUnit.deg ? "grados sexagesimales" : "radianes"}.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: trigExprLatex,
      steps: steps,
      exactResultLatex: approx,
      decimalApproxLatex: approx,
    );
  }

  static ({int refDeg, int sign, String? quadNote, String? quadFormula})
      reduceToFirstQuadrant(int normalizedDeg, TrigFunction fn) {
    if (normalizedDeg <= 90) {
      return (refDeg: normalizedDeg, sign: 1, quadNote: null, quadFormula: null);
    } else if (normalizedDeg <= 180) {
      final ref = 180 - normalizedDeg;
      final sign = fn == TrigFunction.sin ? 1 : -1;
      return (
        refDeg: ref,
        sign: sign,
        quadNote:
            'El ángulo $normalizedDeg° está en el 2.º cuadrante (180° - $ref°). Ahí solo el seno es positivo.',
        quadFormula: '180^\\circ - $ref^\\circ',
      );
    } else if (normalizedDeg <= 270) {
      final ref = normalizedDeg - 180;
      final sign = fn == TrigFunction.tan ? 1 : -1;
      return (
        refDeg: ref,
        sign: sign,
        quadNote:
            'El ángulo $normalizedDeg° está en el 3.er cuadrante (180° + $ref°). Ahí seno y coseno son negativos y la tangente es positiva.',
        quadFormula: '180^\\circ + $ref^\\circ',
      );
    } else {
      final ref = 360 - normalizedDeg;
      final sign = fn == TrigFunction.cos ? 1 : -1;
      return (
        refDeg: ref,
        sign: sign,
        quadNote:
            'El ángulo $normalizedDeg° está en el 4.º cuadrante (360° - $ref°). Ahí solo el coseno es positivo.',
        quadFormula: '360^\\circ - $ref^\\circ',
      );
    }
  }

  static StepByStepResolution solveInverseTrig({
    required TrigFunction function,
    required String trigExprLatex,
    required ExprNode argNode,
    required AngleUnit unit,
    required double? evaluatedNumericArg,
    Rational? exactRationalArg,
  }) {
    final val = exactRationalArg?.toDouble() ?? evaluatedNumericArg ?? 0.0;

    if ((function == TrigFunction.asin || function == TrigFunction.acos) &&
        val.abs() > 1.0 + 1e-9) {
      return StepByStepResolution(
        originalInputLatex: trigExprLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Error de dominio trigonométrico',
            latexExpression: '$trigExprLatex \\implies \\text{Error de dominio}',
            pedagogicalNote:
                'No existe ningún ángulo real cuyo ${function == TrigFunction.asin ? "seno" : "coseno"} sea ${formatDouble(val)}.',
            warningTrick:
                'El valor introducido debe estar siempre comprendido entre -1 y 1.',
          ),
        ],
        exactResultLatex: r'\text{No existe}',
        decimalApproxLatex: r'\text{No existe}',
      );
    }

    final int? notableDeg = matchNotableInverseDegrees(function, val);
    if (notableDeg != null) {
      final radFracLatex = degreesToPiFractionLatex(notableDeg);
      final radApprox = formatDouble(notableDeg * math.pi / 180.0);

      final resultLatex = unit == AngleUnit.deg ? '$notableDeg^\\circ' : radFracLatex;
      final decimalApprox =
          unit == AngleUnit.deg ? '$notableDeg^\\circ' : radApprox;

      final defRelation = switch (function) {
        TrigFunction.asin => '\\sin\\left($resultLatex\\right) = ${argNode.toLatex()}',
        TrigFunction.acos => '\\cos\\left($resultLatex\\right) = ${argNode.toLatex()}',
        TrigFunction.atan => '\\tan\\left($resultLatex\\right) = ${argNode.toLatex()}',
        _ => '',
      };

      return StepByStepResolution(
        originalInputLatex: trigExprLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Ángulo notable correspondiente',
            latexExpression: '$defRelation \\implies $trigExprLatex = $resultLatex',
            pedagogicalNote:
                'Buscamos el ángulo principal cuyo valor trigonométrico exacto coincide con ${argNode.toLatex()} en modo ${unit == AngleUnit.deg ? "grados (DEG)" : "radianes (RAD)"}.',
          ),
        ],
        exactResultLatex: resultLatex,
        decimalApproxLatex: decimalApprox,
      );
    }

    final radResult = switch (function) {
      TrigFunction.asin => math.asin(val.clamp(-1.0, 1.0)),
      TrigFunction.acos => math.acos(val.clamp(-1.0, 1.0)),
      TrigFunction.atan => math.atan(val),
      _ => 0.0,
    };
    final outVal = unit == AngleUnit.deg ? radResult * 180.0 / math.pi : radResult;
    final formatted = formatDouble(outVal);
    final exactStr = unit == AngleUnit.deg ? '$formatted^\\circ' : formatted;

    return StepByStepResolution(
      originalInputLatex: trigExprLatex,
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Cálculo de arco trigonométrico',
          latexExpression: '$trigExprLatex \\approx $exactStr',
          pedagogicalNote:
              'Calculamos el ángulo inverso en ${unit == AngleUnit.deg ? "grados sexagesimales (DEG)" : "radianes (RAD)"}.',
        ),
      ],
      exactResultLatex: exactStr,
      decimalApproxLatex: exactStr,
    );
  }

  static int? matchNotableInverseDegrees(TrigFunction fn, double val) {
    const eps = 1e-7;
    if (fn == TrigFunction.asin) {
      final candidates = <int, double>{
        -90: -1.0,
        -60: -0.8660254037844386,
        -45: -0.7071067811865476,
        -30: -0.5,
        0: 0.0,
        30: 0.5,
        45: 0.7071067811865476,
        60: 0.8660254037844386,
        90: 1.0,
      };
      for (final e in candidates.entries) {
        if ((val - e.value).abs() < eps) return e.key;
      }
    } else if (fn == TrigFunction.acos) {
      final candidates = <int, double>{
        0: 1.0,
        30: 0.8660254037844386,
        45: 0.7071067811865476,
        60: 0.5,
        90: 0.0,
        120: -0.5,
        135: -0.7071067811865476,
        150: -0.8660254037844386,
        180: -1.0,
      };
      for (final e in candidates.entries) {
        if ((val - e.value).abs() < eps) return e.key;
      }
    } else if (fn == TrigFunction.atan) {
      final candidates = <int, double>{
        -60: -1.7320508075688772,
        -45: -1.0,
        -30: -0.5773502691896257,
        0: 0.0,
        30: 0.5773502691896257,
        45: 1.0,
        60: 1.7320508075688772,
      };
      for (final e in candidates.entries) {
        if ((val - e.value).abs() < eps) return e.key;
      }
    }
    return null;
  }

  static String degreesToPiFractionLatex(int deg) {
    if (deg == 0) return '0';
    final r = Rational(deg, 180);
    final sign = r.numerator < 0 ? '-' : '';
    final absNum = r.numerator.abs();
    if (r.denominator == 1) {
      return absNum == 1 ? '$sign\\pi' : '$sign$absNum\\pi';
    }
    final numStr = absNum == 1 ? r'\pi' : '$absNum\\pi';
    return '$sign\\frac{$numStr}{${r.denominator}}';
  }

  static String applySignToLatex(String baseLatex, int sign) {
    if (baseLatex == '0' || sign >= 0) return baseLatex;
    return '-$baseLatex';
  }

  static String formatDouble(double v) => DmsSolver.formatDouble(v);
}
