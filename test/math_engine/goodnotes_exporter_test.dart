import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/utils/goodnotes_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GoodnotesExporter genera bloque align* de LaTeX correctamente formateado', () {
    const resolution = StepByStepResolution(
      originalInputLatex: r'\frac{4}{6} + \frac{5}{4}',
      steps: [
        MathStep(
          index: 1,
          shortTitle: r'1. Simplificar fracción inicial',
          latexExpression: r'\frac{4:2}{6:2} = \frac{2}{3}',
          pedagogicalNote: 'Dividimos entre M.C.D.',
        ),
        MathStep(
          index: 2,
          shortTitle: r'2. Operar numeradores',
          latexExpression: r'\frac{8+15}{12} = \frac{23}{12}',
          pedagogicalNote: 'Resultado irreducible',
        ),
      ],
      exactResultLatex: r'\frac{23}{12}',
      decimalApproxLatex: '1,916667',
    );

    final latexBlock = GoodnotesExporter.formatAsLatexBlock(resolution);

    expect(latexBlock, contains(r'\begin{align*}'));
    expect(latexBlock, contains(r'\text{Expresion inicial:} \quad & \frac{4}{6} + \frac{5}{4} \\'));
    expect(latexBlock, contains(r'\mathbf{\frac{23}{12}}'));
    expect(latexBlock, contains(r'\end{align*}'));
  });
}
