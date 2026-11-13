import 'package:casio_tutor_calc/domain/math_engine/ast/ast_nodes.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/step_evaluator.dart';
import 'package:casio_tutor_calc/domain/services/ai_tutor_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiTutorService tutorService;
  late StepEvaluator evaluator;

  setUp(() {
    tutorService = AiTutorService();
    evaluator = StepEvaluator();
  });

  test('AiTutorService detecta trampa de signos en potencias en modo local', () async {
    const ast = UnaryMinusNode(PowerNode(IntNode(3), 2));
    final resolution = evaluator.evaluate(ast);

    final diagnosis = await tutorService.analyzeCurrentStep(
      resolution: resolution,
      stepIndex: 0,
    );

    expect(diagnosis.isCloudAi, isFalse);
    expect(diagnosis.examTrapAlert, isNotNull);
    expect(diagnosis.socraticQuestion, contains('exponente'));
    expect(diagnosis.conceptualHint, contains('-3²'));
  });

  test('AiTutorService responde a duda específica sobre signos', () async {
    const ast = UnaryMinusNode(PowerNode(IntNode(3), 2));
    final resolution = evaluator.evaluate(ast);

    final diagnosis = await tutorService.analyzeCurrentStep(
      resolution: resolution,
      stepIndex: 0,
      studentDoubt: '¿Por qué sale ese signo?',
    );

    expect(diagnosis.socraticQuestion, contains('signo'));
    expect(diagnosis.conceptualHint, contains('Regla de signos'));
  });

  test('AiTutorService responde a duda sobre el denominador en suma de fracciones', () async {
    const ast = BinaryOpNode(
      FractionNode(4, 6),
      BinaryOperator.add,
      FractionNode(5, 4),
    );
    final resolution = evaluator.evaluate(ast);

    // Buscamos el paso de m.c.m.
    final mcmIndex = resolution.steps.indexWhere(
      (s) => s.shortTitle.toLowerCase().contains('m.c.m.'),
    );

    final diagnosis = await tutorService.analyzeCurrentStep(
      resolution: resolution,
      stepIndex: mcmIndex != -1 ? mcmIndex : 0,
      studentDoubt: '¿De dónde sale el denominador?',
    );

    expect(diagnosis.socraticQuestion, contains('denominadores'));
    expect(diagnosis.conceptualHint, contains('m.c.m.'));
  });
}
