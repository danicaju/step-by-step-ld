import 'dart:math';

import '../core/calculator_settings.dart';
import '../models/step_resolution.dart';

/// Constante fisica del catalogo CONST (valores CODATA 2019).
class PhysicalConstant {
  final String token; // `&c`, `&NA`...
  final String plain; // simbolo en texto plano (menu LCD)
  final String latex; // simbolo en LaTeX
  final String name;
  final double value;
  final String unitLatex;

  const PhysicalConstant(this.token, this.plain, this.latex, this.name, this.value, this.unitLatex);
}

/// Catalogo CONST y evaluador `double` de expresiones con constantes.
///
/// Los valores (6.6e-34, 6.0e23...) desbordan el `Rational` entero del motor
/// exacto, por eso las expresiones con constantes se evaluan en `double`.
class ClassWizConstants {
  const ClassWizConstants._();

  static const List<PhysicalConstant> all = [
    PhysicalConstant('&c', 'c', 'c', 'Velocidad de la luz', 299792458, r'\mathrm{m/s}'),
    PhysicalConstant('&g', 'g', 'g', 'Gravedad estandar', 9.80665, r'\mathrm{m/s^{2}}'),
    PhysicalConstant('&G', 'G', 'G', 'Constante gravitatoria', 6.6743e-11, r'\mathrm{m^{3}/(kg\,s^{2})}'),
    PhysicalConstant('&h', 'h', 'h', 'Constante de Planck', 6.62607015e-34, r'\mathrm{J\,s}'),
    PhysicalConstant('&NA', 'N_A', 'N_{A}', 'Numero de Avogadro', 6.02214076e23, r'\mathrm{mol^{-1}}'),
    PhysicalConstant('&R', 'R', 'R', 'Constante de los gases', 8.314462618, r'\mathrm{J/(mol\,K)}'),
    PhysicalConstant('&e', 'e', 'e', 'Carga elemental', 1.602176634e-19, r'\mathrm{C}'),
    PhysicalConstant('&me', 'm_e', 'm_{e}', 'Masa del electron', 9.1093837015e-31, r'\mathrm{kg}'),
    PhysicalConstant('&mp', 'm_p', 'm_{p}', 'Masa del proton', 1.67262192369e-27, r'\mathrm{kg}'),
    PhysicalConstant('&e0', 'ε₀', r'\varepsilon_{0}', 'Permitividad del vacio', 8.8541878128e-12, r'\mathrm{F/m}'),
    PhysicalConstant('&u0', 'µ₀', r'\mu_{0}', 'Permeabilidad del vacio', 1.25663706212e-6, r'\mathrm{N/A^{2}}'),
  ];

  /// Tokens de mayor a menor longitud (`&e0` antes que `&e`).
  static final RegExp tokenRe = RegExp(r'&(NA|me|mp|e0|u0|c|g|G|h|R|e)');

  static PhysicalConstant? byToken(String token) {
    for (final c in all) {
      if (c.token == token) return c;
    }
    return null;
  }

  /// Valor en texto plano compacto (`6.62607015e-34`).
  static String plainValue(double v) {
    var m = v.toStringAsExponential(9).replaceFirst(RegExp(r'0+e'), 'e').replaceFirst('.e', 'e');
    return m.replaceFirst('e+', 'e');
  }

  static bool containsConstants(String s) => tokenRe.hasMatch(s);

  /// Numero `double` como `m \times 10^{e}` (o decimal llano si es moderado).
  static String sciLatex(double v) {
    if (v == 0) return '0';
    final e = (log(v.abs()) / ln10).floor();
    String sep(String s) => CalculatorSettings.decimalComma ? s.replaceAll('.', ',') : s;
    if (e >= -3 && e <= 6) {
      var t = v.toStringAsFixed(max(0, 9 - e.clamp(0, 9)));
      if (t.contains('.')) {
        t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      }
      return sep(t);
    }
    var m = (v / pow(10, e)).toStringAsFixed(8);
    m = m.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return '${sep(m)} \\times 10^{$e}';
  }

  /// Evalua `+ - * / : ^`, parentesis, `π`, `ANS` y constantes `&x`.
  static double evaluate(String expr, {double ans = 0}) {
    final p = _Parser(expr.replaceAll(' ', ''), ans);
    final v = p.parseExpr();
    if (!p.atEnd) throw const FormatException('Expresion con constantes no valida');
    return v;
  }

  /// Resolucion paso a paso de una expresion con constantes.
  static StepByStepResolution solve(String expr, {double ans = 0}) {
    final value = evaluate(expr, ans: ans);
    if (value.isNaN || value.isInfinite) throw const FormatException('Math ERROR');
    final used = <PhysicalConstant>{
      for (final m in tokenRe.allMatches(expr)) byToken(m.group(0)!)!,
    };
    final subst = used.map((c) => '${c.latex} = ${sciLatex(c.value)}\\;${c.unitLatex}').join(r',\; ');
    final result = sciLatex(value);
    return StepByStepResolution(
      originalInputLatex: expr.replaceAllMapped(tokenRe, (m) => byToken(m.group(0)!)!.latex),
      steps: [
        MathStep(
          index: 1,
          shortTitle: 'Constantes fisicas',
          latexExpression: subst,
          pedagogicalNote: 'Sustituimos cada simbolo por su valor CODATA 2019.',
        ),
        MathStep(
          index: 2,
          shortTitle: 'Resultado numerico',
          latexExpression: '= $result',
          pedagogicalNote: 'El resultado se da en notacion cientifica aproximada.',
        ),
      ],
      exactResultLatex: result,
      decimalApproxLatex: result,
    );
  }
}

class _Parser {
  final String s;
  final double ans;
  int i = 0;
  _Parser(this.s, this.ans);

  bool get atEnd => i >= s.length;
  String get cur => s[i];

  double parseExpr() {
    var v = parseTerm();
    while (!atEnd && (cur == '+' || cur == '-')) {
      final op = s[i++];
      final r = parseTerm();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double parseTerm() {
    var v = parsePow();
    while (!atEnd) {
      if (cur == '*' || cur == '/' || cur == ':') {
        final op = s[i++];
        final r = parsePow();
        v = op == '*' ? v * r : v / r;
      } else if (cur == '(' || cur == '&' || cur == 'π' || s.startsWith('ANS', i)) {
        v *= parsePow();
      } else {
        break;
      }
    }
    return v;
  }

  double parsePow() {
    final b = parseUnary();
    if (!atEnd && cur == '^') {
      i++;
      return pow(b, parsePow()).toDouble();
    }
    return b;
  }

  double parseUnary() {
    if (!atEnd && cur == '-') {
      i++;
      return -parseUnary();
    }
    if (!atEnd && cur == '+') {
      i++;
      return parseUnary();
    }
    return parseAtom();
  }

  double parseAtom() {
    if (atEnd) throw const FormatException('Expresion incompleta');
    if (cur == '(') {
      i++;
      final v = parseExpr();
      if (!atEnd && cur == ')') i++;
      return v;
    }
    if (cur == 'π') {
      i++;
      return pi;
    }
    if (s.startsWith('ANS', i)) {
      i += 3;
      return ans;
    }
    if (cur == '&') {
      final m = ClassWizConstants.tokenRe.matchAsPrefix(s, i);
      if (m == null) throw const FormatException('Constante desconocida');
      i += m.group(0)!.length;
      return ClassWizConstants.byToken(m.group(0)!)!.value;
    }
    final m = RegExp(r'\d+(\.\d+)?|\.\d+').matchAsPrefix(s, i);
    if (m == null) throw FormatException('Simbolo inesperado: ${s[i]}');
    i += m.group(0)!.length;
    return double.parse(m.group(0)!);
  }
}
