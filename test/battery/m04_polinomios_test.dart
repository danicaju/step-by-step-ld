import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_helpers.dart';
import '../support/exercise_dsl.dart';

void main() {
  group('M4.1 Ruffini y productos notables', () {
    bothSizes('1. (x^4 - 16):(x - 2) -> C = x^3 + 2x^2 + 4x + 8, R = 0 (ceros intermedios)', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_degree:ruffini_tab_4 1 = 0 = 0 = 0 = - 1 6 > 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'C(x)=x^{3}+2x^{2}+4x+8,R=0');
      expect(lessonText(r), contains('0x^{3}'));
      expect(lessonText(r).toLowerCase(), contains('cero'));
      expectLesson(r, minSteps: 6);
    });

    bothSizes('2. (2x^3 - 5x + 3):(x + 2) -> C = 2x^2 - 4x + 3, R = -3', (t) async {
      await seq(t, 'mode:4 2 = 0 = - 5 = 3 > - 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'C(x)=2x^{2}-4x+3,R=-3');
      expect(lessonText(r), contains('no es 0'));
      expectLesson(r, minSteps: 5);
    });

    bothSizes('2b. sin raiz r sigue factorizando (comportamiento de siempre)', (t) async {
      await seq(t, 'mode:4 1 = - 6 = 1 1 = - 6 =');
      final result = norm(res(t).exactResultLatex);
      for (final f in ['(x-1)', '(x-2)', '(x-3)']) {
        expect(result, contains(f));
      }
    });

    bothSizes('3a. (2x - 3)^2 = 4x^2 - 12x + 9', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables pick:hdr_poly_identity:identity_squareOfDiff 2 x > 3 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '4x^2-12x+9');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3b. 9x^2 - 25 = (3x + 5)(3x - 5) (inversa)', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables pick:hdr_poly_identity:identity_differenceOfSquares 9 x sq - 2 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '(3x+5)(3x-5)');
      expect(lessonText(r), contains('A^2 - B^2'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3c. 9x^2 - 24 no es diferencia de cuadrados: mensaje claro', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables pick:hdr_poly_identity:identity_differenceOfSquares 9 x sq - 2 4 =');
      expect(find.byKey(const Key('lcd_error_screen')), findsOneWidget);
    });

    bothSizes('4. (x + 2)^3 = x^3 + 6x^2 + 12x + 8', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables pick:hdr_poly_identity:identity_cubeOfSum x > 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), 'x^{3}+6x^{2}+12x+8');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4b. (2x - 1)^3 = 8x^3 - 12x^2 + 6x - 1', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_notables pick:hdr_poly_identity:identity_cubeOfDiff 2 x > 1 =');
      expect(norm(res(t).exactResultLatex), '8x^{3}-12x^{2}+6x-1');
    });
  });

  group('M4.2 Division en caja y fracciones algebraicas', () {
    bothSizes('1. caja: (x^4 - 3x^2 + 2x - 5):(x^2 - x + 1) -> C = x^2 + x - 3, R = -2x - 2', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box');
      expect(find.byKey(const Key('box_input_vline')), findsOneWidget);
      await seq(t, 'x S:pow 4 > - 3 x sq + 2 x - 5'); // ▶ sale del exponente
      // El exponente se ve como LaTeX (nada de x^4 literal).
      expect(find.descendant(of: find.byKey(const Key('xform_cell_0')), matching: find.byType(Math)), findsOneWidget);
      await seq(t, '= x sq - x + 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'C(x)=x^{2}+x-3,R(x)=-2x-2');
      expectLesson(r, minSteps: 6);
      // La caja se dibuja en todos los pasos.
      for (var i = 0; i < r.steps.length; i++) {
        expect(find.byKey(const Key('box_division_clip')), findsOneWidget, reason: 'paso ${i + 1}');
        await key(t, '=');
      }
    });

    bothSizes('2. caja exacta grado 4 entre grado 2 -> C = x^2 + x - 2, R = 0', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_box 2 x S:pow 4 > + x A:x² - 8 x sq - x + 6 = 2 x sq - x - 3 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'C(x)=x^{2}+x-2,R(x)=0');
      expectLesson(r, minSteps: 6);
    });

    bothSizes('3. simplificar (x^2-9)/(x^2-6x+9) = (x+3)/(x-3) con fraccion vertical', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac');
      expect(find.byKey(const Key('xform_bar_0')), findsOneWidget);
      await seq(t, '= x sq - 9 = x sq - 6 x + 9 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{x+3}{x-3}');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('4a. resta (x+2)/(x^2-1) - 1/(x-1) = 1/(x^2-1)', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac v v = x + 2 = x sq - 1 = 1 = x - 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{1}{x^{2}-1}');
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4b. cociente (x^2-4)/x : (x+2)/x^2 = x(x - 2)', (t) async {
      await seq(t, 'mode:4 pick:hdr_poly_kind:poly_tab_frac v v v v = x sq - 4 = x = x + 2 = x sq =');
      final r = res(t);
      expect(norm(r.exactResultLatex), anyOf('x^{2}-2x', 'x(x-2)'));
      expectLesson(r, minSteps: 3);
    });
  });
}
