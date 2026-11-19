import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_helpers.dart';
import '../support/exercise_dsl.dart';

void main() {
  group('M12.1 Derivadas y recta tangente', () {
    bothSizes('1. (x^2+1)e^x -> f\'(x) = (x^2 + 2x + 1)e^x (producto)', (t) async {
      await seq(t, 'mode:12 ( x sq + 1 ) quickoptn quick:ℯ S:pow x > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r"f'(x)=(x^{2}+2x+1)e^{x}");
      expect(lessonText(r).toLowerCase(), contains('producto'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('2. (2x-1)/(x+3) -> f\'(x) = 7/(x+3)^2 (cociente)', (t) async {
      await seq(t, 'mode:12 frac 2 x - 1 v x + 3 > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r"f'(x)=\frac{7}{(x+3)^{2}}");
      expect(lessonText(r).toLowerCase(), contains('cociente'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3. sin(3x^2+1) -> f\'(x) = 6x cos(3x^2+1) (cadena)', (t) async {
      await seq(t, 'mode:12 sin 3 x sq + 1 ) =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r"f'(x)=6x\cos(3x^{2}+1)");
      expect(lessonText(r).toLowerCase(), contains('cadena'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4. ln(x^2+1): f\'(x) = 2x/(x^2+1) y tangente en x0 = 1: y = x - 1 + ln 2', (t) async {
      await seq(t, 'mode:12 ln x sq + 1 > =');
      final d = res(t);
      expect(norm(d.exactResultLatex), r"f'(x)=\frac{2x}{x^{2}+1}");
      expectLesson(d, minSteps: 4);
      await key(t, 'AC');
      await seq(t, 'pick:hdr_calculus_op:calculus_op_tangentLine ln x sq + 1 > = 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), anyOf(r'y=x+\ln(2)-1', r'y=x-1+\ln(2)'));
      expectLesson(r, minSteps: 4);
    });
  });

  group('M12.2 Integrales indefinidas y definidas', () {
    bothSizes('1. ∫(3x^2 - 2/x^2 + sqrt(x))dx = x^3 + 2/x + (2/3)x^(3/2) + C', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_indefiniteIntegral 3 x sq - frac 2 v x sq > + sqrt x > =');
      final r = res(t);
      final text = norm(r.exactResultLatex);
      expect(text, contains('x^{3}+\\frac{2}{x}'));
      expect(text, isNot(contains('--')));
      expect(text, endsWith('+C'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('2. ∫ 4x/(x^2+5) dx = 2 ln|x^2+5| + C (ajuste de derivada)', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_indefiniteIntegral frac 4 x v x sq + 5 > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'2\ln|x^{2}+5|+C');
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3. ∫ x e^(2x) dx por partes', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_indefiniteIntegral x quickoptn quick:ℯ S:pow 2 x > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{xe^{2x}}{2}-\frac{e^{2x}}{4}+C');
      expect(lessonText(r).toLowerCase(), contains('partes'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4. ∫_0^2 (3x^2+1) dx = [x^3 + x]_0^2 = 10 (Barrow)', (t) async {
      await seq(t, 'mode:12 pick:hdr_calculus_op:calculus_op_definiteIntegral 3 x sq + 1 = 0 = 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '10');
      expect(lessonText(r), contains('Barrow'));
      expectLesson(r, minSteps: 4);
    });
  });
}
