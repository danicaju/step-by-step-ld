import 'dart:math' as math;

import '../calculus/limit_models.dart';
import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/calculus/sym_latex.dart';
import '../solvers/equations/eq_poly.dart';
import '../solvers/exact/ext_expr.dart';
import '../solvers/symbolic_derivative_solver.dart';
import 'function_family.dart';

/// Estudio de pizarra de las trigonometricas inversas (arcsen, arccos, arctg) y las
/// hiperbolicas (senh, cosh, tgh), con la forma general `A * g(B x + C) + D`.
class InverseHyperbolicFamilyStudy {
  const InverseHyperbolicFamilyStudy._();

  static String _pt(String x, String y) => '\\left($x,\\,$y\\right)';
  static String _amp(Rational a) => a == Rational(1) ? '' : (a == Rational(-1) ? '-' : '${rl(a)}\\,');
  static String _shift(Rational d) => d.isZero ? '' : (d.isNegative ? ' - ${rl(d.abs())}' : ' + ${rl(d)}');
  static double _h(bool deg) => deg ? 90 : math.pi / 2;
  static double _toUnit(double rad, bool deg) => deg ? rad * 180 / math.pi : rad;
  static double _toRad(double v, bool deg) => deg ? v * math.pi / 180 : v;
  static double _x(FamilyInfo i, double u) => (u - i.c.toDouble()) / i.b.toDouble();
  static String _xl(FamilyInfo i, Rational u) => rl((u - i.c) / i.b);

  /// `D + t * h` como LaTeX exacto (h = pi/2 en RAD, 90 en DEG).
  static String yLatex(Rational t, Rational d, bool deg) {
    if (deg) return rl(d + t * Rational(90));
    final c = t / Rational(2);
    if (c.isZero) return rl(d);
    final pi = c == Rational(1) ? '\\pi' : (c == Rational(-1) ? '-\\pi' : '${rl(c)}\\pi');
    if (d.isZero) return pi;
    return d.isNegative ? '$pi - ${rl(d.abs())}' : '$pi + ${rl(d)}';
  }

  static double yValue(Rational t, Rational d, bool deg) => d.toDouble() + t.toDouble() * _h(deg);

  static int _sign(Rational r) => r.isNegative ? -1 : 1;

  static String _fnLatex(FunctionFamily f) => switch (f) {
        FunctionFamily.arcSine => '\\arcsin',
        FunctionFamily.arcCosine => '\\arccos',
        FunctionFamily.arcTangent => '\\arctan',
        FunctionFamily.hypSine => '\\sinh',
        FunctionFamily.hypCosine => '\\cosh',
        _ => '\\tanh',
      };

  /// Asintotas horizontales exactas de arctg (+-pi/2 o +-90) y tgh (+-1).
  static AsymptoteSet asymptotes(FamilyInfo i, {bool deg = false}) {
    final a = i.a, d = i.d;
    final s = Rational(_sign(i.b));
    switch (i.family) {
      case FunctionFamily.arcTangent:
        final hi = a * s, lo = -(a * s);
        return AsymptoteSet(horizontal: [
          Asymptote.line('y = ${yLatex(hi, d, deg)}', 0, yValue(hi, d, deg)),
          Asymptote.line('y = ${yLatex(lo, d, deg)}', 0, yValue(lo, d, deg)),
        ]);
      case FunctionFamily.hypTangent:
        return AsymptoteSet(horizontal: [
          Asymptote.line('y = ${rl(d + a * s)}', 0, (d + a * s).toDouble()),
          Asymptote.line('y = ${rl(d - a * s)}', 0, (d - a * s).toDouble()),
        ]);
      default:
        return AsymptoteSet.empty;
    }
  }

  static List<MathStep> study(FamilyInfo i, XNode node, {bool deg = false}) {
    final fam = i.family;
    if (fam.isInverseTrig) return _inverse(i, node, deg);
    return _hyperbolic(i, node);
  }

  static MathStep? _derivative(XNode node, String note) {
    try {
      final d = SymbolicDerivativeSolver.differentiate(node).derivative;
      return fstep('Derivada', "f'(x) = ${SymLatex.tex(d)}", note);
    } on FormatException {
      return null;
    } on ExtUnsupported {
      return null;
    }
  }

  // ------------------------------------------------------ trigonometricas inversas

  static List<MathStep> _inverse(FamilyInfo i, XNode node, bool deg) {
    final a = i.a, b = i.b, c = i.c, d = i.d;
    final fam = i.family;
    final arg = PolyOps.latex(i.inner);
    final fn = _fnLatex(fam);
    final unitNote = deg ? 'Calculadora en DEG: la función devuelve grados.' : 'Calculadora en RAD: la función devuelve radianes.';
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${_amp(a)}$fn\\left($arg\\right)${_shift(d)}',
          'Función trigonométrica inversa de la forma A·g(Bx + C) + D. $unitNote'),
    ];
    final incBase = fam != FunctionFamily.arcCosine;
    final inc = (a.isNegative == b.isNegative) == incBase;
    final monoWord = inc ? 'estrictamente creciente' : 'estrictamente decreciente';
    if (fam == FunctionFamily.arcTangent) {
      final lo = -a.abs(), hi = a.abs();
      steps
        ..add(fstep(
            'Dominio e imagen',
            '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\left(${yLatex(lo, d, deg)},\\,${yLatex(hi, d, deg)}\\right)',
            'El arco tangente está definido para todo número real y su valor queda siempre dentro de un intervalo abierto de longitud ${deg ? '180 grados' : 'π'} por |A|.'))
        ..add(fstep(
            'Asíntotas horizontales',
            'x \\to +\\infty:\\; y = ${yLatex(a * Rational(_sign(b)), d, deg)},\\quad x \\to -\\infty:\\; y = ${yLatex(-(a * Rational(_sign(b))), d, deg)}',
            'Cuando el argumento tiende a infinito, arctan se acerca a ${deg ? '90' : 'π/2'} sin llegar a alcanzarlo. No tiene asíntotas verticales.'));
      final dv = deg ? null : _derivative(node, 'La derivada es siempre del mismo signo, así que la función es $monoWord en todo ℝ.');
      steps.add(dv ?? fstep('Monotonía', '\\text{$monoWord}', 'La derivada no cambia de signo, así que la función es $monoWord.'));
      final y0 = a.toDouble() * _toUnit(math.atan(c.toDouble()), deg) + d.toDouble();
      steps.add(fstep('Corte con el eje OY', 'f(0) ${feq(y0)} \\implies ${_pt('0', fapx(y0))}', 'Evaluamos en x = 0.'));
      final target = _toRad(-d.toDouble() / a.toDouble(), deg);
      if (target.abs() < math.pi / 2 - 1e-12) {
        final xr = _x(i, math.tan(target));
        steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies x ${feq(xr)}',
            'Despejamos arctan($arg) = ${fdec(-d.toDouble() / a.toDouble())} y aplicamos la tangente.'));
      } else {
        steps.add(fstep('Corte con el eje OX', '\\text{sin cortes}',
            'La imagen no contiene el valor 0, así que la curva no corta al eje OX.'));
      }
      return steps;
    }
    final isSin = fam == FunctionFamily.arcSine;
    final x1 = (Rational(-1) - c) / b, x2 = (Rational(1) - c) / b;
    final lowFirst = x1.toDouble() < x2.toDouble();
    final xLo = lowFirst ? x1 : x2, xHi = lowFirst ? x2 : x1;
    // Unidades de h: arcsen en [-1, 1]; arccos en [0, 2].
    final (kLo, kHi) = isSin ? (Rational(-1), Rational(1)) : (Rational(0), Rational(2));
    final tA = a * kLo, tB = a * kHi;
    final yA = yValue(tA, d, deg), yB = yValue(tB, d, deg);
    final (tMin, tMax) = yA <= yB ? (tA, tB) : (tB, tA);
    steps
      ..add(fstep(
          'Condición de existencia',
          '-1 \\leq $arg \\leq 1 \\implies x \\in \\left[${rl(xLo)},\\,${rl(xHi)}\\right]',
          'arcsen y arccos solo existen si su argumento está entre -1 y 1. Despejamos x para hallar el dominio.'))
      ..add(fstep(
          'Dominio e imagen',
          '\\text{Dom}(f) = \\left[${rl(xLo)},\\,${rl(xHi)}\\right],\\quad \\text{Im}(f) = \\left[${yLatex(tMin, d, deg)},\\,${yLatex(tMax, d, deg)}\\right]',
          'La imagen de ${isSin ? 'arcsen' : 'arccos'} es ${isSin ? (deg ? '[-90, 90]' : '[-π/2, π/2]') : (deg ? '[0, 180]' : '[0, π]')}; la amplitud A y el desplazamiento D la escalan y la mueven.'))
      ..add(fstep(
          'Extremos del dominio',
          '${_pt(_xl(i, Rational(-1)), yLatex(tA, d, deg))},\\quad ${_pt(_xl(i, Rational(1)), yLatex(tB, d, deg))}',
          'Sustituimos los valores -1 y 1 del argumento: son los puntos donde empieza y termina la curva. No se dibuja nada fuera del dominio.'));
    final dv = deg ? null : _derivative(node, 'La derivada tiene signo constante en el interior del dominio: la función es $monoWord.');
    steps.add(dv ?? fstep('Monotonía', '\\text{$monoWord}', 'La derivada tiene signo constante en el interior del dominio: la función es $monoWord.'));
    if (c.toDouble().abs() <= 1) {
      final base = isSin ? math.asin(c.toDouble()) : math.acos(c.toDouble());
      final y0 = a.toDouble() * _toUnit(base, deg) + d.toDouble();
      steps.add(fstep('Corte con el eje OY', 'f(0) ${feq(y0)} \\implies ${_pt('0', fapx(y0))}', 'Evaluamos en x = 0, que pertenece al dominio.'));
    } else {
      steps.add(fstep('Corte con el eje OY', '0 \\notin \\text{Dom}(f) \\implies \\text{sin corte}', 'x = 0 queda fuera del dominio.'));
    }
    final t = -d.toDouble() / a.toDouble();
    final tr = _toRad(t, deg);
    final inRange = isSin ? tr.abs() <= math.pi / 2 + 1e-12 : (tr >= -1e-12 && tr <= math.pi + 1e-12);
    if (inRange) {
      final u = isSin ? math.sin(tr) : math.cos(tr);
      steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies x ${feq(_x(i, u))}',
          'Despejamos ${isSin ? 'arcsen' : 'arccos'}($arg) = ${fdec(t)} y aplicamos ${isSin ? 'el seno' : 'el coseno'}.'));
    } else {
      steps.add(fstep('Corte con el eje OX', '\\text{sin cortes}', 'El valor ${fdec(t)} queda fuera de la imagen de ${isSin ? 'arcsen' : 'arccos'}.'));
    }
    steps.add(fstep('Asíntotas', '\\text{sin asintotas}', 'La función está definida en un intervalo cerrado y acotado: no hay asíntotas.'));
    return steps;
  }

  // ------------------------------------------------------------------ hiperbolicas

  static List<MathStep> _hyperbolic(FamilyInfo i, XNode node) {
    final a = i.a, b = i.b, c = i.c, d = i.d;
    final fam = i.family;
    final arg = PolyOps.latex(i.inner);
    final fn = _fnLatex(fam);
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${_amp(a)}$fn\\left($arg\\right)${_shift(d)}',
          'Función hiperbólica de la forma A·g(Bx + C) + D. Se definen con exponenciales: senh x = (eˣ - e⁻ˣ)/2, cosh x = (eˣ + e⁻ˣ)/2.'),
    ];
    final plainSym = c.isZero && d.isZero;
    final k = -d.toDouble() / a.toDouble();
    final x0 = -c / b;
    if (fam == FunctionFamily.hypCosine) {
      final minimum = a.isPositive;
      final vy = a + d;
      steps
        ..add(fstep(
            'Dominio e imagen',
            '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = ${minimum ? '\\left[${rl(vy)},\\,+\\infty\\right)' : '\\left(-\\infty,\\,${rl(vy)}\\right]'}',
            'cosh x vale al menos 1 y no tiene máximo; A y D escalan y mueven ese intervalo.'))
        ..add(fstep(
            'Paridad',
            c.isZero ? 'f(-x) = f(x) \\implies \\text{funcion par}' : '\\text{sin paridad definida}',
            c.isZero ? 'cosh es una función par: su gráfica es simétrica respecto del eje OY.' : 'El desplazamiento C rompe la simetría respecto del eje OY (es simétrica respecto de x = ${rl(x0)}).'))
        ..add(fstep(
            minimum ? 'Mínimo' : 'Máximo',
            '${minimum ? '\\text{min}' : '\\text{Max}'}${_pt(rl(x0), rl(vy))}',
            'En u = 0 el cosh alcanza su valor 1, así que ${minimum ? 'el mínimo' : 'el máximo'} está en x = ${rl(x0)} con valor ${rl(vy)}.'));
      final dv = _derivative(node, minimum ? 'La derivada se anula en x = ${rl(x0)}: la función baja antes y sube después.' : 'La derivada se anula en x = ${rl(x0)}: la función sube antes y baja después.');
      if (dv != null) steps.add(dv);
      steps.add(fstep('Monotonía', minimum ? '\\text{decreciente en } (-\\infty,\\,${rl(x0)}),\\; \\text{creciente en } (${rl(x0)},\\,+\\infty)' : '\\text{creciente en } (-\\infty,\\,${rl(x0)}),\\; \\text{decreciente en } (${rl(x0)},\\,+\\infty)',
          'El signo de la derivada cambia en el vértice x = ${rl(x0)}.'));
      final y0 = a.toDouble() * (math.exp(c.toDouble()) + math.exp(-c.toDouble())) / 2 + d.toDouble();
      steps.add(fstep('Corte con el eje OY', 'f(0) ${feq(y0)} \\implies ${_pt('0', fapx(y0))}', 'Evaluamos en x = 0.'));
      if (k < 1 - 1e-12) {
        steps.add(fstep('Corte con el eje OX', '\\text{sin cortes}', 'Habría que tener cosh($arg) = ${fdec(k)}, y cosh nunca baja de 1.'));
      } else if ((k - 1).abs() <= 1e-12) {
        steps.add(fstep('Corte con el eje OX', 'x = ${rl(x0)}', 'cosh($arg) = 1 solo se cumple cuando el argumento vale 0.'));
      } else {
        final u = math.log(k + math.sqrt(k * k - 1));
        steps.add(fstep('Cortes con el eje OX', 'x_{1} ${feq(_x(i, -u))},\\quad x_{2} ${feq(_x(i, u))}',
            'cosh($arg) = ${fdec(k)} tiene dos soluciones simétricas: argumento = ± ln(k + √(k² - 1)).'));
      }
      steps.add(fstep('Asíntotas', '\\text{sin asintotas}', 'cosh crece sin cota (de forma exponencial), así que no hay asíntotas horizontales; tampoco verticales.'));
      return steps;
    }
    final isSinh = fam == FunctionFamily.hypSine;
    final inc = !(a.isNegative != b.isNegative);
    final monoWord = inc ? 'estrictamente creciente' : 'estrictamente decreciente';
    if (isSinh) {
      steps.add(fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\mathbb{R}', 'senh toma todos los valores reales y está definido para todo x.'));
    } else {
      steps.add(fstep(
          'Dominio e imagen',
          '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = \\left(${rl(d - a.abs())},\\,${rl(d + a.abs())}\\right)',
          'tgh x queda siempre entre -1 y 1 sin tocar esos valores; A y D escalan y mueven el intervalo.'));
    }
    steps.add(fstep(
        'Paridad',
        plainSym ? 'f(-x) = -f(x) \\implies \\text{funcion impar}' : '\\text{sin paridad definida}',
        plainSym ? '${isSinh ? 'senh' : 'tgh'} es una función impar: su gráfica es simétrica respecto del origen.' : 'C y D desplazan la gráfica y rompen la simetría respecto del origen.'));
    final dv = _derivative(node, 'La derivada es siempre del mismo signo, así que la función es $monoWord en todo ℝ.');
    steps.add(dv ?? fstep('Monotonía', '\\text{$monoWord}', 'La derivada no cambia de signo.'));
    final y0 = a.toDouble() * (isSinh ? (math.exp(c.toDouble()) - math.exp(-c.toDouble())) / 2 : _tanh(c.toDouble())) + d.toDouble();
    steps.add(fstep('Corte con el eje OY', 'f(0) ${feq(y0)} \\implies ${_pt('0', fapx(y0))}', 'Evaluamos en x = 0.'));
    if (isSinh) {
      final u = math.log(k + math.sqrt(k * k + 1));
      steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies x ${feq(_x(i, u))}',
          'Despejamos senh($arg) = ${fdec(k)} y aplicamos argsenh: u = ln(k + √(k² + 1)).'));
      steps.add(fstep('Asíntotas', '\\text{sin asintotas}', 'senh crece sin cota en ambos sentidos: no tiene asíntotas.'));
    } else {
      if (k.abs() < 1 - 1e-12) {
        final u = 0.5 * math.log((1 + k) / (1 - k));
        steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies x ${feq(_x(i, u))}',
            'Despejamos tgh($arg) = ${fdec(k)}, que exige |k| < 1, y aplicamos u = ½·ln((1 + k)/(1 - k)).'));
      } else {
        steps.add(fstep('Corte con el eje OX', '\\text{sin cortes}', 'El valor ${fdec(k)} queda fuera de la imagen (-1, 1) de tgh.'));
      }
      final s = Rational(_sign(b));
      steps.add(fstep('Asíntotas horizontales', 'y = ${rl(d + a * s)}\\quad (x \\to +\\infty),\\qquad y = ${rl(d - a * s)}\\quad (x \\to -\\infty)',
          'Cuando el argumento tiende a ±infinito, tgh se acerca a ±1. No tiene asíntotas verticales.'));
    }
    return steps;
  }

  static double _tanh(double v) {
    final e = math.exp(2 * v);
    return v > 20 ? 1 : (v < -20 ? -1 : (e - 1) / (e + 1));
  }
}
