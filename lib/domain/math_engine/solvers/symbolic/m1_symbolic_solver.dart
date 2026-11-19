import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../parser/expression_parser.dart';
import '../../polynomials/algebraic_fraction_solver.dart';
import '../equations/eq_poly.dart';
import '../exact/ext_expr.dart';
import '../exact/ext_parser.dart';

/// M1 algebraico: `x` / `y` minusculas son variables simbolicas (no registros de memoria).
///
/// `2x+3x = 5x`, `(x+1)^2 = x^2+2x+1`, `2x^2/x = 2x`. Las mayusculas `X`, `Y`, `A..F`, `M`
/// siguen siendo memoria y se sustituyen por su valor numerico.
class M1SymbolicSolver {
  const M1SymbolicSolver._();

  static final RegExp _fnNames = RegExp(
    r'sin|cos|tan|log|ln|Abs|ANS|ans|root|mcm|mcd|nCr|nPr|Pol|Rec|RanInt|Ran|arcsin|arccos|arctan|asin|acos|atan|exp|sqrt',
  );

  static String _stripFns(String raw) => raw.replaceAll(_fnNames, '');

  /// Letras algebraicas (`x`, `y`) presentes en [raw].
  static Set<String> variablesIn(String raw) {
    final s = _stripFns(raw);
    return {
      for (final v in const ['x', 'y'])
        if (s.contains(v)) v,
    };
  }

  /// `true` si [raw] contiene `x` o `y` minuscula como variable.
  static bool applies(String raw) => variablesIn(raw).isNotEmpty;

  static String _ratText(Rational r) =>
      r.isInteger ? '(${r.numerator})' : '((${r.numerator})/(${r.denominator}))';

  /// Sustituye los registros de memoria en mayuscula por su valor.
  static String _withMemory(String raw, Map<String, Rational> memory) {
    final buf = StringBuffer();
    final fn = _fnNames.allMatches(raw).toList();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final inFn = fn.any((m) => i >= m.start && i < m.end);
      if (!inFn && RegExp(r'[A-FMXY]').hasMatch(ch)) {
        buf.write(_ratText(memory[ch] ?? Rational(0)));
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static bool _letter(String c) => c == r'\' || RegExp(r'[A-Za-z]').hasMatch(c);

  /// Cambia la `x` de un LaTeX por [v] sin tocar comandos (`\text`, `\textcolor`...).
  static String _asVar(String latex, String v) {
    if (v == 'x') return latex;
    final b = StringBuffer();
    for (var i = 0; i < latex.length; i++) {
      final c = latex[i];
      final prev = i > 0 && _letter(latex[i - 1]);
      final next = i + 1 < latex.length && RegExp(r'[A-Za-z]').hasMatch(latex[i + 1]);
      b.write(c == 'x' && !prev && !next ? v : c);
    }
    return b.toString();
  }

  static MathStep _s(int i, String t, String l, String n, {String? trick}) =>
      MathStep(index: i, shortTitle: t, latexExpression: l, pedagogicalNote: n, warningTrick: trick);

  /// Simplifica la expresion algebraica; `null` si [raw] no tiene variables minusculas.
  ///
  /// Lanza `FormatException` si mezcla `x` e `y` o no se puede interpretar.
  static StepByStepResolution? solve(String raw, {Map<String, Rational> memory = const {}}) {
    final vars = variablesIn(raw);
    if (vars.isEmpty) return null;
    if (vars.length > 1) {
      throw const FormatException('Usa una sola variable (x o y) en la expresión.');
    }
    final v = vars.first;
    final lower = _withMemory(raw, memory).replaceAll(v, 'x');
    final XNode node;
    try {
      node = ExtParser().parse(ExpressionParser.finalizeForEvaluation(lower));
    } on ExtUnsupported catch (e) {
      throw FormatException(e.message);
    }
    final original = _asVar(node.latex(), v);
    final steps = <MathStep>[
      _s(1, 'Variable algebraica',
          original,
          'La letra $v minúscula es una incógnita: no se sustituye por ningún número, se opera con ella como símbolo. '
          '(Las mayúsculas X, Y, A..F, M son las memorias.)'),
    ];
    final frac = PolyOps.rationalOf(node);
    if (frac == null) {
      steps.add(_s(2, 'Expresión no polinómica',
          original,
          'Esta expresión no es un polinomio ni una fracción algebraica, así que se deja indicada. '
          'Pulsa CALC para evaluarla dando un valor a $v.'));
      return StepByStepResolution(
        originalInputLatex: original,
        steps: steps,
        exactResultLatex: original,
        decimalApproxLatex: '',
      );
    }
    var (num, den) = frac;
    String shown(Poly p) => _asVar(PolyOps.latex(p), v);
    if (PolyOps.degree(den) == 0 && den.isNotEmpty) {
      final k = PolyOps.coeff(den, 0);
      num = PolyOps.scale(num, Rational(1) / k);
      den = PolyOps.constant(Rational(1));
    }
    String result;
    if (PolyOps.degree(den) == 0) {
      result = shown(num);
      steps.add(_s(2, 'Desarrollar y reducir términos semejantes', '$original = $result',
          'Quitamos paréntesis, aplicamos las potencias y sumamos los términos semejantes (los que llevan la misma potencia de $v).'));
    } else {
      final (rn, rd, more) = AlgebraicFractionSolver.reduce(num, den, 2);
      steps.addAll([
        for (final m in more)
          MathStep(
            index: m.index,
            shortTitle: m.shortTitle,
            latexExpression: _asVar(m.latexExpression, v),
            pedagogicalNote: m.pedagogicalNote,
            warningTrick: m.warningTrick == null ? null : _asVar(m.warningTrick!, v),
          ),
      ]);
      final unit = PolyOps.degree(rd) == 0 && PolyOps.coeff(rd, 0) == Rational(1);
      result = unit ? shown(rn) : '\\frac{${shown(rn)}}{${shown(rd)}}';
    }
    return StepByStepResolution(
      originalInputLatex: original,
      steps: steps,
      exactResultLatex: result,
      decimalApproxLatex: '',
    );
  }
}
