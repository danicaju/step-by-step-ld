import 'package:flutter_test/flutter_test.dart';

import '../support/exercise_dsl.dart';

void main() {
  group('M2.1 Polinomicas', () {
    bothSizes('1. (2x-1)/3 - (x-4)/2 = 1 -> x = -4', (t) async {
      await seq(t, 'mode:2 frac 2 x - 1 v 3 > - frac x - 4 v 2 > > 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), anyOf('x=-4', '-4'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. 3x^2 + 2 = 2x -> sin solucion real (Δ = -20)', (t) async {
      await seq(t, 'mode:2 3 x sq + 2 > 2 x =');
      final r = res(t);
      expect(lessonText(r), contains('-20'));
      expect(lessonText(r).toLowerCase(), contains('sin'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('3. x^4 - 5x^2 - 36 = 0 -> t = 9, t = -4 descartada, x = ±3', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_2 x S:pow 4 > - 5 x sq - 3 6 > 0 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, contains('9'));
      expect(text, contains('-4'));
      expect(text.toLowerCase(), contains('descart'));
      expect(norm(r.exactResultLatex), anyOf(contains('3'), contains('pm')));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. x^3 - 4x^2 + x + 6 = 0 por Ruffini -> {-1, 2, 3}', (t) async {
      await seq(t, 'mode:2 x S:pow 3 > - 4 x sq + x + 6 > 0 =');
      final r = res(t);
      final text = norm(lessonText(r));
      for (final root in ['-1', '2', '3']) {
        expect(text, contains(root));
      }
      expect(text.toLowerCase(), contains('ruffini'));
      expectLesson(r, minSteps: 3);
    });
  });

  group('M2.2 Racionales, irracionales, exponenciales, logaritmicas, trigonometricas', () {
    bothSizes('1. racional: x = 2 prohibida, x = -6 valida (el banco decia -4)', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_3 frac x v x - 2 > + frac 2 v x + 2 > > frac 8 v x sq - 4 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, contains('-6'));
      expect(text.toLowerCase(), contains('prohib'));
      expect(norm(r.exactResultLatex), anyOf('x=-6', '-6'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. irracional: sqrt(2x+3) + x = 6 -> x = 3 valida, x = 11 falsa', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_4 sqrt 2 x + 3 > + x > 6 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, contains('11'));
      expect(text.toLowerCase(), contains('fals'));
      expect(norm(r.exactResultLatex), anyOf('x=3', '3'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3. exponencial: 2^(2x) - 5*2^x + 4 = 0 -> x = 0, x = 2', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_5 2 S:pow 2 x > - 5 × 2 S:pow x > + 4 > 0 =');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains('x=0'));
      expect(text, contains('x=2'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4a. logaritmica fraccionaria -> x = 2 (descarta x = 0)', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_6 frac log 1 0 > 2 x sq + 1 > v log 1 0 > x + 1 > > > 2 =');
      final r = res(t);
      final text = lessonText(r);
      expect(norm(r.exactResultLatex), anyOf('x=2', '2'));
      expect(text, contains('0'));
      expect(text.toLowerCase(), anyOf(contains('descart'), contains('anula'), contains('no vali')));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4b. log2(x+3) + log2(x-3) = 4 -> x = 5 (descarta x = -5)', (t) async {
      await seq(t, 'mode:2 pick:hdr_eq_kind:eq_kind_6 log 2 > x + 3 > + log 2 > x - 3 > > 4 =');
      final r = res(t);
      final text = lessonText(r);
      expect(norm(r.exactResultLatex), anyOf('x=5', '5'));
      expect(text, contains('-5'));
      expect(text.toLowerCase(), contains('descart'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('5. trigonometrica DEG: sin(x) = 1/2 -> 30° y 150°', (t) async {
      await seq(t, 'mode:2 sin x > > frac 1 v 2 =');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains('30'));
      expect(text, contains('150'));
      expectLesson(r, minSteps: 2);
    });
  });
}
