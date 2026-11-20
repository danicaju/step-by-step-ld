import 'dart:math' as math;

import 'package:casio_tutor_calc/domain/math_engine/functions/function_family_study_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus/sym_build.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_expr.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/exact/ext_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/inequality_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/systems_free/free_system_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/super_equation_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic_derivative_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/symbolic_integral_solver.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_viewport_calculator.dart';
import 'package:casio_tutor_calc/presentation/painters/universal_function_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/exercise_dsl.dart';

XNode _p(String s) => ExtParser().parse(s);

double _f(XNode n, double x) => Sx.numAt(n, x)!;

/// f'(x) simbolica contra diferencia central.
void _derivMatches(String raw, List<double> xs) {
  final f = _p(raw);
  final d = SymbolicDerivativeSolver.differentiate(f).derivative;
  const h = 1e-5;
  for (final x in xs) {
    final numeric = (_f(f, x + h) - _f(f, x - h)) / (2 * h);
    expect((_f(d, x) - numeric).abs(), lessThan(1e-4 * (1 + numeric.abs())),
        reason: "d/dx $raw en x=$x: simbolica ${_f(d, x)} vs numerica $numeric");
  }
  expectCleanNotes(SymbolicDerivativeSolver.derivative(raw));
}

/// F'(x) = f(x) para la primitiva devuelta por el integrador.
void _antiderivMatches(String raw, List<double> xs) {
  final f = _p(raw);
  final big = SymbolicIntegralSolver.antiderivative(f).antiderivative;
  const h = 1e-5;
  for (final x in xs) {
    final numeric = (_f(big, x + h) - _f(big, x - h)) / (2 * h);
    expect((numeric - _f(f, x)).abs(), lessThan(1e-4 * (1 + _f(f, x).abs())),
        reason: "F'($x) de $raw: $numeric vs ${_f(f, x)}");
  }
  expectCleanNotes(SymbolicIntegralSolver.indefinite(raw));
}

StepByStepResolution _def(String raw, int a, int b) =>
    SymbolicIntegralSolver.definite(raw, Rational(a), Rational(b));

void main() {
  group('M12 derivadas de las 8 familias', () {
    test('raiz cubica, log base 2, inversas e hiperbolicas', () {
      _derivMatches('cbrt(x+2)', [-1, 0.5, 3]);
      _derivMatches('log_(2,x)', [0.5, 1, 4]);
      _derivMatches('arctan(2x)', [-1, 0.3, 2]);
      _derivMatches('arcsin(x)', [-0.5, 0.2, 0.7]);
      _derivMatches('sinh(3x)', [-1, 0.2, 0.9]);
      _derivMatches('cosh(x)', [-1, 0.4, 1.3]);
      _derivMatches('tanh(x)', [-1, 0.4, 1.3]);
    });

    test('forma de la raiz n-esima y hiperbolica no cae en log', () {
      final sq = SymbolicDerivativeSolver.derivative('sqrt(x+1)').exactResultLatex;
      expect(sq, contains(r'\sqrt{x + 1}'));
      final cb = SymbolicDerivativeSolver.derivative('cbrt(x+2)').exactResultLatex;
      expect(cb, contains(r'\sqrt[3]'));
      final sh = SymbolicDerivativeSolver.derivative('sinh(x)').exactResultLatex;
      expect(sh, contains(r'\cosh'));
      expect(sh, isNot(contains(r'\ln')));
    });
  });

  group('M12 integrales de las 8 familias', () {
    test('primitivas verificadas por derivacion numerica', () {
      _antiderivMatches('cbrt(x+2)', [-1, 0.5, 3]);
      _antiderivMatches('cosh(2x)', [-1, 0.4, 1.3]);
      _antiderivMatches('sinh(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('tanh(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('arctan(x)', [-1, 0.4, 1.3]);
      _antiderivMatches('arcsin(x)', [-0.5, 0.2, 0.7]);
      _antiderivMatches('1/sqrt(4-x^2)', [-1, 0.4, 1.3]);
      _antiderivMatches('1/(4+x^2)', [-1, 0.4, 1.3]);
      _antiderivMatches('1/cosh(x)^2', [-1, 0.4, 1.3]);
      _antiderivMatches('log_(2,x)', [0.5, 1, 4]);
    });

    test('integrales definidas', () {
      for (final (raw, a, b, expected) in [
        ('cbrt(x+2)', -1, 1, 0.75 * (math.pow(3, 4 / 3) - 1)),
        ('cosh(x)', 0, 1, 1.1752011936438014),
        ('arctan(x)', 0, 1, 0.4388245731174757),
      ]) {
        final r = _def(raw, a, b);
        expectCleanNotes(r);
        final dec = double.parse(r.decimalApproxLatex.replaceAll('{,}', '.').replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), ''));
        expect((dec - expected).abs(), lessThan(1e-4), reason: '$raw -> ${r.decimalApproxLatex}');
      }
    });
  });

  group('M5 estudio y trazado de las 8 familias', () {
    const ejemplos = ['x^3-4x', '1/x', 'cbrt(x+2)', 'e^x', 'ln(x)', 'sin(x)', 'arctan(x)', 'cosh(x)'];

    test('los 8 ejemplos se analizan y se trazan sin NaN ni excepciones', () {
      for (final raw in ejemplos) {
        final fs = FunctionFamilyStudySolver.study(raw);
        expectCleanNotes(fs.result.resolution);
        expect(fs.result.resolution.steps, isNotEmpty, reason: raw);
        final w = GraphViewportCalculator.window(fs.result.model, fs.result.asymptotes, info: fs.info);
        expect(w.width.isFinite && w.height.isFinite && w.width > 0 && w.height > 0, isTrue, reason: raw);
        final branches = UniversalFunctionPainter.branchesFor(fs.result.model, fs.result.asymptotes, w);
        expect(branches, isNotEmpty, reason: raw);
        for (final b in branches) {
          for (final p in b) {
            expect(p.$1.isFinite && p.$2.isFinite, isTrue, reason: '$raw punto $p');
          }
        }
      }
    });

    test('raiz cubica: dominio R y f(-10) = -2; raiz cuadrada: [-2, +inf)', () {
      final c = FunctionFamilyStudySolver.study('cbrt(x+2)');
      expect(c.result.domain.isAllReals, isTrue);
      expect(c.result.model.at(-10), -2);
      expect(c.result.model.at(-3), closeTo(-1, 1e-12));
      expect(c.result.model.at(62), 4); // sin error de redondeo
      final s = FunctionFamilyStudySolver.study('sqrt(x+2)');
      expect(s.result.domain.contains(-2), isTrue);
      expect(s.result.domain.contains(-2.5), isFalse);
      expect(s.result.domain.contains(100), isTrue);
      final r = c.result.model;
      final ramas = UniversalFunctionPainter.branchesFor(r, c.result.asymptotes, const GraphWindow(-8, 8, -4, 4));
      expect(ramas.length, 1); // trazo continuo a ambos lados de x = -2
    });

    test('arcsin y arccos solo existen en [-1, 1]', () {
      for (final raw in ['arcsin(x)', 'arccos(x)']) {
        final fs = FunctionFamilyStudySolver.study(raw);
        expect(fs.result.domain.contains(-1), isTrue, reason: raw);
        expect(fs.result.domain.contains(1), isTrue, reason: raw);
        expect(fs.result.domain.contains(1.01), isFalse, reason: raw);
        expect(fs.result.domain.contains(-1.01), isFalse, reason: raw);
        final w = GraphViewportCalculator.window(fs.result.model, fs.result.asymptotes, info: fs.info);
        final ramas = UniversalFunctionPainter.branchesFor(fs.result.model, fs.result.asymptotes, w);
        for (final b in ramas) {
          expect(b.first.$1, greaterThanOrEqualTo(-1 - 1e-9));
          expect(b.last.$1, lessThanOrEqualTo(1 + 1e-9));
        }
      }
    });

    test('arctan: dominio R y asintotas horizontales exactas en RAD y DEG', () {
      final rad = FunctionFamilyStudySolver.study('arctan(x)');
      expect(rad.result.domain.isAllReals, isTrue);
      final ys = rad.result.asymptotes.horizontal.map((a) => a.n).toList()..sort();
      expect(ys[0], closeTo(-1.5707963267948966, 1e-12));
      expect(ys[1], closeTo(1.5707963267948966, 1e-12));
      expect(rad.result.asymptotes.horizontal.map((a) => a.latex).join(), contains(r'\pi'));
      final deg = FunctionFamilyStudySolver.study('arctan(x)', degrees: true);
      final yd = deg.result.asymptotes.horizontal.map((a) => a.n).toList()..sort();
      expect(yd, [-90.0, 90.0]);
      expect(deg.result.asymptotes.horizontal.map((a) => a.latex).join(), contains('90'));
    });

    test('hiperbolicas: paridad, imagen, minimo de cosh y asintotas de tanh', () {
      final sh = FunctionFamilyStudySolver.study('sinh(x)');
      final shText = lessonText(sh.result.resolution);
      expect(shText, contains('impar'));
      expect(sh.result.asymptotes.horizontal, isEmpty);
      final ch = FunctionFamilyStudySolver.study('cosh(x)');
      final chText = lessonText(ch.result.resolution);
      expect(chText, contains('par'));
      expect(chText, contains(r'\left[1,\,+\infty\right)'));
      expect(chText, contains(r'\left(0,\,1\right)'));
      final th = FunctionFamilyStudySolver.study('tanh(x)');
      final ys = th.result.asymptotes.horizontal.map((a) => a.n).toList()..sort();
      expect(ys, [-1.0, 1.0]);
      for (final fs in [sh, ch, th]) {
        expectCleanNotes(fs.result.resolution);
        expect(fs.result.domain.isAllReals, isTrue);
      }
    });

    test('estudio coherente de polinomica, racional, exponencial, logaritmica con base y trig', () {
      final cub = lessonText(FunctionFamilyStudySolver.study('x^3-4x').result.resolution);
      expect(cub, contains('-2'));
      final rat = FunctionFamilyStudySolver.study('1/x');
      expect(rat.result.asymptotes.vertical.map((a) => a.x), contains(0));
      expect(rat.result.asymptotes.horizontal.map((a) => a.n), contains(0));
      final lg = FunctionFamilyStudySolver.study('log_(2,x)');
      expect(lg.result.model.at(8), closeTo(3, 1e-12));
      expect(lg.result.asymptotes.vertical.map((a) => a.x), contains(0));
      final ex = FunctionFamilyStudySolver.study('e^(-x)');
      expect(lessonText(ex.result.resolution), contains(r'x \to +\infty'));
    });
  });

  group('M2 ecuaciones con las familias nuevas', () {
    String eq(String raw, {AngleUnit angle = AngleUnit.rad}) {
      final r = SuperEquationSolver.solve(raw, angle: angle);
      expectCleanNotes(r);
      expect(r.steps, isNotEmpty);
      return r.exactResultLatex.replaceAll(' ', '');
    }

    test('raices de indice n', () {
      expect(eq('cbrt(x+2)=-2'), 'x=-10');
      expect(eq('root(3,x-1)=2'), 'x=9');
      expect(eq('root(4,x+1)=2'), 'x=15');
      expect(eq('root(4,x+1)=-2'), contains('Sinsolucion'));
    });

    test('trigonometricas inversas con rango', () {
      expect(eq('arctan(x)=pi/4'), 'x=1');
      expect(eq('arctan(x)=45', angle: AngleUnit.deg), 'x=1');
      expect(eq('arctan(x)=1'), contains(r'\tan'));
      expect(eq('arcsin(2x)=pi/6'), r'x=\frac{1}{4}');
      expect(eq('arcsin(x)=2'), contains('Sinsolucion'));
      expect(eq('arccos(x)=pi'), 'x=-1');
    });

    test('hiperbolicas', () {
      expect(eq('cosh(x)=1'), 'x=0');
      expect(eq('cosh(x)=0'), contains('Sinsolucion'));
      expect(eq('cosh(x)=1/2'), contains('Sinsolucion'));
      expect(eq('sinh(x)=0'), 'x=0');
      expect(eq('tanh(x)=0'), 'x=0');
      expect(eq('tanh(x)=2'), contains('Sinsolucion'));
      expect(eq('sinh(x)=3'), contains(r'\ln'));
      expect(eq('cosh(x)=5'), contains(r'\ln'));
      expect(eq('tanh(x)=1/2'), contains(r'\ln'));
    });

    test('identidades y contradicciones', () {
      expect(eq('sin(x)^2+cos(x)^2=1'), contains('Identidad'));
      expect(eq('cosh(x)^2-sinh(x)^2=1'), contains('Identidad'));
      expect(eq('sin(x)^2+cos(x)^2=2'), contains('Sinsolucion'));
      // no se roba una ecuacion normal
      expect(eq('sin(x)=1/2', angle: AngleUnit.deg), isNot(contains('Identidad')));
    });
  });

  group('M6 inecuaciones con las familias nuevas', () {
    String ineq(String raw) {
      final r = InequalitySolver.solveString(raw);
      expectCleanNotes(r);
      expect(r.steps.any((st) => st.showsNumberLine), isTrue, reason: 'recta real: $raw');
      return r.exactResultLatex.replaceAll(' ', '');
    }

    test('raiz cubica no corta el dominio en -2', () {
      expect(ineq('cbrt(x+2)<0'), r'(-\infty,-2)');
      expect(ineq('cbrt(x+2)>1'), r'(-1,+\infty)');
      expect(ineq('cbrt(x+2)>=-2'), r'[-10,+\infty)');
    });

    test('trigonometricas inversas respetan su dominio', () {
      expect(ineq('arcsin(x)>=0'), '[0,1]');
      expect(ineq('arcsin(x)>0'), '(0,1]');
      expect(ineq('arcsin(x)<=0'), '[-1,0]');
      expect(ineq('arctan(x)<=0'), r'(-\infty,0]');
      expect(ineq('arctan(x)>0'), r'(0,+\infty)');
    });

    test('hiperbolicas', () {
      expect(ineq('cosh(x)>=1'), r'(-\infty,+\infty)');
      expect(ineq('cosh(x)>1'), r'(-\infty,0)\cup(0,+\infty)');
      expect(ineq('cosh(x)<1'), r'\emptyset');
      expect(ineq('sinh(x)>0'), r'(0,+\infty)');
      expect(ineq('tanh(x)>=0'), r'[0,+\infty)');
    });
  });

  group('M3 sistemas con las familias nuevas', () {
    String sys(List<String> lhs, List<String> rhs) {
      final r = FreeSystemSolver.solve(lhs, rhs);
      expectCleanNotes(r);
      expect(r.steps, isNotEmpty);
      return r.exactResultLatex.replaceAll(' ', '').replaceAll(r'\left', '').replaceAll(r'\right', '').replaceAll(r'\,', '');
    }

    test('2x2 hiperbolico: cosh(x)+sinh(y)=1, cosh(x)-sinh(y)=1 -> (0, 0)', () {
      expect(sys(['cosh(x)+sinh(y)', 'cosh(x)-sinh(y)'], ['1', '1']), contains('(0,0)'));
    });

    test('2x2 con raiz cubica: cbrt(x)+y=3, x-y=7 -> (8, 1) por cambio de variable', () {
      expect(sys(['cbrt(x)+y', 'x-y'], ['3', '7']), contains('(8,1)'));
      final r = FreeSystemSolver.solve(['cbrt(x)+y', 'x-y'], ['3', '7']);
      final titles = r.steps.map((st) => st.shortTitle).join('|');
      expect(titles, contains('Cambio de variable en los radicales'));
      expect(titles, isNot(contains('Newton')));
      expect(r.exactResultLatex, isNot(contains('{,}')));
      // la raiz impar admite a negativa: x = -8, y = 1
      expect(sys(['cbrt(x)+y', 'x-y'], ['-1', '-9']), contains('(-8,1)'));
    });

    test('2x2 con inversas', () {
      expect(sys(['arctan(x)+y', 'arctan(x)-y'], ['pi/4+1', 'pi/4-1']), contains('(1,1)'));
      expect(sys(['arcsin(x)+tanh(y)', 'arcsin(x)-tanh(y)'], ['pi/2', 'pi/2']), contains('(1,0)'));
    });

    test('3x3 y 4x4 con arctan, cbrt y senh', () {
      final r3 = sys(['arctan(x)+y+z', 'y-z', 'cbrt(z)+x'], ['pi/4+3', '1', '3']);
      expect(r3, isNotEmpty);
      final r4 = sys(['sinh(x)+y+z+w', 'y-z', 'z+w', 'w-x'], ['3', '0', '2', '1']);
      expect(r4, isNotEmpty);
    });
  });
}
