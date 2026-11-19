import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_helpers.dart';
import '../support/exercise_dsl.dart';

void main() {
  group('M5.1 Familias de funciones (Estudio + Grafica)', () {
    bothSizes('1. parabola f(x) = -x^2 + 4x - 3: V(2,1), OX (1,0),(3,0), OY (0,-3)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_2 - x sq + 4 x - 3 =');
      expect(find.byKey(const Key('mode5_view_toggle')), findsOneWidget);
      await seq(t, 'steps');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains(r'\text{Vertice}(2,1)'));
      expect(text, contains(r'x_{1}=3,x_{2}=1'));
      expect(text, contains(r'(0,-3)'));
      expectLesson(r, minSteps: 5);
    });

    bothSizes('2. racional (2x+1)/(x-3): Dom = R\\{3}, AV x = 3, AH y = 2', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_4 frac 2 x + 1 v x - 3 >');
      // La plantilla es una fraccion vertical real.
      expect(lcd(t).currentInputLatex, contains(r'\frac'));
      await seq(t, '= steps');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains(r'\mathbb{R}\setminus\{3\}'));
      expect(norm(r.exactResultLatex), contains('AV:x=3'));
      expect(norm(r.exactResultLatex), contains('AH:y=2'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3a. radical sqrt(2x - 4): Dom = [2, +inf)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_5 sqrt 2 x - 4 > = steps');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'[2,+\infty)'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3b. log_2(x - 1): Dom = (1, +inf), AV x = 1', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_6 log 2 > x - 1 > = steps');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'(1,+\infty)'));
      expect(norm(r.exactResultLatex), contains('AV:x=1'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4a. exponencial 2^x: AH y = 0 y corte (0, 1)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_6 2 S:pow x > = steps');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('AH:y=0'));
      expect(norm(lessonText(r)), contains('(0,1)'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4b. tan(x): asintotas en 90° + k·180° (DEG)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_kind:graph_kind_7 tan x > = steps');
      final r = res(t);
      expect(norm(lessonText(r)), contains(r'90^\circ+k\cdot180^\circ'));
      expectLesson(r, minSteps: 4);
    });
  });

  group('M5.2 Limites y TABLE', () {
    bothSizes('1. lim x->2 (x^2-4)/(x^2-5x+6) = -4 (0/0 por factorizacion)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_view:graph_view_1 ( x sq - 4 ) frac ( x sq - 5 x + 6 ) = 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '-4');
      expect(lessonText(r), contains('0/0'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('2. lim x->0 (sqrt(x+4) - 2)/x = 1/4 (conjugado)', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_view:graph_view_1 ( sqrt x + 4 ) - 2 ) frac x = 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{1}{4}');
      expect(lessonText(r).toLowerCase(), contains('conjugado'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3. lim x->+inf (3x^2+1)/(2x^2-5) = 3/2', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_view:graph_view_1 ( 3 x sq + 1 ) frac ( 2 x sq - 5 ) > v v v =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{3}{2}');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. TABLE f = 1/(x-1), g = x^2 en [0,2] paso 0,5: Error / AV en x = 1', (t) async {
      await seq(t, 'mode:5 pick:hdr_graph_view:graph_view_2 1 frac ( x - 1 ) = x sq = 0 = 2 = 0 . 5 =');
      expect(find.textContaining('Error / AV'), findsWidgets);
      expect(find.byKey(const Key('lcd_error_screen')), findsNothing);
    });
  });
}
