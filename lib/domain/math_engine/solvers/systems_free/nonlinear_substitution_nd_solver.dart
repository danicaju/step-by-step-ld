import 'dart:math' as math;

import '../exact/ext_expr.dart';
import '../inequalities/universal/inequality_family_detector.dart';
import '../inequalities/universal/numeric_function.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart' show AngleUnit;
import 'dpoly.dart';
import 'nd_atom_inverses.dart';
import 'nd_common.dart';

/// Funcion elemental de UNA variable dentro de un sistema: `kind(a·v + b)`.
class _Atom {
  final String key;
  final String kind; // id inv root ln log10 logb exp sin cos tan
  final int v;
  final double a, b;
  final double base; // logb / exp
  final int index; // root
  final String latex;
  const _Atom(this.key, this.kind, this.v, this.a, this.b, this.base, this.index, this.latex);
}

/// Cambios de variable N x N: si cada incognita aparece solo a traves de UNA funcion elemental
/// (1/x, raiz, ln, log, a^x, sin, cos, tan...) y el sistema es lineal en esas funciones, se plantea
/// `u_i = f_i(x_i)`, se resuelve el sistema lineal por Gauss y se deshace el cambio con dominio.
abstract final class NonlinearSubstitutionNdSolver {
  static const List<String> _unk = ['u', 'v', 't', 's'];

  static final _regAtoms = <String, _Atom>{};

  // ------------------------------------------------------------- deteccion
  static Set<int> _varsOf(XNode n) {
    final s = <int>{};
    InequalityFamilyDetector.walk(n, (v) {
      if (v is XVar) {
        final i = NdSystem.vars.indexOf(v.name);
        if (i >= 0) s.add(i);
      }
    });
    return s;
  }

  /// `a·v + b` con [v] unica variable; `null` si no es lineal de grado exacto 1.
  static (double, double)? _linear(XNode g, int v, AngleUnit unit) {
    final p = DPoly.fromNode(g, unit);
    if (p == null || p.used.length != 1 || !p.used.contains(v) || p.degree != 1) return null;
    final a = p.coef(List.filled(4, 0)..[v] = 1);
    return a.abs() < 1e-12 ? null : (a, p.constantTerm);
  }

  static double? _constOf(XNode n, AngleUnit unit) => DPoly.hasVar(n) ? null : NumFn.evalEnv(n, const {}, unit: unit);

  static (_Atom, double)? _atom(XNode n, int v, AngleUnit unit) {
    String key(String k, double a, double b, double base, int idx) =>
        '$k|$v|${a.toStringAsFixed(9)}|${b.toStringAsFixed(9)}|${base.toStringAsFixed(9)}|$idx';
    _Atom make(String kind, double a, double b, {double base = 0, int index = 0}) {
      final at = _Atom(key(kind, a, b, base, index), kind, v, a, b, base, index, n.latex());
      return _regAtoms.putIfAbsent(at.key, () => at);
    }

    switch (n) {
      case XVar():
        return (make('id', 1, 0), 1.0);
      case XFn(:final name, :final arg, :final base):
        final g = _linear(arg, v, unit);
        if (g == null) return null;
        if (name == 'ln') return (make('ln', g.$1, g.$2), 1.0);
        if (name == 'log') {
          if (base == null) return (make('log10', g.$1, g.$2), 1.0);
          final bv = _constOf(base, unit);
          if (bv == null || bv <= 0 || (bv - 1).abs() < 1e-12) {
            throw const FormatException('La base del logaritmo debe ser mayor que 0 y distinta de 1.');
          }
          return (make('logb', g.$1, g.$2, base: bv), 1.0);
        }
        if (name == 'sin' || name == 'cos' || name == 'tan' || NdAtomInverses.kinds.contains(name)) {
          return (make(name, g.$1, g.$2), 1.0);
        }
        return null;
      case XRoot(:final index, :final rad):
        final g = _linear(rad, v, unit);
        final m = index == null ? 2.0 : _constOf(index, unit);
        if (g == null || m == null || m < 2 || m != m.roundToDouble()) return null;
        return (make('root', g.$1, g.$2, index: m.round()), 1.0);
      case XBin(:final l, :final op, :final r) when op == '/':
        final c = _constOf(l, unit);
        final g = _linear(r, v, unit);
        if (c == null || g == null) return null;
        return (make('inv', g.$1, g.$2), c);
      case XPow(:final base, :final exp):
        final eg = _linear(exp, v, unit);
        final bv = _constOf(base, unit);
        if (eg != null && bv != null) {
          if (bv <= 0 || (bv - 1).abs() < 1e-12) return null;
          return (make('exp', eg.$1, eg.$2, base: bv), 1.0);
        }
        final e = _constOf(exp, unit);
        final g = _linear(base, v, unit);
        if (e != null && g != null && e == -1) return (make('inv', g.$1, g.$2), 1.0);
        return null;
      default:
        return null;
    }
  }

  static Map<String, double>? _scale(Map<String, double>? m, double k) => m == null ? null : {for (final e in m.entries) e.key: e.value * k};

  static Map<String, double>? _merge(Map<String, double>? a, Map<String, double>? b, double sign) {
    if (a == null || b == null) return null;
    final out = {...a};
    b.forEach((k, v) => out[k] = (out[k] ?? 0) + sign * v);
    return out;
  }

  static Map<String, double>? _lin(XNode n, AngleUnit unit) {
    if (!DPoly.hasVar(n)) {
      final v = NumFn.evalEnv(n, const {}, unit: unit);
      if (v == null) {
        throw const FormatException(
            'Una constante del sistema no está definida: revisa el argumento del logaritmo o de la raíz.');
      }
      return {'': v};
    }
    final vars = _varsOf(n);
    if (vars.length == 1) {
      final at = _atom(n, vars.first, unit);
      if (at != null) return {at.$1.key: at.$2};
    }
    switch (n) {
      case XNeg(:final a):
        return _scale(_lin(a, unit), -1);
      case XBin(:final l, :final op, :final r):
        if (op == '+' || op == '-') return _merge(_lin(l, unit), _lin(r, unit), op == '+' ? 1 : -1);
        if (op == '*') {
          final cl = _constOf(l, unit), cr = _constOf(r, unit);
          if (cl != null) return _scale(_lin(r, unit), cl);
          if (cr != null) return _scale(_lin(l, unit), cr);
          return null;
        }
        final d = _constOf(r, unit);
        return d == null || d == 0 ? null : _scale(_lin(l, unit), 1 / d);
      default:
        return null;
    }
  }

  // ------------------------------------------------------------- inversion
  static double _asin(double u, AngleUnit unit) => _fromRad(math.asin(u.clamp(-1.0, 1.0)), unit);
  static double _acos(double u, AngleUnit unit) => _fromRad(math.acos(u.clamp(-1.0, 1.0)), unit);
  static double _fromRad(double r, AngleUnit unit) => switch (unit) {
        AngleUnit.deg => r * 180 / math.pi,
        AngleUnit.grad => r * 200 / math.pi,
        _ => r,
      };

  /// Valores de `g = a v + b` que cumplen `kind(g) = u`; lista vacia si [u] esta fuera de dominio.
  static List<double> _invert(_Atom at, double u, AngleUnit unit) {
    final turn = NdFmt.fullTurn(unit);
    List<double> g;
    switch (at.kind) {
      case 'id':
        g = [u];
      case 'inv':
        g = u.abs() < 1e-12 ? [] : [1 / u];
      case 'root':
        g = at.index.isEven && u < -1e-12 ? [] : [math.pow(u.abs(), at.index).toDouble() * (u < 0 ? -1 : 1)];
      case 'ln':
        g = [math.exp(u)];
      case 'log10':
        g = [math.pow(10, u).toDouble()];
      case 'logb':
        g = [math.pow(at.base, u).toDouble()];
      case 'exp':
        g = u <= 1e-12 ? [] : [math.log(u) / math.log(at.base)];
      case 'sin':
        if (u.abs() > 1 + 1e-9) return [];
        final s = NdFmt.wrap(_asin(u, unit), turn);
        g = [s, NdFmt.wrap(turn / 2 - s, turn)];
      case 'cos':
        if (u.abs() > 1 + 1e-9) return [];
        final c = _acos(u, unit);
        g = [c, NdFmt.wrap(turn - c, turn)];
      case 'sinh' || 'cosh' || 'tanh' || 'asin' || 'acos' || 'atan':
        g = NdAtomInverses.invert(at.kind, u, unit);
      default: // tan
        final t = NdFmt.wrap(_fromRad(math.atan(u), unit), turn / 2);
        g = [t, t + turn / 2];
    }
    final out = <double>[];
    for (final x in g) {
      final v = (x - at.b) / at.a;
      if (v.isFinite && !out.any((o) => (o - v).abs() < 1e-9)) out.add(v);
    }
    return out;
  }

  static List<double>? _gauss(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
    for (var c = 0; c < n; c++) {
      var p = c;
      for (var r = c + 1; r < n; r++) {
        if (m[r][c].abs() > m[p][c].abs()) p = r;
      }
      if (m[p][c].abs() < 1e-10) return null;
      final t = m[c];
      m[c] = m[p];
      m[p] = t;
      for (var r = c + 1; r < n; r++) {
        final f = m[r][c] / m[c][c];
        for (var k = c; k <= n; k++) {
          m[r][k] -= f * m[c][k];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var s = m[i][n];
      for (var k = i + 1; k < n; k++) {
        s -= m[i][k] * x[k];
      }
      x[i] = s / m[i][i];
    }
    return x;
  }

  static String _domainNote(String kind) => switch (kind) {
        'inv' => 'u distinto de 0 (no se puede dividir entre 0)',
        'root' => 'u mayor o igual que 0 (una raíz par no es negativa)',
        'exp' => 'u mayor que 0 (una potencia de base positiva es positiva)',
        'sin' || 'cos' => 'u entre -1 y 1',
        _ => NdAtomInverses.note(kind),
      };

  // ------------------------------------------------------------- resolucion
  /// `null` si el sistema no se puede linealizar con un cambio de variable por incognita.
  static StepByStepResolution? solve(NdSystem sys) {
    _regAtoms.clear();
    final n = sys.n;
    final rows = <Map<String, double>>[];
    for (final (l, r) in sys.sides) {
      final m = _merge(_lin(l, sys.unit), _lin(r, sys.unit), -1);
      if (m == null) return null;
      rows.add(m);
    }
    final atomOf = <int, _Atom>{};
    for (final row in rows) {
      for (final k in row.keys) {
        if (k.isEmpty) continue;
        final at = _regAtoms[k]!;
        final prev = atomOf[at.v];
        if (prev != null && prev.key != at.key) return null; // dos funciones distintas de la misma incognita
        atomOf[at.v] = at;
      }
    }
    if (atomOf.length != n || atomOf.values.every((a) => a.kind == 'id')) return null;

    final a = [for (final row in rows) [for (var v = 0; v < n; v++) row[atomOf[v]!.key] ?? 0.0]];
    final b = [for (final row in rows) -(row[''] ?? 0.0)];
    final u = _gauss(a, b);
    if (u == null) return null;

    String uName(int v) => atomOf[v]!.kind == 'id' ? NdSystem.names[v] : _unk[v];
    String lin(List<double> c, double rhs) {
      final buf = StringBuffer();
      var first = true;
      for (var v = 0; v < n; v++) {
        if (c[v].abs() < 1e-12) continue;
        buf.write(NdFmt.term(c[v], uName(v), first: first));
        first = false;
      }
      return '${first ? '0' : buf} = ${NdFmt.num(rhs)}';
    }

    final steps = <MathStep>[
      NdFmt.step(
        'Cambio de variable',
        NdFmt.cases([
          for (var v = 0; v < n; v++)
            if (atomOf[v]!.kind != 'id') '${_unk[v]} = ${atomOf[v]!.latex}',
        ]),
        'Cada incógnita aparece solo dentro de una misma función. Llamamos u, v... a esas funciones para que el sistema pase a ser lineal.',
      ),
      NdFmt.step(
        'Sistema lineal en las nuevas incógnitas',
        NdFmt.cases([for (var i = 0; i < n; i++) lin(a[i], b[i])]),
        'Reescrito con el cambio, el sistema es lineal de $n×$n y se resuelve por Gauss con pivoteo parcial.',
      ),
      NdFmt.step(
        'Resolver el sistema lineal',
        NdFmt.cases([for (var v = 0; v < n; v++) '${uName(v)} = ${NdFmt.num(u[v])}']),
        'Eliminamos incógnitas fila a fila eligiendo en cada columna el pivote de mayor valor absoluto.',
      ),
    ];

    final undo = <String>[];
    final branches = <List<double>>[];
    final notes = <String>[];
    for (var v = 0; v < n; v++) {
      final at = atomOf[v]!;
      final vals = _invert(at, u[v], sys.unit);
      branches.add(vals);
      if (at.kind != 'id') {
        undo.add('${NdSystem.names[v]} = ${vals.isEmpty ? r'\varnothing' : vals.map(NdFmt.num).join(r' \;\text{o}\; ')}');
        if (vals.isEmpty) notes.add('${_unk[v]} = ${NdFmt.dec(u[v])} no cumple: ${_domainNote(at.kind)}.');
      }
    }
    final trig = atomOf.values.any((q) => q.kind == 'sin' || q.kind == 'cos' || q.kind == 'tan');
    steps.add(NdFmt.step(
      'Deshacer el cambio y comprobar el dominio',
      NdFmt.cases(undo),
      notes.isNotEmpty
          ? notes.join(' ')
          : 'Despejamos cada incógnita invirtiendo su función${trig ? ' (soluciones principales entre 0 y una vuelta completa)' : ''} y comprobamos las condiciones de existencia.',
      'Una solución del sistema en las nuevas incógnitas solo vale si está dentro del dominio de la función.',
    ));

    final cands = <List<double>>[];
    void combine(int i, List<double> cur) {
      if (cands.length >= 48) return;
      if (i == n) {
        cands.add([...cur]);
        return;
      }
      for (final x in branches[i]) {
        combine(i + 1, [...cur, x]);
      }
    }

    combine(0, []);
    final valid = NdFmt.dedupe([
      for (final c in cands)
        if (sys.satisfies(c)) c,
    ]);
    final dropped = cands.length - valid.length;
    steps.add(NdFmt.step(
      'Comprobar en el sistema original',
      valid.isEmpty
          ? r'\text{Sin solucion real}'
          : NdFmt.cases([for (final s in valid) '${NdFmt.point(s, n, decimal: !s.take(n).every(NdFmt.isExact))} \\;\\text{valida}']),
      dropped > 0
          ? 'Sustituimos cada combinación en las ecuaciones originales y descartamos $dropped que no las cumplen (soluciones extrañas).'
          : 'Sustituimos cada combinación en las ecuaciones originales: todas las que están en el dominio las cumplen.',
    ));
    return NdFmt.finish(sys, steps, valid);
  }
}
