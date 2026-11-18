import 'dart:math' as math;

import '../core/rational.dart';
import '../models/step_resolution.dart';
import '../solvers/equations/eq_poly.dart';
import 'angle_format.dart';
import 'function_family.dart';

/// Estudio de pizarra de exponenciales, logaritmos y funciones trigonometricas.
///
/// Forma general `A * g(B x + C) + D`. En `\text{}` solo ASCII.
class ExpLogTrigFamilyStudy {
  const ExpLogTrigFamilyStudy._();

  static String _pt(String x, String y) => '\\left($x,\\,$y\\right)';
  static String _dec(double v) => fdec(v);
  static String _amp(Rational a) => a == Rational(1) ? '' : (a == Rational(-1) ? '-' : '${rl(a)}\\,');
  static String _shift(Rational d) => d.isZero ? '' : (d.isNegative ? ' - ${rl(d.abs())}' : ' + ${rl(d)}');
  static double _lnBase(FamilyInfo i) => i.base == null ? 1 : math.log(i.base!);

  static List<MathStep> study(FamilyInfo i, {bool deg = false}) => switch (i.family) {
        FunctionFamily.exponential => _exp(i),
        FunctionFamily.logarithmic => _log(i),
        _ => _trig(i, deg),
      };

  // -------------------------------------------------------------- exponencial

  static List<MathStep> _exp(FamilyInfo i) {
    final a = i.a, b = i.b, c = i.c, d = i.d;
    final lb = _lnBase(i);
    final inc = a.toDouble() * b.toDouble() * lb > 0;
    final arg = PolyOps.latex(i.inner);
    final baseOk = i.base == null || (i.base! > 0 && i.base != 1);
    final x1 = -c / b;
    final target = -d.toDouble() / a.toDouble();
    return [
      fstep('Tipo de función', 'f(x) = ${_amp(a)}${i.baseLatex}^{$arg}${_shift(d)}',
          'Función exponencial: la variable está en el exponente. La base ${i.baseLatex} cumple a > 0 y a distinto de 1${baseOk ? '' : ''}.'),
      fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R},\\quad \\text{Im}(f) = ${a.isPositive ? '\\left(${rl(d)},\\,+\\infty\\right)' : '\\left(-\\infty,\\,${rl(d)}\\right)'}',
          'Una potencia de base positiva siempre es positiva; desplazada ${d.isZero ? 'sin cambios' : 'D = ${rl(d)} unidades'} en vertical.'),
      fstep('Monotonía', inc ? '\\text{estrictamente creciente}' : '\\text{estrictamente decreciente}',
          i.base == null || i.base! > 1
              ? (b.isPositive == a.isPositive ? 'Base mayor que 1 y signos positivos: la función crece.' : 'La función es decreciente por el signo de A o de B.')
              : 'Base entre 0 y 1: la función decrece (salvo que A o B cambien el signo).'),
      fstep('Asíntota horizontal', 'y_{AH} = ${rl(d)}\\quad (x \\to ${(inc ? -1 : 1) * (b.isNegative ? -1 : 1) < 0 ? '-' : '+'}\\infty)',
          'Cuando el exponente tiende a -infinito la potencia se acerca a 0 y f tiende a D = ${rl(d)}.'),
      fstep('Punto clave', 'x = ${rl(x1)} \\implies f = ${rl(a + d)} \\implies ${_pt(rl(x1), rl(a + d))}',
          'Si el exponente vale 0, la potencia vale 1. Para a^x el punto clave es (0, 1).'),
      fstep('Corte con el eje OY', 'f(0) ${feq(a.toDouble() * math.pow(i.base ?? math.e, c.toDouble()) + d.toDouble())} \\implies ${_pt('0', fapx(a.toDouble() * math.pow(i.base ?? math.e, c.toDouble()) + d.toDouble()))}',
          'Sustituimos x = 0.'),
      target > 0
          ? fstep('Corte con el eje OX', 'x ${feq((math.log(target) / lb - c.toDouble()) / b.toDouble())}',
              'Despejamos la potencia = ${_dec(target)} y tomamos logaritmos.')
          : fstep('Corte con el eje OX', '\\text{sin cortes}', 'La potencia es siempre positiva y nunca llega a ${_dec(target)}.'),
    ];
  }

  // -------------------------------------------------------------- logaritmica

  static List<MathStep> _log(FamilyInfo i) {
    final a = i.a, b = i.b, c = i.c, d = i.d;
    final lb = _lnBase(i);
    final inc = a.toDouble() * b.toDouble() * lb > 0;
    final x0 = -c / b;
    final arg = PolyOps.latex(i.inner);
    final fn = i.base == null ? '\\ln' : '\\log_{${i.baseLatex}}';
    final x1 = (Rational(1) - c) / b;
    final dom = b.isPositive ? '\\left(${rl(x0)},\\,+\\infty\\right)' : '\\left(-\\infty,\\,${rl(x0)}\\right)';
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${_amp(a)}$fn\\left($arg\\right)${_shift(d)}',
          'Función logarítmica: es la inversa de la exponencial de la misma base.'),
      fstep('Condición de existencia', '$arg > 0 \\implies x ${b.isPositive ? '>' : '<'} ${rl(x0)}', 'El argumento de un logaritmo debe ser estrictamente positivo.'),
      fstep('Dominio e imagen', '\\text{Dom}(f) = $dom,\\quad \\text{Im}(f) = \\mathbb{R}', 'Los logaritmos toman todos los valores reales.'),
      fstep('Asíntota vertical', 'x_{AV} = ${rl(x0)}', 'La curva se acerca a la recta donde el argumento vale 0 sin llegar a tocarla.'),
      fstep('Punto clave', 'arg = 1 \\implies x = ${rl(x1)} \\implies ${_pt(rl(x1), rl(d))}', 'Como log(1) = 0 en cualquier base, el punto clave de log_a(x) es (1, 0).'),
      fstep('Monotonía', inc ? '\\text{estrictamente creciente}' : '\\text{estrictamente decreciente}',
          inc ? 'Sube de forma lenta: crece sin cota pero cada vez más despacio.' : 'Baja: decrece (base menor que 1 o signo de A o B negativo).'),
    ];
    final y0 = c.isPositive ? a.toDouble() * math.log(c.toDouble()) / lb + d.toDouble() : null;
    steps.add(fstep('Corte con el eje OY', y0 == null ? '0 \\notin \\text{Dom}(f) \\implies \\text{sin corte}' : 'f(0) ${feq(y0)}', 'Evaluamos en x = 0 si está en el dominio.'));
    final xr = (math.pow(i.base ?? math.e, -d.toDouble() / a.toDouble()) - c.toDouble()) / b.toDouble();
    steps.add(fstep('Corte con el eje OX', 'f(x) = 0 \\implies $arg = ${i.baseLatex}^{${rl(-d / a)}} \\implies x ${feq(xr)}', 'Pasamos a forma exponencial para despejar x.'));
    return steps;
  }

  // ------------------------------------------------------------ trigonometria

  /// Abscisas `x = base + k T` (en la unidad activa) donde Bx + C = u (+ k turn).
  static double _xAt(FamilyInfo i, double u) => (u - i.c.toDouble()) / i.b.toDouble();

  static List<MathStep> _trig(FamilyInfo i, bool deg) {
    final a = i.a, b = i.b, c = i.c, d = i.d;
    final fam = i.family;
    final half = AngleFormat.turn(deg) / 2;
    final per = half / b.toDouble().abs() * (fam == FunctionFamily.tangent ? 1 : 2);
    final perTex = AngleFormat.latex(per, deg);
    final name = fam == FunctionFamily.sine ? '\\sin' : (fam == FunctionFamily.cosine ? '\\cos' : '\\tan');
    final arg = PolyOps.latex(i.inner);
    final amp = a.abs().toDouble();
    final unit = deg ? '^\\circ' : '';
    final steps = <MathStep>[
      fstep('Tipo de función', 'f(x) = ${_amp(a)}$name\\left($arg\\right)${_shift(d)}',
          'Función trigonométrica de la forma A·f(Bx + C) + D. ${deg ? 'Calculadora en DEG: ángulos en grados.' : 'Calculadora en RAD: ángulos en radianes.'}'),
    ];
    if (fam == FunctionFamily.tangent) {
      final x0 = _xAt(i, half / 2);
      steps
        ..add(fstep('Asíntotas verticales', '\\cos\\left($arg\\right) = 0 \\implies x_{AV} = ${AngleFormat.latex(x0, deg)} + k \\cdot ${AngleFormat.latex(per, deg)}',
            'La tangente es sen/cos y no existe donde cos = 0: en x = ${deg ? '90° + 180°k' : 'π/2 + kπ'} para tan x. Ahí hay asíntotas verticales (k entero).'))
        ..add(fstep('Dominio e imagen', '\\text{Dom}(f) = \\mathbb{R} \\setminus \\left\\{${AngleFormat.latex(x0, deg)} + k \\cdot ${AngleFormat.latex(per, deg)}\\right\\},\\quad \\text{Im}(f) = \\mathbb{R}',
            'Quitamos las asíntotas del dominio; la imagen son todos los reales.'))
        ..add(fstep('Período', 'T = ${deg ? '\\frac{180^\\circ}{|B|}' : '\\frac{\\pi}{|B|}'} = $perTex', 'La tangente repite su forma cada ${deg ? '180°' : 'π'} dividido por |B|.'));
      final xz = _xAt(i, math.atan(-d.toDouble() / a.toDouble()) * half / math.pi);
      steps
        ..add(fstep('Monotonía', a.toDouble() * b.toDouble() > 0 ? '\\text{creciente en cada rama}' : '\\text{decreciente en cada rama}', 'En cada intervalo entre dos asíntotas la función es monótona.'))
        ..add(fstep('Cortes con los ejes', 'x = ${xz.abs() < 1e-9 ? '' : '${AngleFormat.latex(xz, deg)} + '}k \\cdot $perTex;\\quad f(0) ${feq(a.toDouble() * math.tan(c.toDouble() * math.pi / half) + d.toDouble())}', 'Resolvemos tan(Bx + C) = -D/A para OX y evaluamos en x = 0 para OY.'));
      return steps;
    }
    final isSin = fam == FunctionFamily.sine;
    final maxU = isSin ? half / 2 : 0.0;
    final minU = isSin ? half * 1.5 : half;
    final top = a.isPositive ? maxU : minU;
    final bot = a.isPositive ? minU : maxU;
    final yHi = d.toDouble() + amp, yLo = d.toDouble() - amp;
    String ptsFor(double u, double y) => _pt(AngleFormat.latex(_xAt(i, u), deg), _dec(y));
    final dom = '\\text{Dom}(f) = \\mathbb{R}';
    final im = '\\text{Im}(f) = \\left[${_dec(yLo)},\\,${_dec(yHi)}\\right]';
    steps
      ..add(fstep('Dominio e imagen', '$dom,\\quad $im', 'El seno y el coseno están acotados entre -1 y 1; la amplitud |A| = ${rl(a.abs())} y el desplazamiento D = ${rl(d)} fijan la imagen.'))
      ..add(fstep('Período', 'T = ${deg ? '\\frac{360^\\circ}{|B|}' : '\\frac{2\\pi}{|B|}'} = $perTex', 'Con B = ${rl(b)} la gráfica se repite cada T. En un período aparece un ciclo completo.'));
    final s = -d.toDouble() / a.toDouble();
    if (s.abs() > 1 + 1e-12) {
      steps.add(fstep('Cortes con el eje OX', '\\text{sin cortes}', 'Habría que tener ${isSin ? 'sen' : 'cos'} = ${_dec(s)}, que está fuera de [-1, 1].'));
    } else {
      final base = isSin ? math.asin(s.clamp(-1.0, 1.0)) : math.acos(s.clamp(-1.0, 1.0));
      final u1 = base * half / math.pi;
      final u2 = isSin ? half - u1 : -u1;
      final pure = a.abs() == Rational(1) && c.isZero && d.isZero && b.abs() == Rational(1);
      final txt = pure
          ? (isSin ? 'x = k \\cdot ${AngleFormat.latex(half, deg)}' : 'x = ${AngleFormat.latex(half / 2, deg)} + k \\cdot ${AngleFormat.latex(half, deg)}')
          : 'x_{1} = ${AngleFormat.latex(_xAt(i, u1), deg)},\\; x_{2} = ${AngleFormat.latex(_xAt(i, u2), deg)} \\;(+ k \\cdot $perTex)';
      steps.add(fstep('Cortes con el eje OX', txt, 'Resolvemos ${isSin ? 'sen' : 'cos'}($arg) = ${_dec(s)} y sumamos períodos completos.'));
    }
    final y0 = a.toDouble() * (isSin ? math.sin(c.toDouble() * math.pi / half) : math.cos(c.toDouble() * math.pi / half)) + d.toDouble();
    steps
      ..add(fstep('Corte con el eje OY', 'f(0) ${feq(y0)} \\implies ${_pt('0', fapx(y0))}', 'Evaluamos en x = 0.'))
      ..add(fstep('Máximos y mínimos en un período', '\\text{Max}${ptsFor(top, yHi)},\\quad \\text{min}${ptsFor(bot, yLo)}',
          'Máximo ${_dec(yHi)} y mínimo ${_dec(yLo)}: sustituimos el ángulo donde ${isSin ? 'sen' : 'cos'} vale 1 (máx) y -1 (mín). ${unit.isEmpty ? '' : 'Valores en grados.'}'));
    return steps;
  }
}
