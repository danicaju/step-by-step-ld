import '../core/rational.dart';
import 'domain_solver.dart';

/// Lado de aproximacion de un limite.
enum LimSide { both, left, right }

/// Valor de un limite: finito, +-infinito o inexistente.
class LimitValue {
  final Rational? finite;
  final int inf; // +1, -1 o 0
  final bool exists;
  final bool estimated;
  final double? approx; // valor decimal cuando no es racional exacto

  const LimitValue._(this.finite, this.inf, this.exists, this.estimated, this.approx);

  factory LimitValue.number(Rational r, {bool estimated = false}) => LimitValue._(r, 0, true, estimated, r.toDouble());
  factory LimitValue.decimal(double v) => LimitValue._(null, 0, true, true, v);
  factory LimitValue.infinite(int sign, {bool estimated = false}) =>
      LimitValue._(null, sign >= 0 ? 1 : -1, true, estimated, sign >= 0 ? double.infinity : double.negativeInfinity);
  static const LimitValue none = LimitValue._(null, 0, false, false, null);

  bool get isInfinite => inf != 0;
  bool get isFinite => exists && inf == 0;

  double get toDouble => approx ?? double.nan;

  String get latex {
    if (!exists) return r'\nexists';
    if (inf > 0) return r'+\infty';
    if (inf < 0) return r'-\infty';
    if (finite != null) return domainRationalLatex(finite!);
    return approx!.toStringAsFixed(4).replaceAll('.', '{,}');
  }
}

/// Asintota con su ecuacion (LaTeX) y datos numericos para el visor.
class Asymptote {
  final String latex; // `x = 2`, `y = 1`, `y = 2x + 3`
  final double x; // vertical
  final double m; // oblicua / horizontal (m = 0)
  final double n;
  final String tag; // `\to +\infty`, `\to -\infty` o ``
  final bool estimated;

  const Asymptote.vertical(this.latex, this.x, {this.estimated = false})
      : m = 0,
        n = 0,
        tag = '';
  const Asymptote.line(this.latex, this.m, this.n, {this.tag = '', this.estimated = false}) : x = 0;
}

/// Conjunto de asintotas de una funcion.
class AsymptoteSet {
  final List<Asymptote> vertical;
  final List<Asymptote> horizontal;
  final List<Asymptote> oblique;

  const AsymptoteSet({this.vertical = const [], this.horizontal = const [], this.oblique = const []});

  static const AsymptoteSet empty = AsymptoteSet();

  List<double> get verticalXs => [for (final v in vertical) v.x];
  bool get isEmpty => vertical.isEmpty && horizontal.isEmpty && oblique.isEmpty;
}
