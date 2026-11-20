import 'dart:math' as math;

import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart';
import 'ext_evaluator.dart';
import 'ext_expr.dart';

/// Simplificaciones por identidades fundamentales sobre el AST extendido de M1:
/// `sin^2 + cos^2 = 1`, `cosh^2 - sinh^2 = 1`, `ln(e^a) = a`, `e^{ln a} = a` y
/// `arcsin(sin t)`, `arccos(cos t)`, `arctan(tan t)` = `t` en rango principal.
class IdentitySimplifier {
  final List<MathStep> steps;
  final AngleUnit angle;

  IdentitySimplifier._(this.steps, this.angle);

  /// Devuelve [root] simplificado y anade un paso por cada identidad aplicada.
  static XNode apply(XNode root, List<MathStep> steps, {AngleUnit angle = AngleUnit.deg}) =>
      IdentitySimplifier._(steps, angle)._rw(root);

  void _log(XNode before, XNode after, String title, String note) {
    steps.add(MathStep(
      index: steps.length + 1,
      shortTitle: title,
      latexExpression: '${before.latex()} = ${after.latex()}',
      pedagogicalNote: note,
    ));
  }

  XNode _rw(XNode n) => switch (n) {
        XNeg(:final a) => XNeg(_rw(a)),
        XBin(:final l, :final op, :final r) => _sum(XBin(_rw(l), op, _rw(r))),
        XPow(:final base, :final exp) => _expLn(XPow(_rw(base), _rw(exp))),
        XRoot(:final index, :final rad) =>
          XRoot(index == null ? null : _rw(index), _rw(rad)),
        XAbs(:final a) => XAbs(_rw(a)),
        XFact(:final a) => XFact(_rw(a)),
        XComb(n: final top, r: final low, :final perm) => XComb(_rw(top), _rw(low), perm),
        XFn(:final name, :final arg, :final base) =>
          _fn(XFn(name, _rw(arg), base: base == null ? null : _rw(base))),
        _ => n,
      };

  // ---- sumas: sin^2 + cos^2 y cosh^2 - sinh^2 -----------------------------

  static List<(bool, XNode)> _terms(XNode n) => n is XBin && (n.op == '+' || n.op == '-')
      ? [..._terms(n.l), (n.op == '+', n.r)]
      : [(true, n)];

  static XNode _rebuild(List<(bool, XNode)> t) {
    var acc = t.first.$2;
    for (final e in t.skip(1)) {
      acc = XBin(acc, e.$1 ? '+' : '-', e.$2);
    }
    return acc;
  }

  /// `fn(a)^2` -> `a` como LaTeX, o `null` si [n] no es ese cuadrado.
  static String? _squareOf(XNode n, String fn) {
    if (n is! XPow) return null;
    final e = n.exp;
    final b = n.base;
    if (e is! XNum || e.value != Rational(2)) return null;
    if (b is! XFn || b.name != fn || b.base != null) return null;
    return b.arg.latex();
  }

  XNode _sum(XNode node) {
    if (node is! XBin || (node.op != '+' && node.op != '-')) return node;
    var terms = _terms(node);
    var changed = false;
    for (var i = 0; i < terms.length; i++) {
      for (var j = 0; j < terms.length; j++) {
        if (i == j) continue;
        final (si, a) = terms[i];
        final (sj, b) = terms[j];
        final pythagoras = si && sj && i < j && _same(a, 'sin', b, 'cos');
        final hyperbolic = si && !sj && _same(a, 'cosh', b, 'sinh');
        if (!pythagoras && !hyperbolic) continue;
        final before = XBin(a, hyperbolic ? '-' : '+', b);
        _log(
          before,
          XNum(Rational(1)),
          'Identidad fundamental',
          pythagoras
              ? 'Identidad pitagórica: sen²(a) + cos²(a) = 1 para cualquier ángulo a.'
              : 'Identidad hiperbólica: cosh²(a) - sinh²(a) = 1 para cualquier valor real a.',
        );
        terms = [
          for (var k = 0; k < terms.length; k++)
            if (k == i) (true, XNum(Rational(1))) else if (k != j) terms[k],
        ];
        changed = true;
        break;
      }
      if (changed) break;
    }
    return changed ? _sum(_rebuild(terms)) : node;
  }

  /// `a = f(t)^2` y `b = g(t)^2` con el mismo argumento `t`. Para la identidad
  /// pitagorica se prueba tambien el orden inverso en la llamada.
  static bool _same(XNode a, String f, XNode b, String g) {
    final x = _squareOf(a, f);
    final y = _squareOf(b, g);
    if (x != null && y != null && x == y) return true;
    if (f != 'sin') return false;
    final x2 = _squareOf(a, g);
    final y2 = _squareOf(b, f);
    return x2 != null && y2 != null && x2 == y2;
  }

  // ---- e^{ln a} = a ----------------------------------------------------------

  XNode _expLn(XNode node) {
    if (node is! XPow) return node;
    final b = node.base;
    final e = node.exp;
    if (b is! XConst || b.kind != 'e' || e is! XFn || e.name != 'ln') return node;
    final a = e.arg;
    if (a is XNum && (a.value.isNegative || a.value.isZero)) return node;
    _log(node, e.arg, 'Identidad fundamental',
        'e elevado a ln(a) es a, porque exponencial y logaritmo neperiano son funciones inversas (para a > 0).');
    return e.arg;
  }

  // ---- ln(e^a) = a y composiciones con inversas trigonometricas -------------------

  XNode _fn(XFn f) {
    final arg = f.arg;
    if (f.name == 'ln') {
      if (arg is XPow && arg.base is XConst && (arg.base as XConst).kind == 'e') {
        _log(f, arg.exp, 'Identidad fundamental',
            'ln(e^a) = a, porque el logaritmo neperiano deshace la exponencial de base e.');
        return arg.exp;
      }
      if (arg is XConst && arg.kind == 'e') {
        final one = XNum(Rational(1));
        _log(f, one, 'Identidad fundamental', 'ln(e) = 1.');
        return one;
      }
      return f;
    }
    const pairs = {'asin': 'sin', 'acos': 'cos', 'atan': 'tan'};
    final inner = pairs[f.name];
    if (inner == null || arg is! XFn || arg.name != inner) return f;
    if (!_inPrincipalRange(f.name, arg.arg)) return f;
    _log(f, arg.arg, 'Identidad fundamental',
        'La función inversa deshace a la directa cuando el ángulo está en su rango principal (arcsen y arctan en [-90°, 90°], arccos en [0°, 180°]).');
    return arg.arg;
  }

  bool _inPrincipalRange(String inverse, XNode t) {
    if (_hasVar(t)) return false;
    final double v;
    try {
      v = ExtEvaluator(angle: angle).eval(t).approx;
    } on Object {
      return false;
    }
    final rad = switch (angle) {
      AngleUnit.deg => v * math.pi / 180,
      AngleUnit.grad => v * math.pi / 200,
      AngleUnit.rad => v,
    };
    const eps = 1e-12;
    return switch (inverse) {
      'acos' => rad >= -eps && rad <= math.pi + eps,
      'atan' => rad > -math.pi / 2 + eps && rad < math.pi / 2 - eps,
      _ => rad >= -math.pi / 2 - eps && rad <= math.pi / 2 + eps,
    };
  }

  static bool _hasVar(XNode n) => switch (n) {
        XVar() => true,
        XNeg(:final a) || XAbs(:final a) || XFact(:final a) => _hasVar(a),
        XBin(:final l, :final r) => _hasVar(l) || _hasVar(r),
        XPow(:final base, :final exp) => _hasVar(base) || _hasVar(exp),
        XRoot(:final index, :final rad) => (index != null && _hasVar(index)) || _hasVar(rad),
        XComb(n: final top, r: final low) => _hasVar(top) || _hasVar(low),
        XFn(:final arg, :final base) => _hasVar(arg) || (base != null && _hasVar(base)),
        _ => false,
      };
}
