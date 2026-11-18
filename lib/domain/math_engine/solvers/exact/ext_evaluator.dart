import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart';
import 'exact_number.dart';
import 'ext_expr.dart';
import 'ext_math.dart';
import 'ext_trig.dart';

/// Evaluador exacto sobre [XNode] que registra los pasos didacticos de M1.
class ExtEvaluator {
  final AngleUnit angle;
  final Map<String, Rational> memory;
  final List<MathStep> steps = [];

  /// Valor exacto de la incognita `x` (para comprobar soluciones de ecuaciones).
  final ExNum? xValue;

  ExtEvaluator({required this.angle, this.memory = const {}, this.xValue});

  void _log(String title, XNode node, ExNum value, String note,
      {String? mid, String? warn}) {
    final left = node.latex();
    final right = value.toLatex();
    final body = mid == null ? '$left = $right' : '$left = $mid = $right';
    if (steps.isNotEmpty && steps.last.latexExpression == body) return;
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: title,
      latexExpression: body,
      pedagogicalNote: note,
      warningTrick: warn,
    ));
  }

  static String _wrap(ExNum n) =>
      n.isExact && n.terms.length > 1 ? '\\left(${n.toLatex()}\\right)' : n.toLatex();

  ExNum eval(XNode n) {
    switch (n) {
      case XNum(:final value):
        return ExNum.rational(value);
      case XConst(:final kind):
        return kind == 'pi' ? ExNum.pi() : ExNum.euler();
      case XVar(:final name):
        if (name == 'X' && xValue != null) return xValue!;
        return ExNum.rational(memory[name] ?? Rational(0));
      case XNeg(:final a):
        return -eval(a);
      case XBin():
        return _bin(n);
      case XPow():
        return _pow(n);
      case XRoot():
        return _root(n);
      case XAbs(:final a):
        final v = eval(a);
        final r = v.approx < 0 ? -v : v;
        _log('Valor absoluto', n, r,
            'El valor absoluto devuelve la distancia al cero: |a| = a si a es positivo y |a| = -a si a es negativo.');
        return r;
      case XFact(:final a):
        return _fact(n, a);
      case XComb():
        return _comb(n);
      case XFn():
        return _fn(n);
    }
  }

  ExNum _bin(XBin n) {
    final l = eval(n.l);
    final r = eval(n.r);
    switch (n.op) {
      case '+':
        return l + r;
      case '-':
        return l - r;
      case '*':
        return l * r;
      default:
        final f = r.rationalizingFactor();
        final out = l / r;
        if (f != null) {
          final ff = _wrap(f);
          _log(
            'Racionalizar el denominador',
            n,
            out,
            'Multiplicamos numerador y denominador por ${r.terms.length == 1 ? "la raíz del denominador" : "el conjugado del denominador"} para eliminar el radical de abajo.',
            mid: '\\frac{${_wrap(l)} \\cdot $ff}{${_wrap(r)} \\cdot $ff}',
            warn: 'Un resultado con raíz en el denominador no se considera simplificado en ESO y Bachillerato.',
          );
        }
        return out;
    }
  }

  ExNum _root(XRoot n) {
    final idx = n.index == null ? 2 : (eval(n.index!).asInt ?? 0);
    if (idx < 2 || idx > 12) throw const ExMathError();
    final x = eval(n.rad);
    ExNum out;
    final r = x.asRational;
    if (r != null) {
      out = ExtMath.nthRoot(r, idx);
    } else {
      if (x.approx < 0 && idx.isEven) throw const ExMathError(ExMathError.evenRootNegative);
      final lat = idx == 2 ? '\\sqrt{${x.toLatex()}}' : '\\sqrt[$idx]{${x.toLatex()}}';
      out = ExNum.opaque(lat, idx.isEven || x.approx >= 0
          ? math.pow(x.approx, 1 / idx).toDouble()
          : -math.pow(-x.approx, 1 / idx).toDouble());
    }
    final isInt = r != null && r.isInteger && r.numerator > 1;
    final mid = isInt
        ? (idx == 2
            ? '\\sqrt{${Rational.primeFactorizationLatex(r.numerator)}}'
            : '\\sqrt[$idx]{${Rational.primeFactorizationLatex(r.numerator)}}')
        : null;
    _log('Simplificar el radical', n, out,
        'Descomponemos el radicando en factores primos y sacamos fuera de la raíz los factores que se repiten $idx veces.',
        mid: mid);
    return out;
  }

  ExNum _pow(XPow n) {
    final b = eval(n.base);
    final e = eval(n.exp);
    final out = _powValues(b, e);
    final ei = e.asInt;
    if (ei == null || ei < 0) {
      final er = e.asRational;
      final note = ei != null
          ? 'Un exponente negativo invierte la base: a^(-n) = 1 / a^n.'
          : (er != null
              ? 'Una potencia de exponente fraccionario es una raíz: a^(p/q) = raíz q-ésima de a^p.'
              : 'Calculamos la potencia con exponente no entero.');
      _log('Potencia', n, out, note);
    }
    return out;
  }

  ExNum _powValues(ExNum b, ExNum e) {
    final ei = e.asInt;
    if (ei != null) {
      if (b.isZero && ei <= 0) throw const ExMathError();
      return b.powInt(ei);
    }
    final er = e.asRational;
    final br = b.asRational;
    if (er != null && br != null) {
      if (br.isZero) {
        if (er.isNegative) throw const ExMathError();
        return ExNum.integer(0);
      }
      if (br.isNegative && er.denominator.isEven) throw const ExMathError();
      final bp = ExNum.rational(br).powInt(er.numerator);
      final bpr = bp.asRational;
      if (bpr != null) return ExtMath.nthRoot(bpr, er.denominator);
    }
    if (b.approx < 0 && !b.approx.isNaN) throw const ExMathError();
    final lat = '${_wrap(b)}^{${e.toLatex()}}';
    return ExNum.opaque(lat, math.pow(b.approx, e.approx).toDouble());
  }

  ExNum _fact(XFact n, XNode a) {
    final v = eval(a).asInt;
    if (v == null) throw const ExMathError();
    final out = ExtMath.factorial(v);
    final mid = v >= 2 && v <= 8
        ? List.generate(v, (i) => '${v - i}').join(' \\cdot ')
        : null;
    _log('Factorial', n, out,
        'n! es el producto de todos los enteros desde n hasta 1 (y 0! = 1).',
        mid: mid);
    return out;
  }

  ExNum _comb(XComb n) {
    final a = eval(n.n).asInt;
    final b = eval(n.r).asInt;
    if (a == null || b == null) throw const ExMathError();
    final out = ExtMath.comb(a, b, perm: n.perm);
    final mid = n.perm
        ? '\\frac{$a!}{${a - b}!}'
        : '\\frac{$a!}{$b! \\cdot ${a - b}!}';
    _log(
      n.perm ? 'Variaciones (nPr)' : 'Combinaciones (nCr)',
      n,
      out,
      n.perm
          ? 'nPr = n! / (n - r)!: importa el orden de los elementos elegidos.'
          : 'nCr = n! / (r! · (n - r)!): no importa el orden de los elementos elegidos.',
      mid: mid,
    );
    return out;
  }

  ExNum _fn(XFn n) {
    final x = eval(n.arg);
    ExNum out;
    String title;
    String note;
    switch (n.name) {
      case 'sin' || 'cos' || 'tan':
        out = ExtTrig.direct(n.name, x, angle);
        title = 'Razón trigonométrica';
        note = 'Usamos los valores exactos de los ángulos notables (0°, 30°, 45°, 60°, 90°) y reducimos al primer cuadrante.';
      case 'asin' || 'acos' || 'atan':
        out = ExtTrig.inverse(n.name, x, angle);
        title = 'Función trigonométrica inversa';
        note = 'Buscamos el ángulo cuya razón trigonométrica vale ese número (resultado en ${_unitName()}).';
      case 'ln':
        out = _ln(x);
        title = 'Logaritmo neperiano';
        note = 'ln(x) es el exponente al que hay que elevar e para obtener x.';
      default:
        final base = n.base == null ? ExNum.integer(10) : eval(n.base!);
        out = _log2(base, x);
        title = n.base == null ? 'Logaritmo decimal' : 'Logaritmo en base b';
        note = 'log_b(x) es el exponente al que hay que elevar b para obtener x.';
    }
    _log(title, n, out, note);
    return out;
  }

  String _unitName() => switch (angle) {
        AngleUnit.deg => 'grados',
        AngleUnit.rad => 'radianes',
        AngleUnit.grad => 'gradianes',
      };

  ExNum _ln(ExNum x) {
    if (x.approx <= 0) throw const ExMathError();
    if (x.asRational == Rational(1)) return ExNum.integer(0);
    if (x.isExact && x.terms.length == 1) {
      final e = x.terms.entries.first;
      if (e.key == (1, 0, 1) && e.value == Rational(1)) return ExNum.integer(1);
      if (e.key.$1 == 1 && e.key.$2 == 0 && e.value == Rational(1)) {
        return ExNum.integer(e.key.$3);
      }
    }
    return ExNum.opaque('\\ln\\left(${x.toLatex()}\\right)', math.log(x.approx));
  }

  ExNum _log2(ExNum base, ExNum x) {
    if (x.approx <= 0 || base.approx <= 0 || (base.approx - 1).abs() < 1e-12) {
      throw const ExMathError();
    }
    final b = base.asRational;
    final v = x.asRational;
    if (b != null && v != null) {
      final k = ExtMath.logExact(b, v);
      if (k != null) return k;
    }
    final baseTxt = base.asInt == 10 ? '' : '_{${base.toLatex()}}';
    return ExNum.opaque(
      '\\log$baseTxt\\left(${x.toLatex()}\\right)',
      math.log(x.approx) / math.log(base.approx),
    );
  }
}
