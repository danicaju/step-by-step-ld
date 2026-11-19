import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_helpers.dart';
import '../support/exercise_dsl.dart';

void main() {
  group('M8.1 Estadistica de 1 y 2 variables', () {
    bothSizes('1. xi=[4,6,8,10], fi=[2,5,2,1] -> media 6,4, Me = 6, Mo = 6', (t) async {
      await seq(t, 'mode:8 4 > 2 v < 6 > 5 v < 8 > 2 v < 1 0 > 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'\bar{x}=\frac{32}{5}'));
      expect(norm(r.decimalApproxLatex), contains(r'\bar{x}=6,4'));
      // Me y Mo estan en el ultimo paso de la tabla de frecuencias.
      final text = norm(lessonText(r));
      expect(text, contains('M_{e}&=6'));
      expect(text, contains('M_{o}&=6'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('2. xi=[2,4,6,8,10], fi=1 -> media 6, σ = sqrt(8) ≈ 2,828', (t) async {
      await seq(t, 'mode:8 2 > 1 v < 4 > 1 v < 6 > 1 v < 8 > 1 v < 1 0 > 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'\bar{x}=6'));
      expect(norm(r.exactResultLatex), contains(r'\sigma=2\sqrt{2}'));
      expect(norm(r.decimalApproxLatex), contains('2,828'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3. regresion perfecta (1,3),(2,5),(3,7),(4,9) -> y = 2x + 1, r = 1', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_1 1 > 3 v < 2 > 5 v < 3 > 7 v < 4 > 9 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), 'y=2x+1');
      expect(norm(lessonText(r)), anyOf(contains('r=1'), contains('r=1.0000')));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. regresion (2,4),(4,7),(6,11),(8,14) y estimacion y(5) = 9', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_1 2 > 4 v < 4 > 7 v < 6 > 1 1 v < 8 > 1 4 v < 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'y=\frac{17}{10}x+\frac{1}{2}'));
      expect(norm(r.exactResultLatex), contains(r'\hat{y}(5)=9'));
      expect(lessonText(r), contains('interpolación'));
      expectLesson(r, minSteps: 4);
    });
  });

  group('M8.2 Normal y Binomial', () {
    bothSizes('1. N(100,15): P(X <= 115) = 0,8413 con campana', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_2 = 1 0 0 = 1 5 = 1 1 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'0{,}8413');
      expect(lessonText(r), contains('1'));
      expectLesson(r, minSteps: 4);
      for (var i = 0; i < r.steps.length && find.byKey(const Key('gaussian_bell_clip')).evaluate().isEmpty; i++) {
        await key(t, '=');
      }
      expect(find.byKey(const Key('gaussian_bell_clip')), findsOneWidget);
    });

    bothSizes('2. N(50,10): P(40 <= X <= 70) = 0,8186', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_2 > > = 5 0 = 1 0 = 4 0 = 7 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'0{,}8186');
      expect(norm(lessonText(r)), contains('-1'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('3. B(10, 0,3): P(X = 3) = 0,2668, μ = 3, σ = 1,449', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_3 = 1 0 = 0 . 3 = 3 =');
      final r = res(t);
      expect(norm(r.decimalApproxLatex), contains('0{,}2668'));
      final text = lessonText(r);
      expect(text, contains('1{,}449'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('4. B(8, 0,5): P(X <= 2) = 0,1445', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_3 > = 8 = 0 . 5 = 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{37}{256}');
      expect(norm(r.decimalApproxLatex), contains('0{,}1445'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('5. B(6, 1/6) con p tecleada como fraccion', (t) async {
      await seq(t, 'mode:8 pick:hdr_stat_kind:stat_kind_3 = 6 = frac 1 > 6 = 1 =');
      expect(norm(res(t).exactResultLatex), contains('3125'));
    });
  });
}
