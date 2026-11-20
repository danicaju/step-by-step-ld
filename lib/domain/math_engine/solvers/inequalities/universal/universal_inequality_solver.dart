import 'dart:math' as math;

import '../../../../../core/formatting/step_note_formatter.dart';
import '../../../models/inequality_models.dart';
import '../../../models/step_resolution.dart';
import '../../../parser/expression_parser.dart';
import '../../exact/ext_expr.dart';
import '../../exact/ext_parser.dart';
import '../inequality_sign.dart';
import 'critical_scan.dart';
import 'exact_label.dart';
import 'inequality_family_detector.dart';
import 'inequality_family_steps.dart';
import 'inequality_interval_ops.dart';
import 'numeric_function.dart';

/// Resolutor universal de inecuaciones en `x`: dominio natural, ceros y discontinuidades
/// (simbolico cuando se reconoce + barrido y biseccion), signo en cada subintervalo.
class UniversalInequalitySolver {
  const UniversalInequalitySolver._();

  static final Expando<Inequality1DVisualData> visualDataExpando = Expando<Inequality1DVisualData>();

  static int _sg(double v) => v.abs() < 1e-9 ? 0 : (v > 0 ? 1 : -1);

  static String _sgTex(int s) => s > 0 ? '+' : (s < 0 ? '-' : '0');

  static XNode _parse(String side) {
    try {
      return ExtParser().parse(ExpressionParser.finalizeForEvaluation(side));
    } on ExtUnsupported catch (e) {
      throw FormatException('Inecuación no soportada: ${e.message}');
    }
  }

  /// Resuelve `lhs <signo> rhs`. Lanza `FormatException` si no se puede interpretar.
  static StepByStepResolution solve(String lhs, String rhs, InequalitySign sign) {
    final l = _parse(lhs), r = _parse(rhs.isEmpty ? '0' : rhs);
    if (!NumFn.hasX(l) && !NumFn.hasX(r)) {
      throw const FormatException('Escribe la incógnita x en la inecuación.');
    }
    final family = InequalityFamilyDetector.detect(l, r);
    final trig = NumFn.hasTrig(l) || NumFn.hasTrig(r);
    final window = trig ? (0.0, 2 * math.pi) : null;
    double? f(double x) {
      final a = NumFn.eval(l, x), b = NumFn.eval(r, x);
      return a == null || b == null ? null : a - b;
    }

    final crits = CriticalScan.run(f, window: window);
    if (crits.length > 40) throw const FormatException('La inecuación tiene demasiados puntos críticos.');
    final bases = InequalityFamilyDetector.numericBases(l, r);
    final labels = <ExactLabel>[
      for (final c in crits)
        c.kind == CritKind.window
            ? (c.v == 0 ? const ExactLabel('0', 0, true) : ExactLabel(r'2\pi', c.v, true))
            : ExactLabel.of(c.v, bases: bases),
    ];
    final pts = [for (final lab in labels) lab.value];
    final n = crits.length;

    // Tramos (n + 1) y puntos (n).
    double? probe(int i) {
      if (n == 0) {
        for (final x in [0.0, 1.0, -1.0, 2.0]) {
          if (f(x) != null) return x;
        }
        return null;
      }
      if (i == 0) return pts.first - math.max(1, pts.first.abs() * 0.5);
      if (i == n) return pts.last + math.max(1, pts.last.abs() * 0.5);
      return (pts[i - 1] + pts[i]) / 2;
    }

    final segVal = <double?>[
      for (var i = 0; i <= n; i++) (window != null && (i == 0 || i == n)) ? null : _evalAt(f, probe(i)),
    ];
    final segSat = [for (final v in segVal) v != null && sign.matchesSign(_sg(v))];
    final segDef = [for (final v in segVal) v != null];
    final ptVal = <double?>[for (var i = 0; i < n; i++) _ptValue(f, crits[i], pts[i])];
    final ptSat = [
      for (var i = 0; i < n; i++)
        ptVal[i] != null && crits[i].kind != CritKind.pole && sign.matchesSign(_sg(ptVal[i]!)),
    ];
    final ptDef = [for (var i = 0; i < n; i++) ptVal[i] != null && crits[i].kind != CritKind.pole];
    final labelTex = [for (final lab in labels) lab.latex];

    final solution = IntervalOps.assemble(points: pts, labels: labelTex, segIn: segSat, ptIn: ptSat);
    final domain = IntervalOps.assemble(points: pts, labels: labelTex, segIn: segDef, ptIn: ptDef);
    final solTex = IntervalOps.latexOf(solution);
    final domTex = IntervalOps.latexOf(domain);

    final diff = _isZero(r) ? l : XBin(l, '-', r);
    final conds = {
      ...InequalityFamilyDetector.domainConditions(l),
      ...InequalityFamilyDetector.domainConditions(r),
    }.toList();
    final approx = labels.any((lab) => !lab.exact);

    final steps = <MathStep>[
      MathStep(
        index: 0,
        shortTitle: 'Todo a un miembro',
        latexExpression: '${l.latex()} ${sign.latex} ${r.latex()} \\implies ${diff.latex()} ${sign.latex} 0',
        pedagogicalNote:
            'Pasamos todo al primer miembro para estudiar el signo de f(x) = ${_plain(diff)} frente a 0. La solución son los x donde f(x) tiene el signo pedido.',
      ),
      ...InequalityFamilySteps.build(family, l, r, sign),
      MathStep(
        index: 0,
        shortTitle: 'Dominio de la función',
        latexExpression: conds.isEmpty
            ? 'D = $domTex'
            : '${conds.join(r',\;\; ')} \\implies D = $domTex',
        pedagogicalNote: conds.isEmpty
            ? 'La expresión está definida para cualquier número real.'
            : 'Se exigen las condiciones de existencia de cada raíz, logaritmo o denominador. La solución final debe pertenecer a este dominio.',
        warningTrick: conds.isEmpty ? null : 'Un valor que anula un denominador o hace negativo un radicando queda siempre excluido.',
      ),
      MathStep(
        index: 0,
        shortTitle: 'Puntos críticos',
        latexExpression: n == 0
            ? r'\text{No hay puntos criticos}'
            : [for (var i = 0; i < n; i++) 'x = ${labelTex[i]}'].join(r',\;\; '),
        pedagogicalNote: n == 0
            ? 'f(x) no se anula ni cambia de dominio: tiene el mismo signo en toda la recta.'
            : 'Son los ceros de f(x), los extremos del dominio y los valores donde no existe. En ellos puede cambiar el signo.${approx ? ' Los valores aproximados se dan con 4 decimales.' : ''}',
        warningTrick: window != null
            ? 'Con funciones trigonométricas se estudia una vuelta, de 0 a 2π (en radianes); el resultado se repite cada 2π.'
            : null,
      ),
      _signTable(n, labelTex, segVal, ptVal, crits),
      MathStep(
        index: 0,
        shortTitle: 'Solución: tramos que cumplen la desigualdad',
        latexExpression: 'x \\in $solTex',
        pedagogicalNote:
            'Nos quedamos con los tramos cuyo signo cumple ${sign.symbol} 0. Un cero entra solo si la desigualdad no es estricta; un valor fuera del dominio nunca entra.',
      ),
    ];

    final res = StepByStepResolution(
      originalInputLatex: '${l.latex()} ${sign.latex} ${r.latex()}',
      steps: [for (var i = 0; i < steps.length; i++) _renumber(steps[i], i + 1)],
      exactResultLatex: solTex,
      decimalApproxLatex: solTex,
    );
    visualDataExpando[res] = Inequality1DVisualData(
      criticalPoints: [
        for (var i = 0; i < n; i++) CriticalPoint(value: pts[i], label: labelTex[i], isClosed: ptSat[i]),
      ],
      primaryIntervals: solution,
      signTestIntervals: [
        for (var i = 0; i <= n; i++)
          InequalityInterval(
            start: i == 0 ? double.negativeInfinity : pts[i - 1],
            end: i == n ? double.infinity : pts[i],
            startLabel: i == 0 ? null : labelTex[i - 1],
            endLabel: i == n ? null : labelTex[i],
            isSatisfied: segSat[i],
          ),
      ],
      solutionLatex: solTex,
    );
    return res;
  }

  static MathStep _renumber(MathStep s, int i) => MathStep(
        index: i,
        shortTitle: s.shortTitle,
        latexExpression: s.latexExpression,
        pedagogicalNote: s.pedagogicalNote,
        warningTrick: s.warningTrick,
        showsNumberLine: s.showsNumberLine,
      );

  static bool _isZero(XNode n) => n is XNum && n.value.numerator == 0;

  static String _plain(XNode n) => StepNoteFormatter.toPlain(n.latex());

  static double? _evalAt(double? Function(double) f, double? x) => x == null ? null : f(x);

  /// Valor de f en un punto critico (con la abscisa exacta si se reconoce); un cero devuelve 0.
  static double? _ptValue(double? Function(double) f, Crit c, double snapped) {
    if (c.kind == CritKind.root || c.kind == CritKind.touch) return 0;
    return f(snapped);
  }

  static MathStep _signTable(int n, List<String> labels, List<double?> segVal, List<double?> ptVal, List<Crit> crits) {
    final header = <String>[];
    final row = <String>[];
    for (var i = 0; i <= n; i++) {
      final a = i == 0 ? r'-\infty' : labels[i - 1];
      final b = i == n ? r'+\infty' : labels[i];
      header.add('($a, $b)');
      final v = segVal[i];
      row.add(v == null ? r'\nexists' : _sgTex(_sg(v)));
      if (i < n) {
        header.add(labels[i]);
        final pv = ptVal[i];
        row.add(crits[i].kind == CritKind.pole || pv == null ? r'\nexists' : _sgTex(_sg(pv)));
      }
    }
    return MathStep(
      index: 0,
      shortTitle: 'Tabla de signos',
      latexExpression: '\\begin{array}{c|${'c' * header.length}}\n'
          'x & ${header.join(' & ')} \\\\\n\\hline\n'
          'f(x) & ${row.join(' & ')}\n\\end{array}',
      pedagogicalNote:
          'Evaluamos f en un punto de cada tramo. Entre dos puntos críticos consecutivos el signo no cambia. El símbolo ∄ indica que f no existe ahí.',
    );
  }
}
