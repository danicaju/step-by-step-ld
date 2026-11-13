import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/matrix_solver.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/system_3x3_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_coefficient_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_matrix_editor_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';

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
    ast.buildWidget(MathOptions(style: MathStyle.display, fontSize: 18));
  }
}

void main() {
  group('Fase 8A - MatrixSolver (2x2 y 3x3: Sarrus, Adjunta, Inversa, Producto)', () {
    test('Determinante 2x2 exacto por producto cruzado', () {
      final a = RationalMatrix.fromInts([
        [3, 5],
        [2, 4],
      ]);
      expect(a.determinantValue(), equals(Rational(2)));

      final res = MatrixSolver.determinant(a);
      expect(res.exactResultLatex, equals(r'\left|A\right| = 2'));
      expect(res.steps.length, greaterThanOrEqualTo(2));
      _expectAllLatexValid(res);
    });

    test('Regla de Sarrus 3x3 desglosada en 3 pasos pedagógicos con alerta de signos', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 3],
        [0, 1, 4],
        [5, 6, 0],
      ]);
      // Diagonales +: 1*1*0 + 2*4*5 + 3*0*6 = 40
      // Diagonales -: 3*1*5 + 1*4*6 + 2*0*0 = 15 + 24 + 0 = 39
      // |A| = 40 - 39 = 1
      expect(a.determinantValue(), equals(Rational(1)));

      final res = MatrixSolver.determinant(a);
      expect(res.exactResultLatex, equals(r'\left|A\right| = 1'));
      expect(res.steps.length, equals(3));
      expect(res.steps[0].shortTitle, contains('Sarrus'));
      expect(res.steps[1].warningTrick, isNotNull);
      expect(res.steps[2].pedagogicalNote.toLowerCase(), contains('invertible'));
      _expectAllLatexValid(res);
    });

    test('Matriz inversa 3x3 exacta A^-1 verificando A * A^-1 = I_3 con fracciones irreducibles', () {
      final a = RationalMatrix.fromInts([
        [2, 1, 0],
        [1, 2, 1],
        [0, 1, 2],
      ]);
      // |A| = 2*(4-1) - 1*(2-0) + 0 = 4
      expect(a.determinantValue(), equals(Rational(4)));

      final inv = a.inverseMatrix();

      final identity = a * inv;
      expect(identity.at(0, 0), equals(Rational(1)));
      expect(identity.at(1, 1), equals(Rational(1)));
      expect(identity.at(2, 2), equals(Rational(1)));
      expect(identity.at(0, 1), equals(Rational(0)));
      expect(identity.at(0, 2), equals(Rational(0)));
      expect(identity.at(1, 0), equals(Rational(0)));
      expect(identity.at(2, 1), equals(Rational(0)));

      // Comprobamos entradas exactas de la inversa: A^-1[0][0] = 3/4, A^-1[0][1] = -1/2
      expect(inv.at(0, 0), equals(Rational(3, 4)));
      expect(inv.at(0, 1), equals(Rational(-1, 2)));
      expect(inv.at(0, 2), equals(Rational(1, 4)));

      final res = MatrixSolver.inverse(a);
      expect(res.steps.length, equals(4));
      expect(res.steps.last.latexExpression, contains(r'A^{-1} = '));
      expect(res.exactResultLatex, contains(r'\frac{3}{4}'));
      expect(res.exactResultLatex, contains(r'-\frac{1}{2}'));
      _expectAllLatexValid(res);
    });

    test('Matriz singular 3x3 (|A| = 0) se detiene en el Paso 1 explicando que no existe inversa', () {
      final singular = RationalMatrix.fromInts([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ]);
      expect(singular.determinantValue(), equals(Rational(0)));
      expect(() => singular.inverseMatrix(), throwsFormatException);

      final res = MatrixSolver.inverse(singular);
      expect(res.steps.length, equals(1));
      expect(res.exactResultLatex, contains(r'\nexists A^{-1}'));
      expect(res.steps.first.warningTrick, isNotNull);
      _expectAllLatexValid(res);
    });

    test('Adjunta, suma, resta, producto por escalar y producto matricial A·B', () {
      final a = RationalMatrix.fromInts([
        [1, 2, 0],
        [-1, 3, 1],
        [2, 0, -2],
      ]);
      final b = RationalMatrix.fromInts([
        [0, 1, 2],
        [3, -1, 1],
        [2, 4, 0],
      ]);

      final adjRes = MatrixSolver.adjoint(a);
      expect(adjRes.steps.length, equals(2));
      expect(adjRes.steps[0].warningTrick, contains('signo'));
      _expectAllLatexValid(adjRes);

      final mulRes = MatrixSolver.multiply(a, b);
      expect(mulRes.steps.length, equals(3));
      expect(mulRes.steps[0].warningTrick, contains('conmutativo'));
      // Entrada (0,0) = 1*0 + 2*3 + 0*2 = 6
      expect((a * b).at(0, 0), equals(Rational(6)));
      _expectAllLatexValid(mulRes);

      final addRes = MatrixSolver.add(a, b);
      expect(addRes.steps.length, equals(2));
      _expectAllLatexValid(addRes);

      final subRes = MatrixSolver.subtract(a, b);
      expect(subRes.steps.length, equals(2));
      _expectAllLatexValid(subRes);

      final scalarRes = MatrixSolver.scalarMultiply(Rational(3, 2), a);
      expect(scalarRes.steps.length, equals(2));
      expect(scalarRes.exactResultLatex, contains(r'\frac{3}{2}'));
      _expectAllLatexValid(scalarRes);
    });
  });

  group('Fase 8A - System3x3Solver (Gauss y Cramer con fracciones irreducibles)', () {
    test('Equivalencia exacta entre Gauss y Cramer en sistema S.C.D. fraccionario', () {
      // Solución esperada: x = 1/2, y = -3/4, z = 5/2
      // Eq1: 2x + 4y + 2z = 1 - 3 + 5 = 3
      // Eq2: 4x - 4y + 2z = 2 + 3 + 5 = 10
      // Eq3: 2x + 8y - 2z = 1 - 6 - 5 = -10
      final rows = [
        [Rational(2), Rational(4), Rational(2), Rational(3)],
        [Rational(4), Rational(-4), Rational(2), Rational(10)],
        [Rational(2), Rational(8), Rational(-2), Rational(-10)],
      ];

      final gauss = System3x3Solver.analyze(
        augmentedRows: rows,
        method: System3x3Method.gauss,
      );
      final cramer = System3x3Solver.analyze(
        augmentedRows: rows,
        method: System3x3Method.cramer,
      );

      expect(gauss.classification, equals(System3x3Classification.scd));
      expect(cramer.classification, equals(System3x3Classification.scd));
      expect(gauss.rankA, equals(3));
      expect(gauss.rankAugmented, equals(3));
      expect(cramer.rankA, equals(3));
      expect(cramer.rankAugmented, equals(3));

      expect(gauss.x, equals(Rational(1, 2)));
      expect(gauss.y, equals(Rational(-3, 4)));
      expect(gauss.z, equals(Rational(5, 2)));

      expect(cramer.x, equals(gauss.x));
      expect(cramer.y, equals(gauss.y));
      expect(cramer.z, equals(gauss.z));

      expect(gauss.resolution.exactResultLatex, contains(r'\frac{1}{2}'));
      expect(gauss.resolution.exactResultLatex, contains(r'-\frac{3}{4}'));
      expect(gauss.resolution.exactResultLatex, contains(r'\frac{5}{2}'));
      expect(cramer.resolution.exactResultLatex, contains(r'\frac{1}{2}'));
      expect(cramer.resolution.exactResultLatex, contains(r'-\frac{3}{4}'));
      expect(cramer.resolution.exactResultLatex, contains(r'\frac{5}{2}'));

      // Verificamos matriz ampliada en Gauss y determinantes en Cramer
      expect(gauss.resolution.steps.first.latexExpression, contains(r'\begin{array}{ccc|c}'));
      expect(cramer.resolution.steps.first.latexExpression, contains(r'\Delta = '));
      expect(cramer.resolution.steps.length, equals(4));

      _expectAllLatexValid(gauss.resolution);
      _expectAllLatexValid(cramer.resolution);
    });

    test('Gauss con intercambio automático de fila por pivote cero coincide con Cramer', () {
      // y + z = 3; x + z = 4; x + y = 5 => x = 3, y = 2, z = 1
      final rows = [
        [Rational(0), Rational(1), Rational(1), Rational(3)],
        [Rational(1), Rational(0), Rational(1), Rational(4)],
        [Rational(1), Rational(1), Rational(0), Rational(5)],
      ];

      final gauss = System3x3Solver.analyze(
        augmentedRows: rows,
        method: System3x3Method.gauss,
      );
      final cramer = System3x3Solver.analyze(
        augmentedRows: rows,
        method: System3x3Method.cramer,
      );

      expect(gauss.classification, equals(System3x3Classification.scd));
      expect(gauss.x, equals(Rational(3)));
      expect(gauss.y, equals(Rational(2)));
      expect(gauss.z, equals(Rational(1)));
      expect(cramer.x, equals(gauss.x));
      expect(cramer.y, equals(gauss.y));
      expect(cramer.z, equals(gauss.z));

      _expectAllLatexValid(gauss.resolution);
      _expectAllLatexValid(cramer.resolution);
    });

    test('Detección S.C.I. y S.I. por Rouché-Frobenius y aviso en Cramer cuando |A| = 0', () {
      // S.C.I.: rk(A) = rk(A|b) = 2 < 3
      final sciRows = [
        [Rational(1), Rational(1), Rational(1), Rational(6)],
        [Rational(2), Rational(2), Rational(2), Rational(12)],
        [Rational(1), Rational(2), Rational(3), Rational(14)],
      ];
      final sciGauss = System3x3Solver.analyze(
        augmentedRows: sciRows,
        method: System3x3Method.gauss,
      );
      final sciCramer = System3x3Solver.analyze(
        augmentedRows: sciRows,
        method: System3x3Method.cramer,
      );
      expect(sciGauss.classification, equals(System3x3Classification.sci));
      expect(sciGauss.rankA, equals(2));
      expect(sciGauss.rankAugmented, equals(2));
      expect(sciCramer.classification, equals(System3x3Classification.sci));
      expect(sciCramer.resolution.steps.last.warningTrick, isNotNull);
      _expectAllLatexValid(sciGauss.resolution);
      _expectAllLatexValid(sciCramer.resolution);

      // S.I.: rk(A) = 2 < rk(A|b) = 3
      final siRows = [
        [Rational(1), Rational(1), Rational(1), Rational(6)],
        [Rational(2), Rational(2), Rational(2), Rational(10)],
        [Rational(1), Rational(-1), Rational(1), Rational(2)],
      ];
      final siGauss = System3x3Solver.analyze(
        augmentedRows: siRows,
        method: System3x3Method.gauss,
      );
      final siCramer = System3x3Solver.analyze(
        augmentedRows: siRows,
        method: System3x3Method.cramer,
      );
      expect(siGauss.classification, equals(System3x3Classification.si));
      expect(siGauss.rankA, equals(2));
      expect(siGauss.rankAugmented, equals(3));
      expect(siCramer.classification, equals(System3x3Classification.si));
      _expectAllLatexValid(siGauss.resolution);
      _expectAllLatexValid(siCramer.resolution);
    });
  });

  group('Fase 8A - Widget / UX Móvil y Desktop (Modos 10 y 11)', () {
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

    testWidgets('Modo 8 (Matrices): abre editor limpio, alterna 3x3 y calcula |A| por Sarrus', (tester) async {
      await pumpCalc(tester, const Size(1024, 820));

      // Abrimos MENU -> Página 2 y elegimos Modo 8: Matrices
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu_mode_8')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu_mode_8')));
      await tester.pumpAndSettle();

      // Verifica vista de Matrices activa (3x3 por defecto) y cambia a 2x2 para prueba rápida
      expect(find.byType(CasioMatrixEditorView), findsOneWidget);
      expect(find.byKey(const Key('matrix_A_cell_2_2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('matrix_size_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matrix_A_cell_2_2')), findsNothing);
      expect(find.byKey(const Key('matrix_A_cell_0_0')), findsOneWidget);

      // Rellenamos una matriz 2x2: [[3, 5], [2, 4]] con teclado físico y '='
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      // En última celda (1,1) de 2x2, pulsar '=' resuelve directamente (PASO 1/)
      expect(find.textContaining('PASO 1/'), findsOneWidget);

      // Volvemos a editar, pasamos a 3x3 y probamos Sarrus y A·B mostrando pestaña MatB
      await tester.tap(find.byKey(const Key('matrix_edit_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('matrix_size_3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matrix_A_cell_2_2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('matrix_op_determinant')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('matrix_solve_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('matrix_edit_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('matrix_op_multiply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matrix_tab_B')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 3 unificado (Sist. 3x3): cambia Gauss <-> Cramer y resuelve sin overflow en móvil 390x844', (tester) async {
      await pumpCalc(tester, const Size(390, 844));

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sys_dim_3')));
      await tester.pumpAndSettle();

      expect(find.byType(CasioCoefficientView), findsOneWidget);
      expect(find.byKey(const Key('coeff_cell_0')), findsOneWidget);
      expect(find.byKey(const Key('coeff_cell_11')), findsOneWidget);

      // Sistema diagonal trivial rápido: x=2, y=3, z=4
      // Fila 0: [1, 0, 0, 2]
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('coeff_cell_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();

      // Fila 1: [0, 1, 0, 3]
      await tester.tap(find.byKey(const Key('coeff_cell_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('coeff_cell_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();

      // Fila 2: [0, 0, 1, 4]
      await tester.tap(find.byKey(const Key('coeff_cell_10')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('coeff_cell_11')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();

      // Resuelve por Gauss primero
      await tester.tap(find.byKey(const Key('sys3_solve_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Cambia en vivo a Cramer
      await tester.tap(find.byKey(const Key('sys3_method_cramer')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // También verifica que Modo 8 (Matrices) no desborda en pantalla móvil 390x844
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_page_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu_mode_8')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('matrix_size_3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('matrix_A_cell_2_2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
