import '../../core/rational.dart';

class System3x3Formatter {
  static String augmentedLatex(List<List<Rational>> m) {
    final rowsStr = m
        .map((r) => '${r[0].toLatex()} & ${r[1].toLatex()} & ${r[2].toLatex()} & ${r[3].toLatex()}')
        .join(' \\\\\n');
    return '\\left(\\begin{array}{ccc|c}\n$rowsStr\n\\end{array}\\right)';
  }

  static String fractionLatex(Rational num, Rational den, Rational simplified) {
    if (den == Rational(1)) return simplified.toLatex();
    if (num.isInteger && den.isInteger) {
      final raw = '\\frac{${num.numerator}}{${den.numerator}}';
      if (raw == simplified.toLatex()) return raw;
      return '$raw = ${simplified.toLatex()}';
    }
    return simplified.toLatex();
  }

  static String formatTerm(Rational coeff, String varName, {required bool isFirst}) {
    if (coeff.isZero) return '';
    final absVal = coeff.abs();
    final absCore = absVal == Rational(1) ? varName : '${absVal.toLatex()}$varName';
    if (isFirst) {
      return coeff.isNegative ? '-$absCore' : absCore;
    }
    return coeff.isNegative ? ' - $absCore' : ' + $absCore';
  }

  static String formatEquationLatex(
    Rational a,
    Rational b,
    Rational c,
    Rational d,
  ) {
    final buf = StringBuffer();
    bool hasWritten = false;
    for (final (coeff, v) in [(a, 'x'), (b, 'y'), (c, 'z')]) {
      final piece = formatTerm(coeff, v, isFirst: !hasWritten);
      if (piece.isNotEmpty) {
        buf.write(piece);
        hasWritten = true;
      }
    }
    final lhs = hasWritten ? buf.toString() : '0';
    return '$lhs = ${d.toLatex()}';
  }

  static String formatZEquation(Rational c3, Rational d3) {
    return '${formatTerm(c3, 'z', isFirst: true)} = ${d3.toLatex()}';
  }

  static String formatYBackSub(Rational b2, Rational c2, Rational z, Rational d2) {
    final left = formatTerm(b2, 'y', isFirst: true);
    if (c2.isZero) return '$left = ${d2.toLatex()}';
    final prod = c2 * z;
    if (prod.isZero) return '$left = ${d2.toLatex()}';
    final op = prod.isNegative ? ' - ' : ' + ';
    return '$left$op${prod.abs().toLatex()} = ${d2.toLatex()}';
  }

  static String formatXBackSub(
    Rational a1,
    Rational b1,
    Rational c1,
    Rational y,
    Rational z,
    Rational d1,
  ) {
    final buf = StringBuffer(formatTerm(a1, 'x', isFirst: true));
    final by = b1 * y;
    final cz = c1 * z;
    if (!by.isZero) {
      buf.write(by.isNegative ? ' - ${by.abs().toLatex()}' : ' + ${by.toLatex()}');
    }
    if (!cz.isZero) {
      buf.write(cz.isNegative ? ' - ${cz.abs().toLatex()}' : ' + ${cz.toLatex()}');
    }
    return '${buf.toString()} = ${d1.toLatex()}';
  }
}
