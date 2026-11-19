import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/exercise_dsl.dart';

void main() {
  group('M10 Vectores y geometria', () {
    bothSizes('1a. |u| = 3 para u = (1,-2,2)', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_op:vector_op_modulus 1 = - 2 = 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('=3'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('1b. u·v = -4', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_op:vector_op_dotAndAngle 1 = - 2 = 2 = 2 = 1 = - 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('=-4'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('1c. u x v = (2, 6, 5)', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_op:vector_op_crossAndArea 1 = - 2 = 2 = 2 = 1 = - 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('(2,6,5)'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. producto mixto [u,v,w] = 7, paralelepipedo 7 u^3, tetraedro 7/6 u^3', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_op:vector_op_mixedProduct 1 = - 2 = 2 = 2 = 1 = - 2 = 1 = 0 = 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('=7'));
      final text = norm(lessonText(r));
      expect(text, contains(r'7\;u^{3}'.replaceAll(r'\;', '')));
      expect(text, contains(r'\frac{7}{6}'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3. recta por A(1,-2) y B(4,4): 6 ecuaciones, y = 2x - 4, 2x - y - 4 = 0', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_1 = 1 = - 2 = 4 = 4 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '2x-y-4=0');
      final text = lessonText(r);
      for (final title in ['vectorial', 'paramétricas', 'continua', 'punto-pendiente', 'explícita', 'general']) {
        expect(text.toLowerCase(), contains(title));
      }
      expect(norm(text), contains('y=2x-4'));
      expectLesson(r, minSteps: 6);
    });

    bothSizes('4a. triangulo rectangulo de catetos 3 y 4: hipotenusa 5', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 3 = 4 = = = = 9 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('c=5{,}0000'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4b. oblicuangulo a=7, b=8, C=60°: c = sqrt(57) ≈ 7,55 (teorema del coseno)', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 7 = 8 = = = = 6 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('c=7{,}5498'));
      expect(lessonText(r).toLowerCase(), contains('coseno'));
      expect(norm(lessonText(r)), contains(r'\sqrt{57}'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4c. triangulo imposible a=2, b=3, c=10: LcdErrorScreen claro', (t) async {
      await seq(t, 'mode:10 pick:hdr_vector_view:vector_view_2 2 = 3 = 1 0 = = = =');
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
      expect(find.textContaining('no es un triángulo'), findsWidgets);
    });
  });

  group('M11 Numeros complejos', () {
    bothSizes('1. (3+4i)/(1-2i) = -1 + 2i multiplicando por el conjugado', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_divide 3 = 4 = 1 = - 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '-1+2i');
      expect(lessonText(r).toLowerCase(), contains('conjugado'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2a. i^2026 = -1', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_powerOfI 2 0 2 6 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '-1');
      expect(norm(lessonText(r)), contains('2026=4\\cdot506+2'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2b. i^43 = -i', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_powerOfI 4 3 =');
      expect(norm(res(t).exactResultLatex), '-i');
    });

    bothSizes('3a. -1 + sqrt(3) i -> 2 con angulo 120° (2.º cuadrante, exacto)', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_toPolar - 1 = sqrt 3 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'2_{120^{\circ}}');
      expect(lessonText(r), contains('II Cuadrante'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3b. -2 - 2i -> 2 sqrt(2) con angulo 225° (3.er cuadrante)', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_toPolar - 2 = - 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'2\sqrt{2}_{225^{\circ}}');
      expect(lessonText(r), contains('III Cuadrante'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. 4_{210°} -> -2 sqrt(3) - 2i (exacto)', (t) async {
      await seq(t, 'mode:11 pick:hdr_complex_op:complex_op_fromPolar 4 = 2 1 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'-2\sqrt{3}-2i');
      expectLesson(r, minSteps: 2);
    });
  });
}
