import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';

/// Formato LaTeX limpio para ecuaciones de la recta: sin `+ -3`, sin `1x`, sin `x - -2`.
abstract final class LineTex {
  static final Rational _one = Rational(1);

  static String r(Rational x) => ArsenalLatex.rat(x);

  /// Entre parentesis si es negativo o fraccion.
  static String p(Rational x) => ArsenalLatex.ratParen(x);

  /// Coeficiente delante de un simbolo: 1 -> vacio, -1 -> `-`.
  static String coef(Rational k) => k == _one ? '' : (k == -_one ? '-' : r(k));

  /// Suma de terminos `(coeficiente, simbolo)` con signos bien escritos; `0` si todos son cero.
  static String linear(List<(Rational, String)> terms) {
    final sb = StringBuffer();
    var first = true;
    for (final (k, sym) in terms) {
      if (k.isZero) continue;
      final a = k.abs();
      final body = sym.isEmpty ? r(a) : '${a == _one ? '' : r(a)}$sym';
      if (first) {
        sb.write(k.isNegative ? '-$body' : body);
        first = false;
      } else {
        sb.write(k.isNegative ? ' - $body' : ' + $body');
      }
    }
    return first ? '0' : sb.toString();
  }

  /// `x - k` (o `x + |k|`, o `x` si k = 0).
  static String shift(String v, Rational k) => linear([(_one, v), (-k, '')]);

  /// Forma general `Ax + By + C = 0`.
  static String general(Rational a, Rational b, Rational c) =>
      '${linear([(a, 'x'), (b, 'y'), (c, '')])} = 0';

  /// Forma explicita `y = mx + n`.
  static String explicit(Rational m, Rational n) => 'y = ${linear([(m, 'x'), (n, '')])}';

  /// `m(x - x0)` sin parentesis innecesarios.
  static String slopeTimes(Rational m, Rational x0) {
    if (m.isZero) return '0';
    if (x0.isZero) return '${coef(m)}x';
    final g = shift('x', x0);
    if (m == _one) return g;
    return '${coef(m)}\\left($g\\right)';
  }
}
