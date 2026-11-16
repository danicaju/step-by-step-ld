import '../../core/rational.dart';

class MatrixHelpers {
  static String wrapNegative(Rational r) {
    final l = r.toLatex();
    if (r.isNegative || !r.isInteger) return '\\left($l\\right)';
    return l;
  }

  static String tripleProduct(Rational x, Rational y, Rational z) {
    return '${wrapNegative(x)} \\cdot ${_wrapNegative(y)} \\cdot ${_wrapNegative(z)}';
  }

  static String _wrapNegative(Rational r) => wrapNegative(r);

  static String formatBinarySumCell(
    Rational a,
    Rational b, {
    required bool isSubtract,
  }) {
    final left = a.toLatex();
    if (!isSubtract) {
      if (b.isNegative) {
        return '$left - ${b.abs().toLatex()}';
      }
      return '$left + ${b.toLatex()}';
    } else {
      if (b.isNegative) {
        return '$left + ${b.abs().toLatex()}';
      }
      return '$left - ${b.toLatex()}';
    }
  }

  static String formatSignedOperand(Rational r) {
    if (r.isNegative) return '- ${r.abs().toLatex()}';
    return '+ ${r.toLatex()}';
  }

  static String formatSignedSumTerms(List<Rational> terms) {
    if (terms.isEmpty) return '0';
    final buf = StringBuffer();
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      if (i == 0) {
        buf.write(t.toLatex());
      } else {
        buf.write(t.isNegative ? ' - ${t.abs().toLatex()}' : ' + ${t.toLatex()}');
      }
    }
    return buf.toString();
  }

  static String matrixRowsToLatex(List<List<Rational>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) return '()';
    final colSpec = List.filled(rows.first.length, 'c').join();
    final rowLines = rows
        .map((r) => r.map((v) => v.toLatex()).join(' & '))
        .join(' \\\\\n');
    return '\\left(\\begin{array}{$colSpec}\n$rowLines\n\\end{array}\\right)';
  }
}
