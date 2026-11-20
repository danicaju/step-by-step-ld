import 'dart:math' as math;

import '../arithmetic/casio_iberia_arsenal.dart';
import '../models/step_resolution.dart';

/// Una solucion completa: lados a, b, c y angulos A, B, C (grados), opuestos dos a dos.
class TriangleSolution {
  final List<double> sides; // a, b, c
  final List<double> angles; // A, B, C
  const TriangleSolution(this.sides, this.angles);
}

class TriangleResult {
  final List<TriangleSolution> solutions;
  final String kind; // pitagoras | trigonometria | coseno | seno | ambiguo
  final StepByStepResolution resolution;
  const TriangleResult(this.solutions, this.kind, this.resolution);
  bool get isAmbiguous => solutions.length > 1;
}

/// Resolucion de triangulos: rectangulos (Pitagoras y razones) y oblicuangulos (seno y coseno).
class TriangleSolver {
  const TriangleSolver._();

  static const _sn = ['a', 'b', 'c'];
  static const _an = ['A', 'B', 'C'];
  static const double _eps = 1e-9;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  static String n(double v, [int d = 4]) => v.toStringAsFixed(d).replaceAll('.', '{,}');
  static String ang(double v) => '${n(v, 2)}^{\\circ}';

  static void _s(List<MathStep> l, String t, String latex, String note, {String? trick}) => l.add(
        MathStep(index: l.length + 1, shortTitle: t, latexExpression: latex, pedagogicalNote: note, warningTrick: trick),
      );

  /// Resuelve con exactamente tres datos (al menos un lado). Angulos en grados.
  static TriangleResult solve({List<double?> sides = const [null, null, null], List<double?> angles = const [null, null, null]}) {
    final s = [...sides], a = [...angles];
    final ns = s.whereType<double>().length, na = a.whereType<double>().length;
    if (s.any((v) => v != null && v <= 0) || a.any((v) => v != null && v <= 0)) {
      throw const ArsenalException('Math ERROR: Lados y ángulos deben ser positivos.');
    }
    if (a.any((v) => v != null && v >= 180)) throw const ArsenalException('Math ERROR: Un ángulo debe ser menor que 180°.');
    if (ns == 0) throw const ArsenalException('Sintaxis incompleta: Se necesita al menos un lado.');
    if (ns + na != 3) throw const ArsenalException('Sintaxis incompleta: Introduce exactamente 3 datos.');
    final steps = <MathStep>[];
    final given = [
      for (var i = 0; i < 3; i++)
        if (s[i] != null) '${_sn[i]} = ${n(s[i]!)}',
      for (var i = 0; i < 3; i++)
        if (a[i] != null) '${_an[i]} = ${ang(a[i]!)}',
    ].join(r',\; ');
    steps.add(MathStep(
      index: 1,
      shortTitle: 'Datos',
      latexExpression: given,
      pedagogicalNote: 'Cada lado se llama como el ángulo opuesto: a frente a A, b frente a B, c frente a C.',
    ));
    final right = a.indexWhere((v) => v != null && (v - 90).abs() < _eps);
    final List<TriangleSolution> sols;
    final String kind;
    if (right >= 0) {
      kind = 'pitagoras';
      sols = [_right(s, a, right, steps)];
    } else if (ns == 3) {
      kind = 'coseno';
      sols = [_sss(s, steps)];
    } else if (ns == 2 && na == 1) {
      final known = [for (var i = 0; i < 3; i++) if (s[i] != null) i];
      final ai = a.indexWhere((v) => v != null);
      if (known.contains(ai)) {
        kind = 'seno';
        sols = _ssa(s, a, ai, steps);
      } else {
        kind = 'coseno';
        sols = [_sas(s, a, ai, steps)];
      }
    } else {
      kind = 'seno';
      sols = [_asa(s, a, steps)];
    }
    final ambiguous = sols.length > 1;
    final result = [
      for (var k = 0; k < sols.length; k++)
        '${ambiguous ? 'S_{${k + 1}}:\\; ' : ''}${[for (var i = 0; i < 3; i++) '${_sn[i]} = ${n(sols[k].sides[i])}'].join(r',\; ')}'
            r',\; '
            '${[for (var i = 0; i < 3; i++) '${_an[i]} = ${ang(sols[k].angles[i])}'].join(r',\; ')}',
    ].join(r'\quad ');
    return TriangleResult(
      sols,
      ambiguous ? 'ambiguo' : kind,
      StepByStepResolution(originalInputLatex: given, steps: steps, exactResultLatex: result, decimalApproxLatex: ''),
    );
  }

  // ------------------------------------------------------------ rectangulo

  static TriangleSolution _right(List<double?> s, List<double?> a, int r, List<MathStep> st) {
    final i = (r + 1) % 3, j = (r + 2) % 3;
    final h = _sn[r], li = _sn[i], lj = _sn[j];
    final sd = [...s], ad = [...a];
    ad[r] = 90;
    _s(st, 'Triángulo rectángulo', '${_an[r]} = 90^{\\circ}\\;\\Rightarrow\\; $h \\text{ es la hipotenusa}',
        'El lado opuesto al ángulo recto es la hipotenusa; los otros dos son los catetos.');
    final accI = ad[i] != null, accJ = ad[j] != null;
    if ((accI && ad[i]! >= 90 - _eps) || (accJ && ad[j]! >= 90 - _eps)) {
      throw const ArsenalException('Math ERROR: En un triángulo rectángulo los otros ángulos son agudos (menores que 90°).');
    }
    if (accI && accJ && (ad[i]! + ad[j]!) != 90 && ((ad[i]! + ad[j]!) - 90).abs() > 1e-6) {
      throw const ArsenalException('Math ERROR: Los ángulos agudos deben sumar 90°.');
    }
    if (!accI && !accJ && sd[r] != null && sd[i] != null && sd[j] == null) {
      if (sd[i]! >= sd[r]!) throw const ArsenalException('Math ERROR: Un cateto debe ser menor que la hipotenusa.');
      sd[j] = math.sqrt(sd[r]! * sd[r]! - sd[i]! * sd[i]!);
      _s(st, 'Teorema de Pitágoras', '$h^{2} = $li^{2} + $lj^{2}\\;\\Rightarrow\\; $lj = \\sqrt{${n(sd[r]!)}^{2} - ${n(sd[i]!)}^{2}} = ${n(sd[j]!)}',
          'Despejamos el cateto: cateto² = hipotenusa² - cateto².');
    } else if (!accI && !accJ && sd[r] != null && sd[j] != null && sd[i] == null) {
      if (sd[j]! >= sd[r]!) throw const ArsenalException('Math ERROR: Un cateto debe ser menor que la hipotenusa.');
      sd[i] = math.sqrt(sd[r]! * sd[r]! - sd[j]! * sd[j]!);
      _s(st, 'Teorema de Pitágoras', '$h^{2} = $li^{2} + $lj^{2}\\;\\Rightarrow\\; $li = \\sqrt{${n(sd[r]!)}^{2} - ${n(sd[j]!)}^{2}} = ${n(sd[i]!)}',
          'Despejamos el cateto: cateto² = hipotenusa² - cateto².');
    } else if (!accI && !accJ && sd[i] != null && sd[j] != null) {
      sd[r] = math.sqrt(sd[i]! * sd[i]! + sd[j]! * sd[j]!);
      _s(st, 'Teorema de Pitágoras', '$h = \\sqrt{$li^{2} + $lj^{2}} = \\sqrt{${n(sd[i]!)}^{2} + ${n(sd[j]!)}^{2}} = ${n(sd[r]!)}',
          'La hipotenusa es la raíz de la suma de los cuadrados de los catetos.');
    }
    if (ad[i] == null && ad[j] == null) {
      ad[i] = _deg(math.atan2(sd[i]!, sd[j]!));
      ad[j] = 90 - ad[i]!;
      _s(st, 'Razón tangente', '\\tan ${_an[i]} = \\frac{$li}{$lj} = \\frac{${n(sd[i]!)}}{${n(sd[j]!)}}\\;\\Rightarrow\\; ${_an[i]} = ${ang(ad[i]!)},\\; ${_an[j]} = 90^{\\circ} - ${ang(ad[i]!)} = ${ang(ad[j]!)}',
          'tan = cateto opuesto / cateto contiguo. El otro ángulo agudo es el complementario.');
    } else {
      if (ad[i] == null) {
        ad[i] = 90 - ad[j]!;
        _s(st, 'Ángulo complementario', '${_an[i]} = 90^{\\circ} - ${ang(ad[j]!)} = ${ang(ad[i]!)}', 'Los ángulos agudos suman 90°.');
      } else if (ad[j] == null) {
        ad[j] = 90 - ad[i]!;
        _s(st, 'Ángulo complementario', '${_an[j]} = 90^{\\circ} - ${ang(ad[i]!)} = ${ang(ad[j]!)}', 'Los ángulos agudos suman 90°.');
      }
      if (sd[r] != null) {
        sd[i] ??= sd[r]! * math.sin(_rad(ad[i]!));
        sd[j] ??= sd[r]! * math.sin(_rad(ad[j]!));
        _s(st, 'Razón seno', '$li = $h \\sin ${_an[i]} = ${n(sd[i]!)},\\quad $lj = $h \\sin ${_an[j]} = ${n(sd[j]!)}',
            'sen = cateto opuesto / hipotenusa, luego cateto = hipotenusa · sen(ángulo opuesto).');
      } else {
        final base = sd[i] != null ? i : j;
        final other = base == i ? j : i;
        sd[r] = sd[base]! / math.sin(_rad(ad[base]!));
        sd[other] ??= sd[r]! * math.sin(_rad(ad[other]!));
        _s(st, 'Razón seno', '$h = \\frac{${_sn[base]}}{\\sin ${_an[base]}} = ${n(sd[r]!)},\\quad ${_sn[other]} = $h \\sin ${_an[other]} = ${n(sd[other]!)}',
            'Despejamos la hipotenusa del seno del ángulo opuesto al cateto conocido.');
      }
    }
    return TriangleSolution([sd[0]!, sd[1]!, sd[2]!], [ad[0]!, ad[1]!, ad[2]!]);
  }

  // ----------------------------------------------------------- oblicuangulos

  static TriangleSolution _sss(List<double?> s, List<MathStep> st) {
    final x = s.cast<double>();
    if (x[0] + x[1] <= x[2] || x[0] + x[2] <= x[1] || x[1] + x[2] <= x[0]) {
      throw const ArsenalException('Math ERROR: No es un triángulo (un lado debe ser menor que la suma de los otros dos).');
    }
    final ang = List<double>.filled(3, 0);
    for (var i = 0; i < 3; i++) {
      final j = (i + 1) % 3, k = (i + 2) % 3;
      final cosv = ((x[j] * x[j] + x[k] * x[k] - x[i] * x[i]) / (2 * x[j] * x[k])).clamp(-1.0, 1.0);
      ang[i] = _deg(math.acos(cosv));
      _s(st, 'Teorema del coseno', '\\cos ${_an[i]} = \\frac{${_sn[j]}^{2} + ${_sn[k]}^{2} - ${_sn[i]}^{2}}{2\\,${_sn[j]}\\,${_sn[k]}} = ${n(cosv)}\\;\\Rightarrow\\; ${_an[i]} = ${TriangleSolver.ang(ang[i])}',
          '${_sn[i]}² = ${_sn[j]}² + ${_sn[k]}² - 2·${_sn[j]}·${_sn[k]}·cos ${_an[i]}; despejamos el coseno.');
    }
    return TriangleSolution(x, ang);
  }

  static TriangleSolution _sas(List<double?> s, List<double?> a, int ai, List<MathStep> st) {
    final j = (ai + 1) % 3, k = (ai + 2) % 3;
    final x = [...s];
    x[ai] = math.sqrt(x[j]! * x[j]! + x[k]! * x[k]! - 2 * x[j]! * x[k]! * math.cos(_rad(a[ai]!)));
    final c2 = x[ai]! * x[ai]!;
    final c2Txt = (c2 - c2.roundToDouble()).abs() < 1e-6 ? '${c2.round()}' : n(c2);
    final cosTxt = n(math.cos(_rad(a[ai]!)));
    _s(st, 'Teorema del coseno',
        '${_sn[ai]}^{2} = ${_sn[j]}^{2} + ${_sn[k]}^{2} - 2\\,${_sn[j]}\\,${_sn[k]}\\cos ${_an[ai]} = ${n(x[j]! * x[j]!)} + ${n(x[k]! * x[k]!)} - 2\\cdot ${n(x[j]!)}\\cdot ${n(x[k]!)}\\cdot $cosTxt = $c2Txt\\;\\Rightarrow\\; ${_sn[ai]} = \\sqrt{$c2Txt} \\approx ${n(x[ai]!)}',
        'Conocemos dos lados y el ángulo que forman: el coseno da el lado opuesto.');
    final sol = _sss(x, <MathStep>[]);
    final ang = [...sol.angles];
    ang[ai] = a[ai]!;
    _s(st, 'Ángulos restantes', '${_an[j]} = ${TriangleSolver.ang(ang[j])},\\quad ${_an[k]} = ${TriangleSolver.ang(ang[k])}',
        'Se obtienen con el teorema del coseno (o del seno) y suman 180° con el dato.');
    return TriangleSolution(x.cast<double>(), ang);
  }

  static TriangleSolution _asa(List<double?> s, List<double?> a, List<MathStep> st) {
    final ang = [...a];
    final miss = ang.indexWhere((v) => v == null);
    if (miss >= 0) {
      final sum = ang.whereType<double>().fold<double>(0, (p, v) => p + v);
      if (sum >= 180 - _eps) throw const ArsenalException('Math ERROR: Los ángulos deben sumar menos de 180°.');
      ang[miss] = 180 - sum;
      _s(st, 'Tercer ángulo', '${_an[miss]} = 180^{\\circ} - ${TriangleSolver.ang(sum)} = ${TriangleSolver.ang(ang[miss]!)}', 'Los ángulos de un triángulo suman 180°.');
    }
    final ks = s.indexWhere((v) => v != null);
    final ratio = s[ks]! / math.sin(_rad(ang[ks]!));
    final x = [for (var i = 0; i < 3; i++) s[i] ?? ratio * math.sin(_rad(ang[i]!))];
    _s(st, 'Teorema del seno', '\\frac{a}{\\sin A} = \\frac{b}{\\sin B} = \\frac{c}{\\sin C} = ${n(ratio)}\\;\\Rightarrow\\; a = ${n(x[0])},\\; b = ${n(x[1])},\\; c = ${n(x[2])}',
        'Cada lado es proporcional al seno de su ángulo opuesto.');
    return TriangleSolution(x, ang.cast<double>());
  }

  /// SSA: dos lados y un angulo opuesto a uno de ellos (puede ser ambiguo).
  static List<TriangleSolution> _ssa(List<double?> s, List<double?> a, int ai, List<MathStep> st) {
    final other = [for (var i = 0; i < 3; i++) if (i != ai && s[i] != null) i].first;
    final third = 3 - ai - other;
    final sinOther = s[other]! * math.sin(_rad(a[ai]!)) / s[ai]!;
    _s(st, 'Teorema del seno', '\\frac{${_sn[ai]}}{\\sin ${_an[ai]}} = \\frac{${_sn[other]}}{\\sin ${_an[other]}}\\;\\Rightarrow\\; \\sin ${_an[other]} = \\frac{${n(s[other]!)}\\sin ${TriangleSolver.ang(a[ai]!)}}{${n(s[ai]!)}} = ${n(sinOther)}',
        'Despejamos el seno del ángulo desconocido.');
    if (sinOther > 1 + 1e-12) {
      throw const ArsenalException('Math ERROR: Caso imposible, el seno sería mayor que 1.');
    }
    final base = _deg(math.asin(sinOther.clamp(-1.0, 1.0)));
    final cands = <double>[base];
    if ((180 - base - base).abs() > 1e-9) cands.add(180 - base);
    final out = <TriangleSolution>[];
    for (final b in cands) {
      final c = 180 - a[ai]! - b;
      if (c <= 1e-9) continue;
      final ang = List<double>.filled(3, 0);
      ang[ai] = a[ai]!;
      ang[other] = b;
      ang[third] = c;
      final x = List<double>.filled(3, 0);
      x[ai] = s[ai]!;
      x[other] = s[other]!;
      x[third] = s[ai]! * math.sin(_rad(c)) / math.sin(_rad(a[ai]!));
      out.add(TriangleSolution(x, ang));
    }
    if (out.isEmpty) throw const ArsenalException('Math ERROR: Caso imposible, no existe el triángulo.');
    _s(st, out.length > 1 ? 'Caso ambiguo: dos triángulos' : 'Ángulo y lado restantes',
        out.map((o) => '${_an[other]} = ${TriangleSolver.ang(o.angles[other])},\\; ${_an[third]} = ${TriangleSolver.ang(o.angles[third])},\\; ${_sn[third]} = ${n(o.sides[third])}').join(r'\quad |\quad '),
        out.length > 1
            ? 'El seno da dos ángulos (B y 180° - B) y los dos cumplen que la suma de ángulos es menor que 180°.'
            : 'Solo una solución cumple que los ángulos sumen menos de 180°.',
        trick: out.length > 1 ? 'Ambigüedad SSA: el lado opuesto al dato es menor que el otro lado pero mayor que su altura.' : null);
    return out;
  }
}
