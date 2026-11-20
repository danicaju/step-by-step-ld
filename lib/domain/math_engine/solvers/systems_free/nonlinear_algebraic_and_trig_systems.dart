import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../exact/ext_expr.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import 'dpoly.dart';
import 'nd_common.dart';
import 'nonlinear_cascade.dart';

/// Sistemas N x N algebraicos (tambien con constantes trascendentes como `log(5)·sin(5)`):
/// se llevan a polinomios (cambio `a = raiz de x` para radicales acoplados, o aislando una raiz
/// y elevando al cuadrado) y se resuelven por sustitucion en cascada con comprobacion final.
abstract final class NonlinearAlgebraicSystems {
  static bool _isSqrt(XRoot r) => r.index == null || (r.index is XNum && (r.index as XNum).value == Rational(2));

  static Set<int> _sqrtVars(XNode n) {
    final s = <int>{};
    InequalityFamilyDetector.walk(n, (v) {
      if (v is XRoot && _isSqrt(v) && v.rad is XVar) {
        final i = NdSystem.vars.indexOf((v.rad as XVar).name);
        if (i >= 0) s.add(i);
      }
    });
    return s;
  }

  static XNode _tr(XNode n, Set<int> sq) {
    switch (n) {
      case XRoot r when _isSqrt(r) && r.rad is XVar && sq.contains(NdSystem.vars.indexOf((r.rad as XVar).name)):
        return r.rad;
      case XVar(:final name):
        return sq.contains(NdSystem.vars.indexOf(name)) ? XPow(n, XNum(Rational(2))) : n;
      case XNeg(:final a):
        return XNeg(_tr(a, sq));
      case XBin(:final l, :final op, :final r):
        return XBin(_tr(l, sq), op, _tr(r, sq));
      case XPow(:final base, :final exp):
        return XPow(_tr(base, sq), _tr(exp, sq));
      case XRoot(:final index, :final rad):
        return XRoot(index, _tr(rad, sq));
      case XAbs(:final a):
        return XAbs(_tr(a, sq));
      case XFn(:final name, :final arg, :final base):
        return XFn(name, _tr(arg, sq), base: base);
      default:
        return n;
    }
  }

  /// `P - R²` si la ecuacion es `sqrt(P) = R` (o al reves) con P y R polinomios.
  static DPoly? _isolateRoot(XNode l, XNode r, NdSystem sys) {
    for (final (a, b) in [(l, r), (r, l)]) {
      if (a is XRoot && _isSqrt(a)) {
        final p = DPoly.fromNode(a.rad, sys.unit), q = DPoly.fromNode(b, sys.unit);
        if (p != null && q != null) return p - q * q;
      }
    }
    return null;
  }

  static StepByStepResolution? solve(NdSystem sys) {
    final n = sys.n;
    final sq = <int>{};
    for (final (l, r) in sys.sides) {
      sq
        ..addAll(_sqrtVars(l))
        ..addAll(_sqrtVars(r));
    }
    final sides = [for (final (l, r) in sys.sides) (_tr(l, sq), _tr(r, sq))];
    final eqs = <CascadeEq>[];
    var squared = false;
    var anyPoly = false;
    var transcendental = false;
    for (var i = 0; i < n; i++) {
      final (l, r) = sides[i];
      final diff = XBin(l, '-', r);
      transcendental = transcendental || DPoly.isTranscendentalConst(sys.sides[i].$1) || DPoly.isTranscendentalConst(sys.sides[i].$2);
      var p = DPoly.fromNode(diff, sys.unit);
      if (p == null) {
        p = _isolateRoot(l, r, sys);
        if (p != null) squared = true;
      }
      if (p != null) {
        anyPoly = true;
        eqs.add(CascadeEq.poly(p));
      } else {
        eqs.add(CascadeEq.ast(diff));
      }
    }
    if (!anyPoly) return null;
    // Sin nada que reducir (todo lineal con coeficientes racionales) lo resuelve el motor exacto.
    final steps = <MathStep>[];
    if (sq.isNotEmpty) {
      steps.add(NdFmt.step(
        'Cambio de variable en los radicales',
        NdFmt.cases([for (final v in sq) '${NdSystem.names[v]} = a_{${v + 1}}^{2} \\quad (a_{${v + 1}} \\ge 0)']),
        'Llamamos a a la raíz de cada incógnita bajo el radical. Así desaparecen las raíces y el sistema pasa a ser polinómico en a, que debe ser mayor o igual que 0.',
      ));
    }
    if (squared) {
      steps.add(NdFmt.step(
        'Aislar la raíz y elevar al cuadrado',
        NdFmt.cases([for (final e in eqs) if (e.p != null) '${e.p!.latex()} = 0']),
        'Dejamos la raíz sola en un miembro y elevamos al cuadrado ambos miembros. Esto puede introducir soluciones falsas: se comprueban al final.',
        'Elevar al cuadrado no es una equivalencia: comprueba siempre las soluciones en el sistema original.',
      ));
    }
    if (transcendental) {
      steps.add(NdFmt.step(
        'Evaluar las constantes',
        NdFmt.cases([for (final e in eqs) if (e.p != null) '${e.p!.latex()} = 0']),
        'Calculamos primero las partes que solo llevan números (logaritmos, senos, raíces...) respetando la unidad angular. Así cada ecuación queda con coeficientes numéricos.',
      ));
    } else if (sq.isEmpty && !squared) {
      steps.add(NdFmt.step(
        'Escribir el sistema como polinomios',
        NdFmt.cases([for (final e in eqs) if (e.p != null) '${e.p!.latex()} = 0']),
        'Pasamos todo al primer miembro de cada ecuación para ver el grado y elegir cómo reducir el sistema.',
      ));
    }
    final found = NonlinearCascade(sys).run(eqs, steps);
    if (found == null) return null;

    final cands = <List<double>>[];
    var negRoot = 0;
    for (final s in found) {
      final v = [...s];
      var ok = true;
      for (final i in sq) {
        if (v[i] < -1e-9) {
          ok = false;
          negRoot++;
        } else {
          v[i] = v[i] * v[i];
        }
      }
      if (ok) cands.add(v);
    }
    final valid = NdFmt.dedupe([
      for (final c in cands)
        if (sys.satisfies(c)) c,
    ]);
    final dropped = cands.length - valid.length + negRoot;
    steps.add(NdFmt.step(
      'Comprobar en el sistema original',
      valid.isEmpty
          ? r'\text{Sin solucion real}'
          : NdFmt.cases([for (final s in valid) '${NdFmt.point(s, n, decimal: !s.take(n).every(NdFmt.isExact))} \\;\\text{valida}']),
      dropped > 0
          ? 'Sustituimos cada candidato en las ecuaciones originales y descartamos $dropped por no cumplirlas o por salirse del dominio (soluciones extrañas).'
          : 'Sustituimos cada candidato en las ecuaciones originales: todos las cumplen.',
    ));
    return NdFmt.finish(sys, steps, valid);
  }
}
