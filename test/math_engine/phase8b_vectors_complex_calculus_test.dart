import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/calculus_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/complex_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/vector_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/utils/goodnotes_exporter.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_calculus_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_complex_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_vector_editor_view.dart';

void _expectAllLatexValid(StepByStepResolution res) {
  final all = <String>[
    res.originalInputLatex,
    res.exactResultLatex,
    if (res.decimalApproxLatex.isNotEmpty) res.decimalApproxLatex,
    ...res.steps.map((s) => s.latexExpression),
  ];
  for (final raw in all) {
    final sanitized = CasioLcdScreen.sanitizeForMathTex(raw);
    final ast = SyntaxTree(
      greenRoot: TexParser(sanitized, const TexParserSettings()).parse(),
    );
    ast.buildWidget(
      MathOptions(
        style: MathStyle.display,
        fontSize: 16,
        color: Colors.black,
      ),
    );
  }
}

void main() {
  group('Fase 8B - VectorSolver (2D/3D)', () {
    test('Módulo exacto simplifica √18 en 3√2 y gestiona vector nulo', () {
      final resSqrt18 = VectorSolver.modulus(RationalVector.fromInts([3, 3]));
      expect(resSqrt18.exactResultLatex, contains(r'3\sqrt{2}'));
      expect(resSqrt18.steps.length, equals(2));
      _expectAllLatexValid(resSqrt18);

      final resZero = VectorSolver.modulus(RationalVector.fromInts([0, 0, 0]));
      expect(resZero.exactResultLatex, contains('0'));
      _expectAllLatexValid(resZero);

      final resFrac = VectorSolver.modulus(
        RationalVector.fromRationals([Rational(3, 2), Rational(2, 1)]),
      );
      expect(resFrac.exactResultLatex, contains(r'\frac{5}{2}'));
      _expectAllLatexValid(resFrac);
    });

    test('Producto escalar ortogonal = 0 resalta perpendicularidad (90°)', () {
      final u = RationalVector.fromInts([1, 2, -1]);
      final v = RationalVector.fromInts([2, 0, 2]);
      final analysis = VectorSolver.analyzeDotAndAngle(u, v);

      expect(analysis.dotValue, equals(Rational(0)));
      expect(analysis.angleDegrees, closeTo(90.0, 1e-6));
      expect(
        analysis.resolution.steps.first.pedagogicalNote.toLowerCase(),
        contains('ortogonales'),
      );
      expect(analysis.resolution.exactResultLatex, contains(r'90^{\circ}'));
      _expectAllLatexValid(analysis.resolution);
    });

    test('Producto vectorial (1,2,3) × (4,5,6) = (-3, 6, -3) y área del paralelogramo', () {
      final u = RationalVector.fromInts([1, 2, 3]);
      final v = RationalVector.fromInts([4, 5, 6]);
      final analysis = VectorSolver.analyzeCrossProductAndArea(u, v);

      expect(analysis.resultVector, isNotNull);
      expect(analysis.resultVector!.x, equals(Rational(-3)));
      expect(analysis.resultVector!.y, equals(Rational(6)));
      expect(analysis.resultVector!.z, equals(Rational(-3)));

      // Debe incluir determinante i, j, k y alerta de signo '-' en j
      expect(analysis.resolution.steps[0].latexExpression, contains(r'\vec{i}'));
      expect(
        analysis.resolution.steps[1].warningTrick,
        allOf(isNotNull, contains('j')),
      );
      // Área del paralelogramo = |-3, 6, -3| = √54 = 3√6
      expect(analysis.exactNormLatex, equals(r'3\sqrt{6}'));
      expect(analysis.resolution.steps.last.latexExpression, contains(r'3\sqrt{6}'));
      _expectAllLatexValid(analysis.resolution);
    });

    test('Suma y resta de vectores 2D y 3D producen LaTeX válido', () {
      final u2 = RationalVector.fromInts([2, -3]);
      final v2 = RationalVector.fromInts([-1, 5]);
      final sumRes = VectorSolver.add(u2, v2);
      final subRes = VectorSolver.subtract(u2, v2);

      expect(sumRes.exactResultLatex, contains('(1, 2)'));
      expect(subRes.exactResultLatex, contains('(3, -8)'));
      _expectAllLatexValid(sumRes);
      _expectAllLatexValid(subRes);
    });
  });

  group('Fase 8B - ComplexSolver (Binómica y Polar)', () {
    test('División (2 + i) / (1 - i) = 1/2 + 3/2 i multiplicando por conjugado', () {
      final z1 = RationalComplex.fromInts(2, 1);
      final z2 = RationalComplex.fromInts(1, -1);
      final analysis = ComplexSolver.analyzeOperation(
        operation: ComplexOperation.divide,
        z1: z1,
        z2: z2,
      );

      expect(analysis.binomial, isNotNull);
      expect(analysis.binomial!.real, equals(Rational(1, 2)));
      expect(analysis.binomial!.imag, equals(Rational(3, 2)));
      expect(
        analysis.resolution.steps.first.latexExpression,
        contains(r'\frac{2 + i}{1 - i}'),
      );
      expect(
        analysis.resolution.steps.first.pedagogicalNote,
        contains('conjugado'),
      );
      expect(
        analysis.resolution.steps[1].warningTrick,
        allOf(isNotNull, contains('denominador')),
      );
      expect(
        analysis.resolution.exactResultLatex,
        equals(r'\frac{1}{2} + \frac{3}{2}i'),
      );
      _expectAllLatexValid(analysis.resolution);

      // División por cero lanza FormatException controlada
      expect(
        () => ComplexSolver.divide(z1, RationalComplex.fromInts(0, 0)),
        throwsFormatException,
      );
    });

    test('Multiplicación destaca sustitución i² = -1 en warningTrick', () {
      final res = ComplexSolver.multiply(
        RationalComplex.fromInts(3, 2),
        RationalComplex.fromInts(1, -4),
      );
      // (3+2i)(1-4i) = 3 - 12i + 2i - 8i² = 11 - 10i
      expect(res.exactResultLatex, equals('11 - 10i'));
      expect(res.steps[1].warningTrick, contains('i² = -1'));
      _expectAllLatexValid(res);
    });

    test('Conversión Binómica ↔ Polar respeta todos los cuadrantes y ejes', () {
      final q1 = ComplexSolver.analyzeToPolar(RationalComplex.fromInts(1, 1));
      expect(q1.polarModulusLatex, equals(r'\sqrt{2}'));
      expect(q1.polarAngleDegrees, closeTo(45.0, 1e-6));
      _expectAllLatexValid(q1.resolution);

      final q2 = ComplexSolver.analyzeToPolar(RationalComplex.fromInts(-3, 3));
      expect(q2.polarModulusLatex, equals(r'3\sqrt{2}'));
      expect(q2.polarAngleDegrees, closeTo(135.0, 1e-6));
      expect(q2.resolution.steps[1].warningTrick, contains('II Cuadrante'));
      _expectAllLatexValid(q2.resolution);

      final q3 = ComplexSolver.analyzeToPolar(RationalComplex.fromInts(-1, -1));
      expect(q3.polarAngleDegrees, closeTo(225.0, 1e-6));
      _expectAllLatexValid(q3.resolution);

      final q4 = ComplexSolver.analyzeToPolar(RationalComplex.fromInts(1, -1));
      expect(q4.polarAngleDegrees, closeTo(315.0, 1e-6));
      _expectAllLatexValid(q4.resolution);

      final axisImagNeg =
          ComplexSolver.analyzeToPolar(RationalComplex.fromInts(0, -4));
      expect(axisImagNeg.polarModulusLatex, equals('4'));
      expect(axisImagNeg.polarAngleDegrees, closeTo(270.0, 1e-6));
      _expectAllLatexValid(axisImagNeg.resolution);

      final inv = ComplexSolver.fromPolar(
        modulus: Rational(2),
        angleDegrees: 60,
      );
      expect(inv.exactResultLatex, contains(r'\sqrt{3}'));
      _expectAllLatexValid(inv);
    });
  });

  group('Fase 8B - CalculusSolver (Derivadas, Tangente e Integrales Barrow)', () {
    test('Derivada de x^3 - 3x^2 + 2 = 3x^2 - 6x sin 0x ni signos dobles', () {
      final poly = RationalPolynomial.parseExpression('x^3 - 3x^2 + 2');
      final analysis = CalculusSolver.analyzeDerivative(poly);

      expect(analysis.resultPolynomial, isNotNull);
      expect(analysis.resultPolynomial!.coeffOf(2), equals(Rational(3)));
      expect(analysis.resultPolynomial!.coeffOf(1), equals(Rational(-6)));
      expect(analysis.resultPolynomial!.coeffOf(0), equals(Rational(0)));
      expect(analysis.resolution.exactResultLatex, equals("f'(x) = 3x^{2} - 6x"));
      expect(analysis.resolution.exactResultLatex, isNot(contains('+ -')));
      _expectAllLatexValid(analysis.resolution);
    });

    test('Recta tangente a f(x) = x^2 - 4x + 5 en x0 = 3 da y = 2x - 4', () {
      final poly = RationalPolynomial.parseExpression('x² - 4x + 5');
      final analysis = CalculusSolver.analyzeTangentLine(poly, Rational(3));

      expect(analysis.slopeM, equals(Rational(2)));
      expect(analysis.interceptN, equals(Rational(-4)));
      expect(analysis.resolution.exactResultLatex, equals('y = 2x - 4'));
      _expectAllLatexValid(analysis.resolution);
    });

    test('Integral indefinida añade constante + C y simplifica fracciones', () {
      final poly = RationalPolynomial.parseExpression('3x^2 - 2x + 1/2');
      final analysis = CalculusSolver.analyzeIndefiniteIntegral(poly);

      expect(analysis.resultPolynomial!.coeffOf(3), equals(Rational(1)));
      expect(analysis.resultPolynomial!.coeffOf(2), equals(Rational(-1)));
      expect(analysis.resultPolynomial!.coeffOf(1), equals(Rational(1, 2)));
      expect(analysis.resolution.exactResultLatex, contains('+ C'));
      _expectAllLatexValid(analysis.resolution);
    });

    test('Integral definida por Regla de Barrow ∫_0^2 3x^2 dx = 8', () {
      final poly = RationalPolynomial.parseExpression('3x^2');
      final analysis = CalculusSolver.analyzeDefiniteIntegralBarrow(
        poly,
        Rational(0),
        Rational(2),
      );

      expect(analysis.definiteValue, equals(Rational(8)));
      expect(analysis.resolution.exactResultLatex, equals('8'));
      expect(analysis.resolution.steps[1].latexExpression, contains('['));
      expect(
        analysis.resolution.steps[1].warningTrick,
        allOf(isNotNull, contains('paréntesis')),
      );
      _expectAllLatexValid(analysis.resolution);

      // Exportación LaTeX Goodnotes válida
      final block = GoodnotesExporter.formatAsLatexBlock(analysis.resolution);
      expect(block, contains(r'\begin{align*}'));
      expect(block, contains(r'\end{align*}'));
    });
  });

  group('Fase 8B - Widget / UX Móvil y Desktop (Modos 12, 13 y 14)', () {
    Future<void> pumpCalc(WidgetTester tester, Size size) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Modo 9 (Vectores 3D): abre editor limpio y calcula (1,2,3) × (4,5,6)', (tester) async {
      await pumpCalc(tester, const Size(1024, 820));

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu_mode_9')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_10')), findsOneWidget);
      expect(find.byKey(const Key('menu_mode_11')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu_mode_9')));
      await tester.pumpAndSettle();

      expect(find.byType(CasioVectorEditorView), findsOneWidget);
      expect(find.byKey(const Key('vector_u_cell_0')), findsOneWidget);
      expect(find.byKey(const Key('vector_v_cell_2')), findsOneWidget);

      // Seleccionamos Producto Vectorial y rellenamos u=(1,2,3), v=(4,5,6)
      await tester.tap(find.byKey(const Key('vector_op_crossAndArea')));
      await tester.pumpAndSettle();

      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.widgetWithText(CasioPhysicalKey, digit));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
        await tester.pumpAndSettle();
      }

      // Al pulsar '=' en v_z resuelve automáticamente
      expect(find.textContaining('PASO 1/'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 10 (Complejos): divide (2 + i) / (1 - i) con teclado físico', (tester) async {
      await pumpCalc(tester, const Size(1024, 820));

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_10')));
      await tester.pumpAndSettle();

      expect(find.byType(CasioComplexEditorView), findsOneWidget);
      await tester.tap(find.byKey(const Key('complex_op_divide')));
      await tester.pumpAndSettle();

      // z1: a=2, b=1; z2: c=1, d=-1
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 11 (Cálculo Móvil 390x844): ∫_0^2 3x² dx por Barrow sin overflow', (tester) async {
      await pumpCalc(tester, const Size(390, 844));

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_11')));
      await tester.pumpAndSettle();

      expect(find.byType(CasioCalculusEditorView), findsOneWidget);

      // Seleccionamos integral definida ∫_a^b
      await tester.tap(find.byKey(const Key('calculus_op_definiteIntegral')));
      await tester.pumpAndSettle();

      // Escribimos 3x² en f(x) usando teclado físico + ALPHA ')' -> x y tecla x²
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, ')'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'x²'));
      await tester.pumpAndSettle();

      // Avanzamos con '=' a límite a = 0 y límite b = 2, y '=' final resuelve
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
