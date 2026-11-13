import 'dart:math' as math;
import '../ast/ast_nodes.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';

enum AngleUnit { deg, rad }

/// Representa un ángulo en Sistema Sexagesimal (grados, minutos y segundos).
class DmsValue {
  final bool isNegative;
  final int degrees;
  final int minutes;
  final double seconds;

  const DmsValue({
    required this.degrees,
    this.minutes = 0,
    this.seconds = 0,
    this.isNegative = false,
  });

  /// Convierte grados decimales exactos a DMS redondeando los segundos a centésimas limpias.
  factory DmsValue.fromDecimalDegrees(double decDegrees) {
    final neg = decDegrees < 0;
    final absVal = decDegrees.abs();
    // Redondeo en total de milésimas de segundo para evitar deriva binaria (ej. 34.52 -> 34°31'12")
    final totalMilliSeconds = (absVal * 3600000).round();
    final deg = totalMilliSeconds ~/ 3600000;
    final remAfterDeg = totalMilliSeconds % 3600000;
    final min = remAfterDeg ~/ 60000;
    final remMilliSec = remAfterDeg % 60000;
    final sec = remMilliSec / 1000.0;
    return DmsValue(
      degrees: deg,
      minutes: min,
      seconds: sec,
      isNegative: neg && (deg != 0 || min != 0 || sec > 1e-6),
    );
  }

  double toDecimalDegrees() {
    final absVal = degrees + minutes / 60.0 + seconds / 3600.0;
    return isNegative ? -absVal : absVal;
  }

  String toLatex({bool includeZeroMinutes = true, bool includeZeroSeconds = false}) {
    final sign = isNegative ? '-' : '';
    final buf = StringBuffer('$sign$degrees^\\circ');
    final hasNonZeroSec = seconds.abs() > 1e-6;
    if (includeZeroMinutes || minutes != 0 || hasNonZeroSec) {
      buf.write(" $minutes'");
    }
    if (includeZeroSeconds || hasNonZeroSec) {
      buf.write(" ${_formatSeconds(seconds)}''");
    }
    return buf.toString();
  }

  static String _formatSeconds(double sec) {
    final rounded = double.parse(sec.toStringAsFixed(2));
    if ((rounded - rounded.roundToDouble()).abs() < 1e-6) {
      return '${rounded.round()}';
    }
    return rounded
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }
}

class _NotableFirstQuadEntry {
  final String sinLatex;
  final String? sinRawUnrationalized;
  final String cosLatex;
  final String? cosRawUnrationalized;
  final String? tanLatex; // null = indefinido (90°)
  final String? tanRawUnrationalized;
  final double sinVal;
  final double cosVal;
  final double? tanVal;

  const _NotableFirstQuadEntry({
    required this.sinLatex,
    this.sinRawUnrationalized,
    required this.cosLatex,
    this.cosRawUnrationalized,
    required this.tanLatex,
    this.tanRawUnrationalized,
    required this.sinVal,
    required this.cosVal,
    required this.tanVal,
  });
}

class TrigAndAnglesSolver {
  static const Map<int, _NotableFirstQuadEntry> _firstQuadTable = {
    0: _NotableFirstQuadEntry(
      sinLatex: '0',
      cosLatex: '1',
      tanLatex: '0',
      tanRawUnrationalized: null,
      sinVal: 0,
      cosVal: 1,
      tanVal: 0,
    ),
    30: _NotableFirstQuadEntry(
      sinLatex: r'\frac{1}{2}',
      cosLatex: r'\frac{\sqrt{3}}{2}',
      tanLatex: r'\frac{\sqrt{3}}{3}',
      tanRawUnrationalized: r'\frac{1}{\sqrt{3}}',
      sinVal: 0.5,
      cosVal: 0.8660254037844386,
      tanVal: 0.5773502691896257,
    ),
    45: _NotableFirstQuadEntry(
      sinLatex: r'\frac{\sqrt{2}}{2}',
      sinRawUnrationalized: r'\frac{1}{\sqrt{2}}',
      cosLatex: r'\frac{\sqrt{2}}{2}',
      cosRawUnrationalized: r'\frac{1}{\sqrt{2}}',
      tanLatex: '1',
      sinVal: 0.7071067811865476,
      cosVal: 0.7071067811865476,
      tanVal: 1,
    ),
    60: _NotableFirstQuadEntry(
      sinLatex: r'\frac{\sqrt{3}}{2}',
      cosLatex: r'\frac{1}{2}',
      tanLatex: r'\sqrt{3}',
      sinVal: 0.8660254037844386,
      cosVal: 0.5,
      tanVal: 1.7320508075688772,
    ),
    90: _NotableFirstQuadEntry(
      sinLatex: '1',
      cosLatex: '0',
      tanLatex: null,
      tanRawUnrationalized: null,
      sinVal: 1,
      cosVal: 0,
      tanVal: null,
    ),
  };

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
      TrigFunction.sin || TrigFunction.cos || TrigFunction.tan => _solveDirectTrig(
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
        _solveInverseTrig(
          function: function,
          trigExprLatex: trigExprLatex,
          argNode: argNode,
          unit: unit,
          evaluatedNumericArg: evaluatedNumericArg,
          exactRationalArg: exactRationalArg,
        ),
    };
  }

  static StepByStepResolution _solveDirectTrig({
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

    // Determinar ángulo exacto en grados si es entero notable (desde DEG, DMS exacto, o múltiplo racional de pi)
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

      // Reducción al primer cuadrante
      final ({int refDeg, int sign, String? quadNote, String? quadFormula}) reduction =
          _reduceToFirstQuadrant(normalized, function);

      final entry = _firstQuadTable[reduction.refDeg];
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

        final signedExact = _applySignToLatex(baseLatex, reduction.sign);
        final signedNumeric = reduction.sign * numericVal;

        if (rawUnrationalized != null) {
          final signedRaw = _applySignToLatex(rawUnrationalized, reduction.sign);
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
          decimalApproxLatex: _formatDouble(signedNumeric),
        );
      }
    }

    // Fallback numérico preciso para ángulos no notables (ej. sin(37°))
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
    final approx = _formatDouble(result);

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
      _reduceToFirstQuadrant(int normalizedDeg, TrigFunction fn) {
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

  static StepByStepResolution _solveInverseTrig({
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
                'No existe ningún ángulo real cuyo ${function == TrigFunction.asin ? "seno" : "coseno"} sea ${_formatDouble(val)}.',
            warningTrick:
                'El valor introducido debe estar siempre comprendido entre -1 y 1.',
          ),
        ],
        exactResultLatex: r'\text{No existe}',
        decimalApproxLatex: r'\text{No existe}',
      );
    }

    // Buscar si coincide exactamente con algún valor notable conocido
    final int? notableDeg = _matchNotableInverseDegrees(function, val);
    if (notableDeg != null) {
      final radFracLatex = _degreesToPiFractionLatex(notableDeg);
      final radApprox = _formatDouble(notableDeg * math.pi / 180.0);

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
    final formatted = _formatDouble(outVal);
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

  static int? _matchNotableInverseDegrees(TrigFunction fn, double val) {
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

  static String _degreesToPiFractionLatex(int deg) {
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

  /// Opera sumas y restas en Sistema Sexagesimal explicando los acarreos/préstamos en base 60.
  static StepByStepResolution solveDmsOperation({
    required String originalLatex,
    required List<({DmsValue value, bool isSubtract})> terms,
  }) {
    if (terms.isEmpty) {
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: const [],
        exactResultLatex: '0^\\circ',
        decimalApproxLatex: '0',
      );
    }

    if (terms.length == 1) {
      final single = terms.first;
      final effective = DmsValue(
        degrees: single.value.degrees,
        minutes: single.value.minutes,
        seconds: single.value.seconds,
        isNegative: single.isSubtract ? !single.value.isNegative : single.value.isNegative,
      );
      // Normalizar si metió p.ej. 75' o 90''
      final norm = DmsValue.fromDecimalDegrees(effective.toDecimalDegrees());
      final exactLatex = norm.toLatex(
        includeZeroMinutes: true,
        includeZeroSeconds: norm.seconds > 1e-6 || single.value.seconds > 1e-6,
      );
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Ángulo en sistema sexagesimal',
            latexExpression: '$originalLatex = $exactLatex',
            pedagogicalNote:
                'Cada grado equivale a 60 minutos y cada minuto a 60 segundos.',
          ),
        ],
        exactResultLatex: exactLatex,
        decimalApproxLatex: '${_formatDouble(norm.toDecimalDegrees())}^\\circ',
      );
    }

    final List<MathStep> steps = [];
    int stepIdx = 1;

    // Caso pedagógico binario puro (A + B o A - B con términos positivos) para mostrar columnas y acarreos/préstamos
    if (terms.length == 2 && !terms[0].value.isNegative && !terms[1].value.isNegative) {
      final a = terms[0].value;
      final b = terms[1].value;
      final isSub = terms[1].isSubtract;
      final showSecs = a.seconds > 1e-6 || b.seconds > 1e-6;

      if (!isSub && !terms[0].isSubtract) {
        // Suma directa por columnas
        final rawSec = a.seconds + b.seconds;
        final rawMin = a.minutes + b.minutes;
        final rawDeg = a.degrees + b.degrees;
        final rawDms = DmsValue(degrees: rawDeg, minutes: rawMin, seconds: rawSec);

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Suma por columnas (° , \' , \'\')',
            latexExpression:
                '${a.toLatex(includeZeroSeconds: showSecs)} + ${b.toLatex(includeZeroSeconds: showSecs)} = ${rawDms.toLatex(includeZeroSeconds: showSecs)}',
            pedagogicalNote:
                'Sumamos por separado los grados, los minutos y los segundos.',
          ),
        );

        final norm = DmsValue.fromDecimalDegrees(rawDms.toDecimalDegrees());
        final needsCarry = rawSec >= 60 - 1e-6 || rawMin >= 60;
        if (needsCarry) {
          steps.add(
            MathStep(
              index: stepIdx++,
              shortTitle: 'Ajuste en base 60 (acarreo)',
              latexExpression:
                  '${rawDms.toLatex(includeZeroSeconds: showSecs)} = ${norm.toLatex(includeZeroSeconds: showSecs || norm.seconds > 1e-6)}',
              pedagogicalNote:
                  'Como cada 60 segundos forman 1 minuto y cada 60 minutos forman 1 grado, convertimos los excesos >= 60.',
              warningTrick: 'Recuerda: en base 60 el tope de minutos y segundos es 59.',
            ),
          );
        }

        final finalLatex = norm.toLatex(includeZeroSeconds: showSecs || norm.seconds > 1e-6);
        return StepByStepResolution(
          originalInputLatex: originalLatex,
          steps: steps,
          exactResultLatex: finalLatex,
          decimalApproxLatex: '${_formatDouble(norm.toDecimalDegrees())}^\\circ',
        );
      }

      if (isSub && !terms[0].isSubtract && a.toDecimalDegrees() >= b.toDecimalDegrees()) {
        int degA = a.degrees;
        int minA = a.minutes;
        double secA = a.seconds;

        if (secA < b.seconds) {
          minA -= 1;
          secA += 60;
        }
        if (minA < b.minutes) {
          degA -= 1;
          minA += 60;
        }
        final borrowedA = DmsValue(degrees: degA, minutes: minA, seconds: secA);

        if (degA != a.degrees || minA != a.minutes) {
          steps.add(
            MathStep(
              index: stepIdx++,
              shortTitle: 'Préstamo en base 60',
              latexExpression:
                  '${a.toLatex(includeZeroSeconds: showSecs)} = ${borrowedA.toLatex(includeZeroSeconds: showSecs)}',
              pedagogicalNote:
                  'Al ser menor alguna columna superior, pedimos 1 grado (= 60\') o 1 minuto (= 60\'\') a la unidad izquierda.',
              warningTrick: 'Nunca pidas 100 al vecino: en ángulos se suma 60.',
            ),
          );
        }

        final resDeg = degA - b.degrees;
        final resMin = minA - b.minutes;
        final resSec = secA - b.seconds;
        final resDms = DmsValue.fromDecimalDegrees(
          DmsValue(degrees: resDeg, minutes: resMin, seconds: resSec).toDecimalDegrees(),
        );
        final finalLatex = resDms.toLatex(includeZeroSeconds: showSecs || resDms.seconds > 1e-6);

        steps.add(
          MathStep(
            index: stepIdx++,
            shortTitle: 'Resta por columnas',
            latexExpression:
                '${borrowedA.toLatex(includeZeroSeconds: showSecs)} - ${b.toLatex(includeZeroSeconds: showSecs)} = $finalLatex',
            pedagogicalNote:
                'Restamos segundos con segundos, minutos con minutos y grados con grados.',
          ),
        );

        return StepByStepResolution(
          originalInputLatex: originalLatex,
          steps: steps,
          exactResultLatex: finalLatex,
          decimalApproxLatex: '${_formatDouble(resDms.toDecimalDegrees())}^\\circ',
        );
      }
    }

    // Suma/resta N-aria general pasando por segundos totales
    double totalDeg = 0;
    for (final term in terms) {
      final val = term.value.toDecimalDegrees();
      totalDeg += term.isSubtract ? -val : val;
    }
    final resDms = DmsValue.fromDecimalDegrees(totalDeg);
    final hasAnySec = resDms.seconds > 1e-6 || terms.any((t) => t.value.seconds > 1e-6);
    final finalLatex = resDms.toLatex(includeZeroSeconds: hasAnySec);

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Operación combinada sexagesimal',
        latexExpression: '$originalLatex = $finalLatex',
        pedagogicalNote:
            'Agrupamos todas las cantidades en grados, minutos y segundos ajustando en base 60.',
      ),
    );

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: finalLatex,
      decimalApproxLatex: '${_formatDouble(totalDeg)}^\\circ',
    );
  }

  /// Convierte un ángulo decimal (ej. 34.52°) a Grados, Minutos y Segundos paso a paso.
  static StepByStepResolution solveDecimalToDms(
    double decimalDegrees, {
    String? originalLatex,
  }) {
    final isNeg = decimalDegrees < 0;
    final absVal = decimalDegrees.abs();
    final dms = DmsValue.fromDecimalDegrees(decimalDegrees);

    final fracDeg = absVal - absVal.floorToDouble();
    final rawMin = fracDeg * 60.0;
    final intMin = dms.minutes;
    final fracMin = (rawMin - intMin).abs();

    final orig = originalLatex ?? _formatDouble(decimalDegrees);
    final resultLatex = dms.toLatex(
      includeZeroMinutes: true,
      includeZeroSeconds: true,
    );

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Parte entera = Grados',
        latexExpression:
            '${isNeg ? "-" : ""}${_formatDouble(absVal)}^\\circ \\implies ${isNeg ? "-" : ""}${dms.degrees}^\\circ + ${_formatDouble(fracDeg)}^\\circ',
        pedagogicalNote:
            'La parte entera (${dms.degrees}) corresponde directamente a los grados completos.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Parte decimal × 60 = Minutos',
        latexExpression:
            '${_formatDouble(fracDeg)} \\cdot 60 = ${_formatDouble(rawMin)}\' \\implies $intMin\'',
        pedagogicalNote:
            'Multiplicamos los decimales de grado por 60 para obtener los minutos enteros ($intMin\').',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Decimales de minuto × 60 = Segundos',
        latexExpression:
            '${_formatDouble(fracMin)} \\cdot 60 = ${DmsValue._formatSeconds(dms.seconds)}\'\' \\implies $resultLatex',
        pedagogicalNote:
            'Multiplicamos la parte decimal restante por 60 para obtener los segundos exactos.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: '$orig^\\circ',
      steps: steps,
      exactResultLatex: resultLatex,
      decimalApproxLatex: '${_formatDouble(decimalDegrees)}^\\circ',
    );
  }

  static String _applySignToLatex(String baseLatex, int sign) {
    if (baseLatex == '0' || sign >= 0) return baseLatex;
    return '-$baseLatex';
  }

  static String _formatDouble(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-9) {
      return '${v.round()}';
    }
    String s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }
}
