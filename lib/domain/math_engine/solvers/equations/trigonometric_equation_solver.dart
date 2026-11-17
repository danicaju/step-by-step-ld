import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_trig.dart';
import '../trig_and_angles_solver.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Ecuaciones trigonometricas basicas sin(a x + b) = k, cos(..) = k, tan(..) = k
/// (tambien cuadraticas en la razon) con soluciones principales en DEG / RAD / GRA.
class TrigonometricEquationSolver {
  const TrigonometricEquationSolver._();

  static const _names = {'sin', 'cos', 'tan'};

  static bool matches(EqCtx c) =>
      _find(c.left) != null || _find(c.right) != null;

  static XFn? _find(XNode n) {
    switch (n) {
      case XFn():
        return _names.contains(n.name) && PolyOps.containsX(n.arg) ? n : null;
      case XNeg(:final a) || XAbs(:final a):
        return _find(a);
      case XBin(:final l, :final r):
        return _find(l) ?? _find(r);
      case XPow(:final base, :final exp):
        return _find(base) ?? _find(exp);
      default:
        return null;
    }
  }

  static ExNum _full(AngleUnit u) => switch (u) {
        AngleUnit.deg => ExNum.integer(360),
        AngleUnit.rad => ExNum.integer(2) * ExNum.pi(),
        AngleUnit.grad => ExNum.integer(400),
      };

  static ExNum _half(AngleUnit u) => ExNum.rational(Rational(1, 2)) * _full(u);

  static String _unit(AngleUnit u) => u == AngleUnit.deg ? '^\\circ' : '';

  static String _ang(ExNum v, AngleUnit u) {
    final t = v.toLatex();
    final suffix = _unit(u);
    if (suffix.isEmpty) return t;
    return v.isExact && v.terms.length > 1 ? '\\left($t\\right)$suffix' : '$t$suffix';
  }

  static ExNum _norm(ExNum a, AngleUnit u) {
    var v = a;
    final full = _full(u);
    var guard = 0;
    while (v.approx < -1e-12 && guard++ < 8) {
      v = v + full;
    }
    while (v.approx >= full.approx - 1e-12 && guard++ < 16) {
      v = v - full;
    }
    return v;
  }

  static StepByStepResolution? solve(EqCtx c) {
    final target = _find(c.left) ?? _find(c.right);
    if (target == null) return null;
    final key = target.latex();
    bool isS(XNode n) => n is XFn && n.latex() == key;
    final dl = PolyOps.polyOf(c.left, isVar: isS);
    final dr = PolyOps.polyOf(c.right, isVar: isS);
    if (dl == null || dr == null) return null;
    final p = PolyOps.sub(dl, dr);
    final argPoly = PolyOps.polyOf(target.arg);
    if (argPoly == null || PolyOps.degree(argPoly) != 1) return null;
    final m = PolyOps.coeff(argPoly, 1);
    final n = PolyOps.coeff(argPoly, 0);
    final u = c.angle;
    final fn = target.name;

    if (PolyOps.degree(p) < 1) return null;
    c.add(
      'Despejar la razon trigonometrica',
      '\\theta = ${PolyOps.latex(argPoly)} \\implies ${PolyOps.latex(p, v: '\\$fn(\\theta)')} = 0',
      'Llamamos θ al ángulo y tratamos $fn(θ) como una incógnita auxiliar que hay que despejar.',
    );
    final ratios = PolyRoots.real(p);
    if (PolyOps.degree(p) >= 2) {
      c.addPolynomialSolveStep(p, ratios, title: 'Resolver en la razon trigonometrica');
    } else {
      c.add('Valor de la razon',
          ratios.map((r) => '\\$fn = ${r.toLatex()}').join(', \\; '),
          'Con la razón aislada buscamos los ángulos que la cumplen.');
    }

    final sols = <ExNum>[];
    final general = <String>[];
    final lines = <String>[];
    for (final k in ratios) {
      if (fn != 'tan' && k.approx.abs() > 1 + 1e-12) {
        lines.add('\\$fn = ${k.toLatex()}, \\; |${k.toLatex()}| > 1 \\implies \\text{Sin solucion real}');
        continue;
      }
      final inv = ExtTrig.inverse(switch (fn) {
        'sin' => 'asin',
        'cos' => 'acos',
        _ => 'atan',
      }, k, u);
      final t1 = _norm(inv, u);
      final t2 = _norm(
        switch (fn) {
          'sin' => _half(u) - inv,
          'cos' => _full(u) - inv,
          _ => inv + _half(u),
        },
        u,
      );
      final thetas =
          (fn == 'tan' || (t2.approx - t1.approx).abs() < 1e-9) ? [t1] : [t1, t2];
      lines.add('\\theta = ${thetas.map((t) => _ang(t, u)).join(', \\; ')}');
      for (final t in thetas) {
        var x = t;
        if (!n.isZero) x = x - ExNum.rational(n);
        if (m != Rational(1)) x = x / ExNum.rational(m);
        sols.add(x);
        var period = fn == 'tan' ? _half(u) : _full(u);
        if (m != Rational(1)) period = period / ExNum.rational(m);
        general.add('x = ${_ang(x, u)} + ${_ang(period, u)}\\,k');
      }
    }
    c.add(
      'Angulos principales (primera vuelta)',
      lines.isEmpty ? '\\text{Sin solucion real}' : lines.join(' \\\\ '),
      'Usamos la función inversa para el ángulo del primer cuadrante y la simetría de la circunferencia para el segundo ángulo solución (en ${_unitName(u)}).',
    );

    if (sols.isEmpty) {
      c.add('Conclusion', '\\text{Sin solucion real}',
          'El seno y el coseno solo toman valores entre -1 y 1.');
      return c.finish(const []);
    }
    final period = fn == 'tan' ? _half(u) : _full(u);
    c.add(
      'Soluciones generales',
      '${general.join(', \\quad ')}, \\quad k \\in \\mathbb{Z}',
      'Las funciones trigonométricas son periódicas (período ${_ang(period, u)}), por eso se suman múltiplos enteros del período.',
    );
    final exact = '${general.join(', \\quad ')}, \\quad k \\in \\mathbb{Z}';
    final decimal = sols
        .map((s) => 'x \\approx ${s.decimalLatex()}${_unit(u)}')
        .join(', \\quad ');
    return c.finish(sols, exactOverride: exact, decimalOverride: decimal);
  }

  static String _unitName(AngleUnit u) => switch (u) {
        AngleUnit.deg => 'grados',
        AngleUnit.rad => 'radianes',
        AngleUnit.grad => 'gradianes',
      };
}
