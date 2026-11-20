import 'dart:math' as math;

import '../../models/step_resolution.dart';
import '../calculus/sym_build.dart';
import '../calculus/sym_latex.dart';
import '../exact/exact_number.dart';
import '../exact/ext_expr.dart';
import 'eq_context.dart';
import 'eq_poly.dart';

/// Detecta identidades trigonometricas / hiperbolicas (siempre ciertas en su dominio)
/// y contradicciones (la diferencia de los miembros es una constante no nula).
///
/// Muestrea `izquierda - derecha` en varios puntos: si es constante, la ecuacion no
/// depende de x. En otro caso devuelve `null` y se usa el solver habitual.
class IdentityEquationSolver {
  const IdentityEquationSolver._();

  static const _fns = {'sin', 'cos', 'tan', 'sinh', 'cosh', 'tanh'};

  static bool _has(XNode n) => switch (n) {
        XFn() => (_fns.contains(n.name) && PolyOps.containsX(n.arg)) || _has(n.arg),
        XNeg(:final a) || XAbs(:final a) => _has(a),
        XBin(:final l, :final r) => _has(l) || _has(r),
        XPow(:final base, :final exp) => _has(base) || _has(exp),
        _ => false,
      };

  static bool matches(EqCtx c) => _has(c.left) || _has(c.right);

  static const _samples = [-2.9, -1.7, -0.83, -0.31, 0.27, 0.64, 1.13, 1.9, 2.6, 3.4];

  static String _identityTex(String diff) {
    final hyp = diff.contains('sinh') || diff.contains('cosh');
    if (hyp && diff.contains('cosh') && diff.contains('sinh')) {
      return '\\cosh^{2}(x) - \\sinh^{2}(x) = 1';
    }
    if (!hyp && diff.contains('sin') && diff.contains('cos')) {
      return '\\sin^{2}(x) + \\cos^{2}(x) = 1';
    }
    return 'f(x) - g(x) = 0';
  }

  static StepByStepResolution? solve(EqCtx c) {
    final vals = <double>[];
    for (final x in _samples) {
      final v = Sx.numAt(c.diff, x, angle: c.angle);
      if (v != null) vals.add(v);
    }
    if (vals.length < 5) return null;
    final first = vals.first;
    final scale = 1 + vals.map((v) => v.abs()).reduce(math.max);
    if (vals.any((v) => (v - first).abs() > 1e-9 * scale)) return null;
    final diffTex = SymLatex.tex(c.diff);
    c.add(
      'Pasar todo al primer miembro',
      '$diffTex = 0',
      'Restamos el segundo miembro al primero y estudiamos la expresión resultante.',
    );
    final isIdentity = first.abs() <= 1e-9 * scale;
    if (isIdentity) {
      c.add(
        'Reconocer la identidad',
        '${_identityTex(diffTex)} \\implies 0 = 0',
        'Al aplicar la identidad fundamental, la expresión vale 0 para todo x: los dos miembros son siempre iguales.',
      );
      return c.finish(
        const [],
        exactOverride: '\\text{Identidad: infinitas soluciones en el dominio}',
        decimalOverride: '\\text{Identidad: infinitas soluciones en el dominio}',
      );
    }
    final value = (first - first.roundToDouble()).abs() < 1e-9
        ? ExNum.integer(first.round()).toLatex()
        : ExNum.opaque('', first).decimalLatex();
    c.add(
      'Reconocer la contradiccion',
      '${_identityTex(diffTex)} \\implies $value = 0',
      'La expresión vale siempre lo mismo y nunca 0: es una contradicción, así que ningún valor de x cumple la ecuación.',
    );
    return c.finish(const []);
  }
}
