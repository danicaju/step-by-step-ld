import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/super_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/system_3x3_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/ruffini_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/function_graph_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_inequality_2d_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/statistics_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/vector_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/utils/latex_plain_text.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

/// Auditoría profunda: casos borde reales de los 12 modos + lint de LaTeX.
final List<String> failures = [];

// ---------------------------------------------------------------------------
// Lint de LaTeX / textos
// ---------------------------------------------------------------------------
final RegExp _textBlock = RegExp(r'\\(?:text|mathrm|textbf|mathbf)\{([^{}]*)\}');
final RegExp _nonAscii = RegExp(r'[^\x00-\x7F]');
final RegExp _unbracedScript = RegExp(r'[_^](?:[0-9]{2}|[A-Za-z]{2}|[α-ωΑ-Ω])');
final RegExp _dirtySign = RegExp(r'\+\s*-|-\s*-|\+\s*\+|(?:^|[^0-9.\\A-Za-z{])1[a-z](?![a-z])');
final RegExp _rawLatexInPlainText = RegExp(r'\\(?:frac|sqrt|cdot|text|begin|end|left|right|boxed|textcolor)\b');

void lintLatex(String label, String latex) {
  if (latex.contains('\r')) failures.add('[$label] contiene \\r: $latex');
  for (final m in _textBlock.allMatches(latex)) {
    if (_nonAscii.hasMatch(m.group(1)!)) {
      failures.add('[$label] tilde/eñe dentro de \\text/\\mathrm: ${m.group(0)}');
    }
  }
  // Se ignoran los bloques \text{...} para no marcar "x_y" de texto literal.
  final mathOnly = latex.replaceAll(_textBlock, '');
  final script = _unbracedScript.firstMatch(mathOnly);
  if (script != null) failures.add('[$label] sub/superíndice sin llaves "${script.group(0)}" en: $latex');
  final dirty = _dirtySign.firstMatch(mathOnly);
  if (dirty != null) failures.add('[$label] signo sucio "${dirty.group(0)}" en: $latex');
  final sanitized = CasioLcdScreen.sanitizeForMathTex(latex);
  try {
    SyntaxTree(greenRoot: TexParser(sanitized, const TexParserSettings()).parse())
        .buildWidget(MathOptions(style: MathStyle.display, fontSize: 20));
  } catch (e) {
    failures.add('[$label] KaTeX falla: $latex -> $e');
  }
}

void lintPlain(String label, String text) {
  // La UI pinta estos textos con Text() pasando por LatexPlainText.toPlain.
  final shown = LatexPlainText.toPlain(text);
  if (_rawLatexInPlainText.hasMatch(shown) || shown.contains('\\')) {
    failures.add('[$label] LaTeX crudo visible en texto plano: $shown');
  }
}

void lintResolution(String label, StepByStepResolution res) {
  lintLatex('$label.original', res.originalInputLatex);
  lintLatex('$label.exact', res.exactResultLatex);
  if (res.decimalApproxLatex.isNotEmpty) lintLatex('$label.decimal', res.decimalApproxLatex);
  for (var i = 0; i < res.steps.length; i++) {
    final s = res.steps[i];
    lintLatex('$label.step[$i]', s.latexExpression);
    lintPlain('$label.step[$i].title', s.shortTitle);
    lintPlain('$label.step[$i].note', s.pedagogicalNote);
    if (s.warningTrick != null) lintPlain('$label.step[$i].trick', s.warningTrick!);
  }
}

/// Ejecuta [body]. Aceptamos resolución o error de entrada controlado
/// (FormatException/ArgumentError/StateError); cualquier otro error es bug.
StepByStepResolution? attempt(String label, StepByStepResolution Function() body, {bool mustSucceed = false}) {
  try {
    final res = body();
    lintResolution(label, res);
    return res;
  } on FormatException catch (_) {
    if (mustSucceed) failures.add('[$label] lanzó FormatException inesperada');
  } on ArgumentError catch (_) {
    if (mustSucceed) failures.add('[$label] lanzó ArgumentError inesperado');
  } on StateError catch (_) {
    if (mustSucceed) failures.add('[$label] lanzó StateError inesperado');
  } catch (e, st) {
    failures.add('[$label] excepción NO controlada ${e.runtimeType}: $e\n$st');
  }
  return null;
}

StepByStepResolution evalExpr(String expr) {
  final ast = ExpressionParser().parse(ExpressionParser.finalizeForEvaluation(expr));
  return StepEvaluator().evaluate(ast);
}

void expectResult(String label, StepByStepResolution? res, String contains_) {
  if (res == null) {
    failures.add('[$label] sin resolución (esperaba "$contains_")');
  } else if (!res.exactResultLatex.contains(contains_)) {
    failures.add('[$label] resultado "${res.exactResultLatex}" no contiene "$contains_"');
  }
}

void main() {
  setUp(failures.clear);

  test('M1 Calcular: jerarquía, trigonometría anidada, división por cero y entradas vacías', () {
    expectResult('-3^2', attempt('-3^2', () => evalExpr('-3^2'), mustSucceed: true), '-9');
    expectResult('(-3)^2', attempt('(-3)^2', () => evalExpr('(-3)^2'), mustSucceed: true), '9');
    expectResult('2+3*4', attempt('2+3*4', () => evalExpr('2+3*4'), mustSucceed: true), '14');
    attempt(r'sin(sqrt(cos(0)))', () => evalExpr('sin(√(cos(0)))'));
    attempt('sin(cos(tan(45)))', () => evalExpr('sin(cos(tan(45)))'));
    attempt('log_(2,8)+1', () => evalExpr('log_(2,8)+1'));
    attempt('5/0', () => evalExpr('5/0'));
    attempt('0/0', () => evalExpr('0/0'));
    attempt('1/(2-2)', () => evalExpr('1/(2-2)'));
    attempt('tan(90)', () => evalExpr('tan(90)'));
    attempt('√(-4)', () => evalExpr('√(-4)'));
    attempt('ln(0)', () => evalExpr('ln(0)'));
    attempt('0^0', () => evalExpr('0^0'));
    attempt('2^(-3)', () => evalExpr('2^(-3)'));
    attempt('(((', () => evalExpr('((('));
    attempt('vacío', () => evalExpr(''));
    attempt('espacios', () => evalExpr('   '));
    attempt('mcm(12,18,24)', () => evalExpr('mcm(12,18,24)'));
    attempt('mcd(0,0)', () => evalExpr('mcd(0,0)'));
    attempt('√(72)+³√(27)', () => evalExpr('√(72)+³√(27)'));
    attempt('4/6+2/3', () => evalExpr('4/6+2/3'));
    attempt('1/3+1/6-1/2', () => evalExpr('1/3+1/6-1/2'));
    attempt('9999999999^9', () => evalExpr('9999999999^9'));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M1 D-Pad: navegar dentro y fuera de log_(2,8)+1 sin saltos ni bloqueos', () {
    for (final raw in ['log_(2,8)+1', 'root(3,27)+2', '√(16)+1', '(1+2)/3', '2^(3)+1', 'sin(30)+cos(60)']) {
      var pos = 0;
      final seen = <int>[];
      for (var i = 0; i < raw.length * 3 + 4; i++) {
        // Mismo orden de prioridad que calculator_screen_dpad.dart
        final special = ExpressionParser.handleFractionRightArrow(raw, pos) ??
            ExpressionParser.handlePowerRightArrow(raw, pos) ??
            ExpressionParser.handleMcmMcdRightArrow(raw, pos) ??
            ExpressionParser.handleTwoSlotRightArrow(raw, pos) ??
            ExpressionParser.handleStructuredBlockRightArrow(raw, pos);
        var next = special != null && special.$1 == raw
            ? special.$2
            : ExpressionParser.stepCursorRight(raw, pos);
        if (next < pos) failures.add('[dpad▶ $raw] retrocede de $pos a $next');
        if (next < 0 || next > raw.length) failures.add('[dpad▶ $raw] cursor fuera de rango: $next');
        seen.add(next);
        lintLatex('dpad▶ $raw@$next', ExpressionParser.rawToLiveLatex(raw, cursorPos: next.clamp(0, raw.length)));
        if (next == pos && pos == raw.length) break;
        pos = next;
      }
      if (pos != raw.length) failures.add('[dpad▶ $raw] no alcanza el final (queda en $pos, pasos $seen)');
      for (var i = 0; i < raw.length * 3 + 4 && pos > 0; i++) {
        var prev = ExpressionParser.stepCursorLeft(raw, pos);
        final slot = ExpressionParser.handleTwoSlotLeftArrow(raw, pos);
        if (slot != null && slot.$1 == raw) prev = slot.$2;
        if (prev > pos) failures.add('[dpad◀ $raw] avanza de $pos a $prev');
        if (prev == pos) break;
        pos = prev;
      }
      if (pos != 0) failures.add('[dpad◀ $raw] no regresa al inicio (queda en $pos)');
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M2 Ecuaciones: desordenadas, irracionales con raíces falsas, sin solución e infinitas', () {
    attempt('3x-5=7-x', () => LinearEquationSolver.solveEquationString('3x - 5 = 7 - x'), mustSucceed: true);
    attempt('7=3x-5 (desordenada)', () => LinearEquationSolver.solveEquationString('7 = 3x - 5'));
    attempt('x+1=x', () => LinearEquationSolver.solveEquationString('x + 1 = x'));
    attempt('2x+4=2x+4', () => LinearEquationSolver.solveEquationString('2x + 4 = 2x + 4'));
    attempt('0x=5', () => LinearEquationSolver.solveEquationString('0x = 5'));
    attempt('=', () => LinearEquationSolver.solveEquationString('='));
    attempt('x=', () => LinearEquationSolver.solveEquationString('x ='));
    attempt('vacía', () => LinearEquationSolver.solveEquationString(''));
    attempt('(x-2)/3-(x+1)/4=2', () => LinearEquationSolver.solveEquationString('(x-2)/3 - (x+1)/4 = 2'));
    attempt('x/0=1', () => LinearEquationSolver.solveEquationString('x/0 = 1'));
    attempt(r'sqrt(x+2)=x (raíz falsa)', () => SuperEquationSolver.solve(r'\sqrt{x+2}=x'));
    attempt(r'sqrt(2x-1)=x-2 (falsa)', () => SuperEquationSolver.solve(r'\sqrt{2x-1}=x-2'));
    attempt(r'sqrt(x)=-3 (sin solución)', () => SuperEquationSolver.solve(r'\sqrt{x}=-3'));
    attempt('x^4-5x^2+4=0', () => SuperEquationSolver.solve('x^4-5x^2+4=0'));
    attempt('x^4+x^2+1=0', () => SuperEquationSolver.solve('x^4+x^2+1=0'));
    attempt('1/x=0', () => SuperEquationSolver.solve('1/x=0'));
    attempt('1/(x-1)=2/(x^2-1)', () => SuperEquationSolver.solve(r'\frac{1}{x-1}=\frac{2}{x^2-1}'));
    attempt('2^x=8', () => SuperEquationSolver.solve('2^x=8'));
    attempt('log(x)=-1', () => SuperEquationSolver.solve('log(x)=-1'));
    attempt('x^2-5x+6=0', () => PolynomialEquationSolver.solveEquationString('x^2-5x+6=0'));
    attempt('x^3-6x^2+11x-6=0', () => PolynomialEquationSolver.solveEquationString('x^3-6x^2+11x-6=0'));
    attempt('x^2+1=0', () => PolynomialEquationSolver.solveEquationString('x^2+1=0'));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M3 Sistemas 2x2 / 3x3: compatibles, incompatibles, indeterminados y degenerados', () {
    for (final method in SystemResolutionMethod.values) {
      attempt('2x2 único $method', () => LinearSystemSolver.solve(a1: 2, b1: 1, c1: 5, a2: 1, b2: -1, c2: 1, method: method), mustSucceed: true);
      attempt('2x2 incompatible $method', () => LinearSystemSolver.solve(a1: 1, b1: 1, c1: 2, a2: 1, b2: 1, c2: 5, method: method), mustSucceed: true);
      attempt('2x2 indeterminado $method', () => LinearSystemSolver.solve(a1: 1, b1: 1, c1: 2, a2: 2, b2: 2, c2: 4, method: method), mustSucceed: true);
      attempt('2x2 todo ceros $method', () => LinearSystemSolver.solve(a1: 0, b1: 0, c1: 0, a2: 0, b2: 0, c2: 0, method: method));
      attempt('2x2 0=5 $method', () => LinearSystemSolver.solve(a1: 0, b1: 0, c1: 5, a2: 1, b2: 1, c2: 1, method: method));
      attempt('2x2 coef cero en a1 $method', () => LinearSystemSolver.solve(a1: 0, b1: 3, c1: 6, a2: 2, b2: 0, c2: 4, method: method), mustSucceed: true);
    }
    final cases = <String, List<List<int>>>{
      'único': [[2, 4, 2, 3], [4, -4, 2, 10], [2, 8, -2, -10]],
      'indeterminado': [[1, 1, 1, 6], [2, 2, 2, 12], [1, 2, 3, 14]],
      'incompatible': [[1, 1, 1, 6], [2, 2, 2, 10], [1, -1, 1, 2]],
      'todo ceros': [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]],
      'fila 0=1': [[0, 0, 0, 1], [1, 0, 0, 1], [0, 1, 0, 1]],
      'pivote cero': [[0, 1, 1, 2], [1, 0, 1, 2], [1, 1, 0, 2]],
    };
    for (final e in cases.entries) {
      for (final m in System3x3Method.values) {
        attempt('3x3 ${e.key} $m', () => System3x3Solver.solveFromInts(augmentedRows: e.value, method: m), mustSucceed: true);
      }
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M4 Polinomios / Ruffini: incompleto, sin raíces enteras, constantes y ceros', () {
    for (final coeffs in <List<int>>[
      [1, 0, -4, 0],
      [1, 0, 0, 0, -1],
      [1, 0, 1],
      [2, -3, 1],
      [1, -6, 11, -6],
      [1, 0, 0, 0, 0, 0, -1],
      [0, 0, 5],
      [5],
      [1, 0],
      [0, 0, 0],
      [1, -3, 0, 0, 0, 0],
      [6, -5, 1],
      [1, 1, 1, 1, 1, 1, 1],
    ]) {
      attempt('ruffini$coeffs', () => RuffiniSolver.factorize(coeffs));
    }
    attempt('ruffini vacío', () => RuffiniSolver.factorize(const []));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M5 Estudio de funciones: parábolas degeneradas, rectas y tabla de valores', () {
    for (final abc in <List<int>>[
      [1, -2, -3], [-1, 4, -4], [1, 0, 2], [2, 1, 0], [100, 0, 0], [1, 0, 0], [-2, 0, 8], [0, 1, 1],
    ]) {
      late final FunctionAnalysisResult r;
      try {
        r = FunctionGraphSolver.analyzeQuadratic(a: abc[0], b: abc[1], c: abc[2]);
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      }
      lintResolution('quad$abc', r.resolution);
      for (final row in r.samplePoints) {
        if (!row.y.isFinite) failures.add('[tabla quad$abc] y no finita en x=${row.x}');
        lintLatex('tabla quad$abc.x', row.xLatex);
        lintLatex('tabla quad$abc.y', row.yLatex);
      }
    }
    for (final mn in <List<int>>[[2, -4], [0, 5], [-1, 0], [0, 0], [3, 2]]) {
      final r = FunctionGraphSolver.analyzeLinear(m: mn[0], n: mn[1]);
      lintResolution('lin$mn', r.resolution);
      for (final row in r.samplePoints) {
        if (!row.y.isFinite) failures.add('[tabla lin$mn] y no finita');
        lintLatex('tabla lin$mn.y', row.yLatex);
      }
    }
    // Asíntota: la evaluación 1/x en x=0 no debe reventar.
    attempt('tabla 1/x en 0 (asíntota)', () => evalExpr('1/0'));
    attempt('tabla 1/(x-2) en 2', () => evalExpr('1/(2-2)'));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M6 Inecuaciones 1D: lineales, cuadráticas, valor absoluto, vacías y todo R', () {
    for (final s in [
      '-2x+4<10', '2x+1>2x', '2x+1<2x', '0x<5', 'x^2-4x+3<=0', 'x^2+1<0', 'x^2+1>0', 'x^2<=0', 'x^2>0',
      '-x^2+4x-4>=0', '|x-2|<3', '|x-2|>3', '|x|<0', '|x|>=0', '(x-2)/(x+1)>0', 'x/0>1', '', '<', 'x<', '3<x<5',
      '5<x<3',
    ]) {
      attempt('ineq($s)', () => InequalitySolver.solveString(s));
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M7 Sistemas de inecuaciones 1D/2D: acotadas, no acotadas y vacías', () {
    final sets2d = <String, List<String>>{
      'triángulo acotado': ['x>=0', 'y>=0', 'x+y<=4'],
      'cuadrilátero': ['x>=0', 'y>=0', 'x<=3', 'y<=2'],
      'no acotada': ['x>=0', 'y>=0'],
      'semiplano': ['x+y<=4'],
      'vacía': ['x>=3', 'x<=1'],
      'vacía oblicua': ['x+y>=5', 'x+y<=2'],
      'franja paralela': ['x+y>=0', 'x+y<=2'],
      'recta degenerada': ['x+y>=2', 'x+y<=2'],
      'punto': ['x>=0', 'y>=0', 'x+y<=0'],
      'coef cero': ['0x+0y<=1'],
      'imposible 0<=-1': ['0x+0y<=-1'],
      'vacío': [],
      'basura': ['abc', '???'],
      'estricta': ['x>0', 'y>0', 'x+y<4'],
      'coef decimales': ['0.5x+0.25y<=3', 'x>=0', 'y>=0'],
    };
    for (final e in sets2d.entries) {
      attempt('2D ${e.key}', () => LinearInequality2DSolver.solveSystem2D(e.value).resolution);
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M8 Estadística 1 variable: datos vacíos, un dato, frecuencias grandes y repetidos', () {
    StatDataPoint p(int v, int f) => StatDataPoint(Rational(v), f);
    final sets = <String, List<StatDataPoint>>{
      'vacío': [],
      'un dato': [p(5, 1)],
      'constante': [p(3, 4)],
      'normal': [p(2, 1), p(4, 2), p(6, 1)],
      'frec grande': [p(1, 1000000), p(2, 1)],
      'negativos': [p(-3, 2), p(0, 1), p(3, 2)],
      'frec cero': [p(1, 0), p(2, 0)],
      'moda múltiple': [p(1, 2), p(2, 2), p(3, 2)],
    };
    for (final e in sets.entries) {
      attempt('stats ${e.key}', () => StatisticsOneVarSolver.solve(e.value));
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M9 Matrices: rectangulares 4x1, singulares, 1x1 y operaciones incompatibles', () {
    final m4x1 = RationalMatrix.fromInts([[1], [2], [3], [4]]);
    final m1x4 = RationalMatrix.fromInts([[1, 2, 3, 4]]);
    final m2x3 = RationalMatrix.fromInts([[1, 2, 3], [4, 5, 6]]);
    final m1x1 = RationalMatrix.fromInts([[7]]);
    final sing2 = RationalMatrix.fromInts([[1, 2], [2, 4]]);
    final sing3 = RationalMatrix.fromInts([[1, 2, 3], [4, 5, 6], [7, 8, 9]]);
    final id2 = RationalMatrix.fromInts([[1, 0], [0, 1]]);
    final m4x4 = RationalMatrix.fromInts([[1, 0, 2, -1], [3, 0, 0, 5], [2, 1, 4, -3], [1, 0, 5, 0]]);
    final zero2 = RationalMatrix.fromInts([[0, 0], [0, 0]]);
    final all = <String, RationalMatrix>{
      '4x1': m4x1, '1x4': m1x4, '2x3': m2x3, '1x1': m1x1, 'sing2': sing2, 'sing3': sing3, 'id2': id2, '4x4': m4x4, 'zero2': zero2,
    };
    for (final e in all.entries) {
      attempt('det ${e.key}', () => MatrixSolver.determinant(e.value));
      attempt('inv ${e.key}', () => MatrixSolver.inverse(e.value));
      attempt('adj ${e.key}', () => MatrixSolver.adjoint(e.value));
      attempt('trans ${e.key}', () => MatrixSolver.transpose(e.value));
      attempt('gauss ${e.key}', () => MatrixSolver.gauss(e.value));
      attempt('k*${e.key}', () => MatrixSolver.scalarMultiply(Rational(-3, 2), e.value));
      attempt('k=0 ${e.key}', () => MatrixSolver.scalarMultiply(Rational(0), e.value));
    }
    attempt('4x1 * 1x4', () => MatrixSolver.multiply(m4x1, m1x4));
    attempt('1x4 * 4x1', () => MatrixSolver.multiply(m1x4, m4x1));
    attempt('2x3 * 4x1 (incompatible)', () => MatrixSolver.multiply(m2x3, m4x1));
    attempt('4x1 + 1x4 (incompatible)', () => MatrixSolver.add(m4x1, m1x4));
    attempt('2x3 - 2x3', () => MatrixSolver.subtract(m2x3, m2x3));
    attempt('cramer sing', () => MatrixSolver.cramer(sing2, RationalMatrix.fromInts([[1], [2]])));
    attempt('cramer 2x2', () => MatrixSolver.cramer(id2, RationalMatrix.fromInts([[1], [2]])));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M10 Vectores 2D/3D: nulos, paralelos, ortogonales y dimensiones mezcladas', () {
    final z3 = RationalVector.fromInts([0, 0, 0]);
    final z2 = RationalVector.fromInts([0, 0]);
    final u3 = RationalVector.fromInts([1, 2, 3]);
    final v3 = RationalVector.fromInts([2, 4, 6]);
    final o3 = RationalVector.fromInts([1, 2, -1]);
    final w3 = RationalVector.fromInts([2, 0, 2]);
    final u2 = RationalVector.fromInts([3, 4]);
    final v2 = RationalVector.fromInts([-4, 3]);
    final pairs = <String, List<RationalVector>>{
      'nulo-3d': [z3, u3], 'nulo-2d': [z2, u2], 'paralelos': [u3, v3], 'ortogonales': [o3, w3],
      '2d ortog': [u2, v2], 'mezcla 2d-3d': [u2, u3], 'mismo': [u3, u3],
    };
    for (final e in pairs.entries) {
      attempt('mod ${e.key}', () => VectorSolver.modulus(e.value[0]));
      attempt('dot ${e.key}', () => VectorSolver.dotProductAndAngle(e.value[0], e.value[1]));
      attempt('cross ${e.key}', () => VectorSolver.crossProductAndArea(e.value[0], e.value[1]));
      attempt('add ${e.key}', () => VectorSolver.add(e.value[0], e.value[1]));
      attempt('sub ${e.key}', () => VectorSolver.subtract(e.value[0], e.value[1]));
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M11 Complejos: i puro, reales, división por 0, ángulos en cada cuadrante', () {
    RationalComplex c(int a, int b) => RationalComplex.fromInts(a, b);
    final list = [c(0, 0), c(1, 0), c(0, 1), c(0, -1), c(-1, 0), c(1, 1), c(-3, 3), c(-1, -1), c(3, -4), c(0, 5)];
    for (final a in list) {
      attempt('polar $a', () => ComplexSolver.toPolar(a));
      for (final b in list) {
        attempt('add $a $b', () => ComplexSolver.add(a, b));
        attempt('sub $a $b', () => ComplexSolver.subtract(a, b));
        attempt('mul $a $b', () => ComplexSolver.multiply(a, b));
        attempt('div $a $b', () => ComplexSolver.divide(a, b));
      }
    }
    for (final ang in [0.0, 30.0, 90.0, 180.0, 270.0, 360.0, -45.0, 720.0, 45.5]) {
      for (final mod in [0, 1, 2]) {
        attempt('fromPolar r=$mod α=$ang', () => ComplexSolver.fromPolar(modulus: Rational(mod), angleDegrees: ang));
      }
    }
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('M12 Derivadas e integrales: constantes, cero, negativos, límites iguales/invertidos', () {
    for (final poly in ['x^3-3x^2+2', '7', '0', 'x', '-x', '-x^2-2x', '3x^2', 'x^10', '1/2x', '0.5x^2', '']) {
      attempt('deriv($poly)', () => CalculusSolver.derivative(RationalPolynomial.parseExpression(poly)));
      attempt('int($poly)', () => CalculusSolver.indefiniteIntegral(RationalPolynomial.parseExpression(poly)));
      attempt('tangente($poly,x0=0)', () => CalculusSolver.tangentLine(RationalPolynomial.parseExpression(poly), Rational(0)));
      attempt('tangente($poly,x0=-2)', () => CalculusSolver.tangentLine(RationalPolynomial.parseExpression(poly), Rational(-2)));
    }
    final p = RationalPolynomial.parseExpression('3x^2');
    attempt('barrow 0..2', () => CalculusSolver.definiteIntegralBarrow(p, Rational(0), Rational(2)));
    attempt('barrow 2..2', () => CalculusSolver.definiteIntegralBarrow(p, Rational(2), Rational(2)));
    attempt('barrow 2..0', () => CalculusSolver.definiteIntegralBarrow(p, Rational(2), Rational(0)));
    attempt('barrow -3..3', () => CalculusSolver.definiteIntegralBarrow(p, Rational(-3), Rational(3)));
    attempt('barrow 1/2..3/2', () => CalculusSolver.definiteIntegralBarrow(p, Rational(1, 2), Rational(3, 2)));
    if (failures.isNotEmpty) fail(failures.join('\n'));
  });

  test('LatexPlainText convierte LaTeX de notas a texto legible', () {
    expect(LatexPlainText.toPlain(r'k = -\frac{3}{2}'), 'k = -3/2');
    expect(LatexPlainText.toPlain(r'así que \sqrt{14} es exacto'), 'así que √(14) es exacto');
    expect(LatexPlainText.toPlain(r'u_{x} \cdot v_{z}'), 'u_x · v_z');
    expect(LatexPlainText.toPlain(r'Adj(A) = \left(\begin{array}{cc} 1 & 0 \\ 0 & 1 \end{array}\right).'), 'Adj(A) = ([1 0; 0 1]).');
    expect(LatexPlainText.toPlain('texto sin latex'), 'texto sin latex');
  });

  testWidgets('SHIFT + 0 inserta π y SHIFT + ANS ejecuta M+ (leyendas coherentes)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHIFT'));
    await tester.pumpAndSettle();
    expect(find.text('π'), findsWidgets);
    expect(find.text('M+'), findsWidgets);
    await tester.tap(find.widgetWithText(CasioPhysicalKey, 'π').first);
    await tester.pumpAndSettle();
    final lcd = tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen));
    expect(lcd.currentInputLatex, contains(r'\pi'));
    expect(tester.takeException(), isNull);
  });

  group('Layout responsivo: 12 modos sin RenderFlex overflow', () {
    const sizes = <String, Size>{'móvil 360x800': Size(360, 800), 'apaisado 900x500': Size(900, 500)};

    for (final sizeEntry in sizes.entries) {
      testWidgets('${sizeEntry.key}: arranque, menú y los 12 modos', (tester) async {
        await tester.binding.setSurfaceSize(sizeEntry.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'arranque ${sizeEntry.key}');

        for (var mode = 1; mode <= 12; mode++) {
          await tester.tap(find.text('MODE'));
          await tester.pumpAndSettle();
          // El menú recuerda la última página (y es cíclico): avanzamos hasta ver el modo.
          for (var guard = 0; guard < 4 && find.byKey(Key('menu_mode_$mode')).evaluate().isEmpty; guard++) {
            await tester.tap(find.byKey(const Key('menu_page_next')));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: 'menú página ${(mode - 1) ~/ 4 + 1} ${sizeEntry.key}');
          await tester.tap(find.byKey(Key('menu_mode_$mode')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'M$mode ${sizeEntry.key} al entrar');

          // Escribir y navegar con el D-Pad sin desbordar.
          for (final k in ['7', '=', '1', '=']) {
            final finder = find.text(k);
            if (finder.evaluate().isNotEmpty) {
              await tester.tap(finder.first, warnIfMissed: false);
              await tester.pumpAndSettle();
            }
          }
          for (final icon in [Icons.arrow_left_rounded, Icons.arrow_right_rounded, Icons.arrow_drop_up_rounded, Icons.arrow_drop_down_rounded]) {
            final f = find.byIcon(icon);
            if (f.evaluate().isNotEmpty) {
              await tester.tap(f.first, warnIfMissed: false);
              await tester.pumpAndSettle();
            }
          }
          expect(tester.takeException(), isNull, reason: 'M$mode ${sizeEntry.key} tras teclear y D-Pad');
        }
      });
    }
  });
}
