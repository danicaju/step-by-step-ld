import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_memory.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/services/class_history_service.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';

void main() {
  group('Fase 6: Gestor de Memoria Científica Casio (ANS, M+, Variables)', () {
    test('Resolución inicial 4/6 + 5/4 = 23/12 y posterior uso de ANS: ANS - 1 = 11/12', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();
      final memory = CalculatorMemoryManager();

      // 1. Resolver 4/6 + 5/4
      final ast1 = parser.parse('4/6 + 5/4');
      final res1 = evaluator.evaluate(ast1);

      expect(res1.exactResultLatex, equals(r'\frac{23}{12}'));
      expect(evaluator.lastEvaluatedRational, equals(Rational(23, 12)));

      // Almacenamos el resultado en ANS automáticamente
      memory.setAns(evaluator.lastEvaluatedRational!);
      expect(memory.ans, equals(Rational(23, 12)));

      // 2. Evaluar ANS - 1
      final ast2 = parser.parse('ANS - 1');
      expect(ast2, isA<BinaryOpNode>());

      final res2 = evaluator.evaluate(
        ast2,
        memoryVariables: memory.getAllVariablesWithAns(),
      );

      // Verificamos que el Paso 1 sustituye explícitamente ANS por 23/12
      expect(res2.steps.isNotEmpty, isTrue);
      final step1 = res2.steps.first;
      expect(step1.shortTitle, contains('Sustitución'));
      expect(step1.latexExpression, contains(r'\text{Sustituimos } \text{ANS} = \frac{23}{12} \text{ en la expresion}'));

      // Verificamos que el resultado final es 11/12
      expect(res2.exactResultLatex, equals(r'\frac{11}{12}'));
      expect(evaluator.lastEvaluatedRational, equals(Rational(11, 12)));
    });

    test('Memoria independiente M (M+, M-, MR, MC e indicador [M])', () {
      final memory = CalculatorMemoryManager();

      // Inicialmente M = 0 y no está activo
      expect(memory.independentMemoryM, equals(Rational(0)));
      expect(memory.hasActiveM, isFalse);

      // M+ con 5/2
      memory.mPlus(Rational(5, 2));
      expect(memory.independentMemoryM, equals(Rational(5, 2)));
      expect(memory.hasActiveM, isTrue);

      // M+ con 1/2 -> 6/2 = 3
      memory.mPlus(Rational(1, 2));
      expect(memory.independentMemoryM, equals(Rational(3, 1)));

      // M- con 1 -> 2
      memory.mMinus(Rational(1));
      expect(memory.mRecall(), equals(Rational(2, 1)));

      // MC limpia la memoria
      memory.mClear();
      expect(memory.independentMemoryM, equals(Rational(0)));
      expect(memory.hasActiveM, isFalse);
    });

    test('Almacenamiento y sustitución de variables alfabéticas (A..F)', () {
      final parser = ExpressionParser();
      final evaluator = StepEvaluator();
      final memory = CalculatorMemoryManager();

      // Guardamos A = 3/2
      memory.storeVariable('A', Rational(3, 2));
      expect(memory.getVariable('A'), equals(Rational(3, 2)));

      // Parseamos 2*A + 3/4
      final ast = parser.parse('2*A + 3/4');
      final res = evaluator.evaluate(
        ast,
        memoryVariables: memory.getAllVariablesWithAns(),
      );

      // Paso 1 sustituye A
      expect(res.steps.first.latexExpression, contains(r'\text{Sustituimos } A = \frac{3}{2}'));

      // 2 * (3/2) + 3/4 = 3 + 3/4 = 15/4
      expect(res.exactResultLatex, equals(r'\frac{15}{4}'));
    });

    test('Parser reconoce variables en mayúsculas, minúsculas y formato LaTeX', () {
      final parser = ExpressionParser();
      final astA = parser.parse('A');
      expect(astA, isA<VariableNode>());
      expect((astA as VariableNode).name, equals('A'));

      final astAns = parser.parse('ans');
      expect(astAns, isA<VariableNode>());
      expect((astAns as VariableNode).name, equals('ANS'));

      expect(ExpressionParser.rawToLiveLatex('ANS + 2'), contains(r'\text{ANS}'));
    });
  });

  group('Fase 6: Cuaderno de Historial de Clase y Persistencia', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Serialización y deserialización JSON de ClassHistoryEntry', () {
      final entry = ClassHistoryEntry(
        id: 'test_123',
        timestamp: DateTime(2026, 11, 10, 18, 30),
        modeName: 'M1: CALC',
        studentTag: '1.º-2.º ESO',
        isFavorite: true,
        resolution: const StepByStepResolution(
          originalInputLatex: r'\frac{4}{6} + \frac{5}{4}',
          steps: [
            MathStep(
              index: 1,
              shortTitle: 'Simplificar',
              latexExpression: r'\frac{2}{3}',
              pedagogicalNote: 'Dividimos entre 2',
            ),
          ],
          exactResultLatex: r'\frac{23}{12}',
          decimalApproxLatex: '1,916667',
        ),
      );

      final json = entry.toJson();
      final decoded = ClassHistoryEntry.fromJson(json);

      expect(decoded.id, equals('test_123'));
      expect(decoded.modeName, equals('M1: CALC'));
      expect(decoded.studentTag, equals('1.º-2.º ESO'));
      expect(decoded.isFavorite, isTrue);
      expect(decoded.resolution.originalInputLatex, equals(r'\frac{4}{6} + \frac{5}{4}'));
      expect(decoded.resolution.exactResultLatex, equals(r'\frac{23}{12}'));
      expect(decoded.resolution.steps.length, equals(1));
    });

    test('ClassHistoryService almacena, recupera, marca favoritos y genera resumen .tex', () async {
      final service = ClassHistoryService();

      final entry1 = ClassHistoryEntry(
        id: '1',
        timestamp: DateTime.now(),
        modeName: 'M1: Aritmética',
        studentTag: '1.º ESO',
        resolution: const StepByStepResolution(
          originalInputLatex: '2 + 3',
          steps: [
            MathStep(
              index: 1,
              shortTitle: 'Suma directa',
              latexExpression: '2 + 3 = 5',
              pedagogicalNote: 'Operamos números enteros',
            ),
          ],
          exactResultLatex: '5',
          decimalApproxLatex: '5',
        ),
      );

      // Guardamos la entrada
      await service.addEntry(entry1);
      var list = await service.getEntries();
      expect(list.length, equals(1));
      expect(list.first.id, equals('1'));
      expect(list.first.isFavorite, isFalse);

      // Marcamos como favorito
      await service.toggleFavorite('1');
      list = await service.getEntries();
      expect(list.first.isFavorite, isTrue);

      // Contador de hoy
      final count = await service.getTodayEntriesCount();
      expect(count, equals(1));

      // Generación de documento LaTeX completo
      final texSummary = service.generateClassTexSummary(list);
      expect(texSummary, contains(r'\documentclass'));
      expect(texSummary, contains('Resumen de Sesión de Clase'));
      expect(texSummary, contains(r'2 + 3 = 5'));
      expect(texSummary, contains('Pregunta Tipica'));

      // Borrado de entrada
      await service.deleteEntry('1');
      list = await service.getEntries();
      expect(list, isEmpty);
    });
  });

  group('Fase 6: Modo Dual LCD (Clásico vs OLED Pizarra Oscura)', () {
    testWidgets('CasioLcdScreen renderiza con modo OLED e indicador [M] activo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CasioLcdScreen(
              currentInputLatex: r'\text{ANS} + 2',
              currentResolution: null,
              activeStepIndex: 0,
              isShiftActive: false,
              isAlphaActive: false,
              isMemoryActive: true,
              isOledDark: true,
              showDecimalApprox: false,
              modeLabel: 'M1: CALC',
            ),
          ),
        ),
      );

      // Buscamos los indicadores de la barra superior: S, A, M
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('M1: CALC'), findsOneWidget);
    });
  });
}
