import '../../models/step_resolution.dart';

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
      buf.write(" ${formatSeconds(seconds)}''");
    }
    return buf.toString();
  }

  static String formatSeconds(double sec) {
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

class DmsSolver {
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
      final lat = effective.toLatex(includeZeroMinutes: true, includeZeroSeconds: false);
      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: [
          MathStep(
            index: 1,
            shortTitle: 'Ángulo sexagesimal',
            latexExpression: lat,
            pedagogicalNote: 'Ángulo en grados sexagesimales, minutos y segundos.',
          ),
        ],
        exactResultLatex: lat,
        decimalApproxLatex: '${formatDouble(effective.toDecimalDegrees())}^\\circ',
      );
    }

    // Caso de 2 términos: desglose detallado con acarreo / préstamo
    if (terms.length == 2) {
      final t1 = terms[0];
      final t2 = terms[1];
      final isSub = t2.isSubtract;

      final double dec1 = t1.isSubtract ? -t1.value.toDecimalDegrees() : t1.value.toDecimalDegrees();
      final double dec2 = isSub ? -t2.value.toDecimalDegrees() : t2.value.toDecimalDegrees();
      final double totalDec = dec1 + dec2;
      final resultDms = DmsValue.fromDecimalDegrees(totalDec);

      final steps = <MathStep>[];

      final rawDeg = t1.value.degrees + (isSub ? -t2.value.degrees : t2.value.degrees);
      final rawMin = t1.value.minutes + (isSub ? -t2.value.minutes : t2.value.minutes);
      final rawSec = t1.value.seconds + (isSub ? -t2.value.seconds : t2.value.seconds);

      steps.add(
        MathStep(
          index: 1,
          shortTitle: isSub ? 'Paso 1: Resta por columnas' : 'Paso 1: Suma por columnas',
          latexExpression:
              '\\begin{aligned} '
              '${isSub ? "\\text{Grados}:" : "\\text{Grados}:"} & ${t1.value.degrees}^\\circ ${isSub ? "-" : "+"} ${t2.value.degrees}^\\circ = $rawDeg^\\circ \\\\ '
              '${isSub ? "\\text{Minutos}:" : "\\text{Minutos}:"} & ${t1.value.minutes}\' ${isSub ? "-" : "+"} ${t2.value.minutes}\' = $rawMin\' \\\\ '
              '${isSub ? "\\text{Segundos}:" : "\\text{Segundos}:"} & ${DmsValue.formatSeconds(t1.value.seconds)}\'\' ${isSub ? "-" : "+"} ${DmsValue.formatSeconds(t2.value.seconds)}\'\' = ${DmsValue.formatSeconds(rawSec)}\'\' '
              '\\end{aligned}',
          pedagogicalNote: isSub
              ? 'Restamos las unidades de la misma especie: grados con grados, minutos con minutos y segundos con segundos.'
              : 'Sumamos primero por separado los grados, los minutos y los segundos.',
        ),
      );

      final bool needsBase60Adjustment = rawSec >= 60 || rawSec < 0 || rawMin >= 60 || rawMin < 0;

      if (needsBase60Adjustment) {
        steps.add(
          MathStep(
            index: 2,
            shortTitle: isSub ? 'Paso 2: Préstamos en base 60' : 'Paso 2: Acarreos en base 60 (60\'\' = 1\', 60\' = 1°)',
            latexExpression:
                '$rawDeg^\\circ \\; $rawMin\' \\; ${DmsValue.formatSeconds(rawSec)}\'\' \\implies '
                '${resultDms.toLatex(includeZeroMinutes: true, includeZeroSeconds: resultDms.seconds.abs() > 1e-6)}',
            pedagogicalNote: isSub
                ? 'Si los segundos o minutos quedan negativos, pedimos prestada 1 unidad superior (1° = 60\' o 1\' = 60\'\') para que todos los valores queden entre 0 y 59.'
                : 'Como 60\'\' = 1\' y 60\' = 1°, agrupamos de 60 en 60 hacia la izquierda para que los minutos y segundos queden estrictamente menores de 60.',
            warningTrick:
                'El sistema sexagesimal funciona en base 60: nunca dejes más de 59 segundos o 59 minutos en el resultado final.',
          ),
        );
      }

      final finalLatex = resultDms.toLatex(
        includeZeroMinutes: true,
        includeZeroSeconds: resultDms.seconds.abs() > 1e-6,
      );

      return StepByStepResolution(
        originalInputLatex: originalLatex,
        steps: steps,
        exactResultLatex: finalLatex,
        decimalApproxLatex: '${formatDouble(totalDec)}^\\circ',
      );
    }

    // Caso general de N términos
    double totalDeg = 0;
    for (final t in terms) {
      final dec = t.value.toDecimalDegrees();
      totalDeg += t.isSubtract ? -dec : dec;
    }
    final resultDms = DmsValue.fromDecimalDegrees(totalDeg);
    final finalLatex = resultDms.toLatex(
      includeZeroMinutes: true,
      includeZeroSeconds: resultDms.seconds.abs() > 1e-6,
    );

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Operación combinada sexagesimal',
        latexExpression: '$originalLatex = $finalLatex',
        pedagogicalNote:
            'Agrupamos todas las cantidades en grados, minutos y segundos ajustando en base 60.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: originalLatex,
      steps: steps,
      exactResultLatex: finalLatex,
      decimalApproxLatex: '${formatDouble(totalDeg)}^\\circ',
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

    final orig = originalLatex ?? formatDouble(decimalDegrees);
    final resultLatex = dms.toLatex(
      includeZeroMinutes: true,
      includeZeroSeconds: true,
    );

    final steps = <MathStep>[
      MathStep(
        index: 1,
        shortTitle: 'Parte entera = Grados',
        latexExpression:
            '${isNeg ? "-" : ""}${formatDouble(absVal)}^\\circ \\implies ${isNeg ? "-" : ""}${dms.degrees}^\\circ + ${formatDouble(fracDeg)}^\\circ',
        pedagogicalNote:
            'La parte entera (${dms.degrees}) corresponde directamente a los grados completos.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Parte decimal × 60 = Minutos',
        latexExpression:
            '${formatDouble(fracDeg)} \\cdot 60 = ${formatDouble(rawMin)}\' \\implies $intMin\'',
        pedagogicalNote:
            'Multiplicamos los decimales de grado por 60 para obtener los minutos enteros ($intMin\').',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Decimales de minuto × 60 = Segundos',
        latexExpression:
            '${formatDouble(fracMin)} \\cdot 60 = ${DmsValue.formatSeconds(dms.seconds)}\'\' \\implies $resultLatex',
        pedagogicalNote:
            'Multiplicamos la parte decimal restante por 60 para obtener los segundos exactos.',
      ),
    ];

    return StepByStepResolution(
      originalInputLatex: '$orig^\\circ',
      steps: steps,
      exactResultLatex: resultLatex,
      decimalApproxLatex: '${formatDouble(decimalDegrees)}^\\circ',
    );
  }

  static String formatDouble(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-9) {
      return '${v.round()}';
    }
    String s = v.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }
}
