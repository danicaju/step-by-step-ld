import 'dart:math' as math;

import '../arithmetic/casio_iberia_arsenal.dart';
import '../core/rational.dart';

/// Numero de la forma `coef * sqrt(rad)` con `rad` libre de cuadrados (radicales simplificados).
class Surd {
  final Rational coef;
  final int rad;
  const Surd._(this.coef, this.rad);

  factory Surd(Rational coef, int rad) {
    var r = rad < 1 ? 1 : rad;
    var k = 1;
    for (var i = 2; i * i <= r && i <= 1000000; i++) {
      while (r % (i * i) == 0) {
        r ~/= i * i;
        k *= i;
      }
    }
    return Surd._(coef * Rational(k), r);
  }

  /// Raiz cuadrada exacta de un racional no negativo: sqrt(p/d) = sqrt(p·d)/d.
  static Surd sqrtOf(Rational q) => Surd(Rational(1, q.denominator), q.numerator * q.denominator);

  bool get isRational => rad == 1 || coef.isZero;
  double get value => coef.toDouble() * math.sqrt(rad);

  Surd operator *(Surd o) => Surd(coef * o.coef, rad * o.rad);

  /// Division racionalizada: (c1·√r1)/(c2·√r2) = (c1/c2)·√(r1·r2)/r2.
  Surd operator /(Surd o) => Surd(coef / o.coef / Rational(o.rad), rad * o.rad);

  String get latex {
    if (coef.isZero) return '0';
    if (rad == 1) return ArsenalLatex.rat(coef);
    final sign = coef.isNegative ? '-' : '';
    final a = coef.abs();
    final root = '\\sqrt{$rad}';
    if (a.isInteger) return '$sign${a.numerator == 1 ? '' : a.numerator}$root';
    return '$sign\\frac{${a.numerator == 1 ? '' : a.numerator}$root}{${a.denominator}}';
  }
}

/// Valor decimal con su forma exacta opcional (si todos los datos son racionales o angulos notables).
class Val {
  final double v;
  final Surd? ex;
  const Val(this.v, [this.ex]);

  /// Racional exacto si [x] tiene a lo sumo 4 decimales; si no, solo decimal.
  factory Val.of(double x) {
    if (x.abs() < 1e6) {
      final r = Rational.fromDouble(x);
      if ((r.toDouble() - x).abs() < 1e-9) return Val(x, Surd(r, 1));
    }
    return Val(x);
  }

  static double _near(double deg) => deg.roundToDouble();
  static bool _is(double deg, int k) => (deg - k).abs() < 1e-9 && _near(deg) == k.toDouble();

  static Val _surd(double v, int num, int den, int rad) => Val(v, Surd(Rational(num, den), rad));

  static Val sinD(double d) {
    final v = math.sin(d * math.pi / 180);
    if (_is(d, 30) || _is(d, 150)) return _surd(v, 1, 2, 1);
    if (_is(d, 45) || _is(d, 135)) return _surd(v, 1, 2, 2);
    if (_is(d, 60) || _is(d, 120)) return _surd(v, 1, 2, 3);
    if (_is(d, 90)) return _surd(v, 1, 1, 1);
    return Val(v);
  }

  static Val cosD(double d) {
    final v = math.cos(d * math.pi / 180);
    if (_is(d, 30)) return _surd(v, 1, 2, 3);
    if (_is(d, 45)) return _surd(v, 1, 2, 2);
    if (_is(d, 60)) return _surd(v, 1, 2, 1);
    if (_is(d, 90)) return _surd(0, 0, 1, 1);
    if (_is(d, 120)) return _surd(v, -1, 2, 1);
    if (_is(d, 135)) return _surd(v, -1, 2, 2);
    if (_is(d, 150)) return _surd(v, -1, 2, 3);
    return Val(v);
  }

  static Val tanD(double d) {
    final v = math.tan(d * math.pi / 180);
    if (_is(d, 30)) return _surd(v, 1, 3, 3);
    if (_is(d, 45)) return _surd(v, 1, 1, 1);
    if (_is(d, 60)) return _surd(v, 1, 1, 3);
    return Val(v);
  }

  Val operator *(Val o) => Val(v * o.v, ex != null && o.ex != null ? ex! * o.ex! : null);

  Val operator /(Val o) =>
      Val(v / o.v, ex != null && o.ex != null && !o.ex!.coef.isZero ? ex! / o.ex! : null);

  Val operator +(Val o) => _sum(o, 1);
  Val operator -(Val o) => _sum(o, -1);

  Val _sum(Val o, int sign) {
    final dv = v + sign * o.v;
    final a = ex, b = o.ex;
    if (a == null || b == null) return Val(dv);
    if (a.isRational && b.isRational) return Val(dv, Surd(a.coef + (sign == 1 ? b.coef : -b.coef), 1));
    if (a.rad == b.rad) return Val(dv, Surd(a.coef + (sign == 1 ? b.coef : -b.coef), a.rad));
    return Val(dv);
  }

  Val sq() => this * this;

  /// Raiz exacta si el radicando es racional no negativo.
  Val sqrt() {
    final r = math.sqrt(v < 0 ? 0 : v);
    final a = ex;
    if (a != null && a.isRational && !a.coef.isNegative) return Val(r, Surd.sqrtOf(a.coef));
    return Val(r);
  }

  /// Racional exacto (sin radicales), si lo hay.
  Rational? get rational => ex != null && ex!.isRational ? ex!.coef : null;

  String _dec(int d) {
    var s = v.toStringAsFixed(d);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return (s == '-0' ? '0' : s).replaceAll('.', '{,}');
  }

  /// Decimal con coma, sin ceros sobrantes.
  String dec([int d = 4]) => _dec(d);

  /// Forma exacta si existe; si no, el decimal.
  String get tex => ex?.latex ?? dec();

  /// Como [tex] pero entre parentesis si es negativo o fraccion (para sustituir en formulas).
  String get paren {
    final t = tex;
    return t.startsWith('-') || t.contains('frac') ? '\\left($t\\right)' : t;
  }

  /// Como [eq] para una raiz: evita repetir `\sqrt{57} = \sqrt{57}` cuando no se simplifica.
  String eqRoot(Val radicand) {
    final root = '\\sqrt{${radicand.tex}}';
    return ex != null && ex!.latex == root ? eq : '= $root $eq';
  }

  /// `= exacto`, `= exacto \approx decimal` o `\approx decimal`.
  String get eq {
    final a = ex;
    if (a == null) return '\\approx ${dec()}';
    if (a.isRational && a.coef.isInteger) return '= ${a.latex}';
    final exact = a.latex;
    final decimal = dec();
    if (a.isRational && decimal == exact) return '= $exact';
    return '= $exact \\approx $decimal';
  }
}
