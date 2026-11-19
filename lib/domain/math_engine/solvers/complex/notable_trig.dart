import '../../core/rational.dart';

/// Coseno y seno exactos de los angulos notables (multiplos de 30° y de 45°) de toda la circunferencia.
typedef NotableTrig = ({
  Rational? rationalCos,
  Rational? rationalSin,
  String cosLatex,
  String sinLatex,
  Rational cosRadCoeff,
  int cosRad,
  Rational sinRadCoeff,
  int sinRad,
});

class NotableTrigTable {
  const NotableTrigTable._();

  static NotableTrig _q(Rational c, Rational s, String cl, String sl) => (
        rationalCos: c,
        rationalSin: s,
        cosLatex: cl,
        sinLatex: sl,
        cosRadCoeff: c,
        cosRad: 1,
        sinRadCoeff: s,
        sinRad: 1,
      );

  /// Angulos del primer cuadrante (y los ejes).
  static NotableTrig? _firstQuadrant(int d) {
    switch (d) {
      case 0:
        return _q(Rational(1), Rational(0), '1', '0');
      case 90:
        return _q(Rational(0), Rational(1), '0', '1');
      case 180:
        return _q(Rational(-1), Rational(0), '-1', '0');
      case 270:
        return _q(Rational(0), Rational(-1), '0', '-1');
      case 45:
        return (
          rationalCos: null,
          rationalSin: null,
          cosLatex: r'\frac{\sqrt{2}}{2}',
          sinLatex: r'\frac{\sqrt{2}}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 2,
          sinRadCoeff: Rational(1, 2),
          sinRad: 2,
        );
      case 30:
        return (
          rationalCos: null,
          rationalSin: Rational(1, 2),
          cosLatex: r'\frac{\sqrt{3}}{2}',
          sinLatex: r'\frac{1}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 3,
          sinRadCoeff: Rational(1, 2),
          sinRad: 1,
        );
      case 60:
        return (
          rationalCos: Rational(1, 2),
          rationalSin: null,
          cosLatex: r'\frac{1}{2}',
          sinLatex: r'\frac{\sqrt{3}}{2}',
          cosRadCoeff: Rational(1, 2),
          cosRad: 1,
          sinRadCoeff: Rational(1, 2),
          sinRad: 3,
        );
      default:
        return null;
    }
  }

  static String _neg(String s) => s == '0' ? s : (s.startsWith('-') ? s.substring(1) : '-$s');

  /// `null` si el angulo no es multiplo de 30° ni de 45°.
  static NotableTrig? of(int deg) {
    final d = ((deg % 360) + 360) % 360;
    final direct = _firstQuadrant(d);
    if (direct != null) return direct;
    if (d <= 90) return null;
    // Angulo de referencia en el primer cuadrante y signos por cuadrante.
    final ref = d < 180 ? 180 - d : (d < 270 ? d - 180 : 360 - d);
    final base = _firstQuadrant(ref);
    if (base == null) return null;
    final cosNeg = d > 90 && d < 270;
    final sinNeg = d > 180;
    Rational? flip(Rational? r, bool neg) => r == null ? null : (neg ? -r : r);
    return (
      rationalCos: flip(base.rationalCos, cosNeg),
      rationalSin: flip(base.rationalSin, sinNeg),
      cosLatex: cosNeg ? _neg(base.cosLatex) : base.cosLatex,
      sinLatex: sinNeg ? _neg(base.sinLatex) : base.sinLatex,
      cosRadCoeff: flip(base.cosRadCoeff, cosNeg)!,
      cosRad: base.cosRad,
      sinRadCoeff: flip(base.sinRadCoeff, sinNeg)!,
      sinRad: base.sinRad,
    );
  }
}
