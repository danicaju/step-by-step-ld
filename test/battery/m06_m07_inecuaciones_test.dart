import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/exercise_dsl.dart';

const _ge = 'pick:hdr_ineq_sign:ineq_sign_greaterOrEqual';
const _le = 'pick:hdr_ineq_sign:ineq_sign_lessOrEqual';
const _gt = 'pick:hdr_ineq_sign:ineq_sign_greater';
const _lt = 'pick:hdr_ineq_sign:ineq_sign_less';

const _sge = 'pick:hdr_ineqsys_sign:ineq_sign_greaterOrEqual';
const _sle = 'pick:hdr_ineqsys_sign:ineq_sign_lessOrEqual';
const _sgt = 'pick:hdr_ineqsys_sign:ineq_sign_greater';

void main() {
  group('M6 Inecuaciones de 1 incognita', () {
    bothSizes('1. -3x + 6 >= 15 -> (-inf, -3] (inversion de signo)', (t) async {
      await seq(t, 'mode:6 - 3 x + 6 $_ge 1 5 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'(-\infty,-3]'));
      expect(lessonText(r).toLowerCase(), contains('invert'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. x^2 - 5x + 6 <= 0 -> [2, 3]', (t) async {
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_2 x sq - 5 x + 6 $_le 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '[2,3]');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('3. x^2 + 2x + 5 > 0 -> R (Δ < 0, siempre positiva)', (t) async {
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_2 x sq + 2 x + 5 $_gt 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'(-\infty,+\infty)');
      expect(lessonText(r), contains('Δ < 0'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('4. (x-1)/(x+2) >= 0 -> (-inf, -2) U [1, +inf) con tabla de signos', (t) async {
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_3 frac x - 1 v x + 2 > $_ge 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'(-\infty,-2)\cup[1,+\infty)');
      expect(lessonText(r), contains(r'\begin{array}'));
      expect(lessonText(r).toLowerCase(), contains('prohibid'));
      expectLesson(r, minSteps: 4);
    });

    bothSizes('5. |2x - 4| < 6 -> (-1, 5) con la tecla |x| de OPTN', (t) async {
      await seq(t, 'mode:6 pick:hdr_ineq_kind:ineq_deg_3 quickoptn quick:Abs( 2 x - 4 > $_lt 6 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'x\in(-1,5)');
      expectLesson(r, minSteps: 2);
    });
  });

  group('M7 Sistemas de inecuaciones (entrada directa)', () {
    bothSizes('1. x^2 - 9 <= 0 y 2x - 2 > 0 -> (1, 3]', (t) async {
      await seq(t, 'mode:7 x sq - 9 $_sle 0 v 2 x - 2 $_sgt 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'S_{f}=(1,3]');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. x > 4 y x <= 1 -> vacio', (t) async {
      await seq(t, 'mode:7 x $_sgt 4 v x $_sle 1 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'S_{f}=\emptyset');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3. region acotada x>=0, y>=0, x+y<=4: vertices (0,0), (4,0), (0,4)', (t) async {
      await seq(t, 'mode:7 pick:hdr_ineqsys_unknowns:ineqsys_unk_2 pick:hdr_ineqsys_rows:ineqsys_rows_3 x $_sge 0 v y $_sge 0 v x + y $_sle 4 =');
      expect(find.byType(CustomPaint), findsWidgets);
      await seq(t, 'steps');
      final r = res(t);
      final text = norm(r.exactResultLatex);
      expect(text, contains('acotada'));
      for (final v in ['A(0,0)', 'B(4,0)', 'C(0,4)']) {
        expect(text, contains(v));
      }
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. region no acotada x+y>0, x-2y<=4: no es vacia', (t) async {
      await seq(t, 'mode:7 pick:hdr_ineqsys_unknowns:ineqsys_unk_2 x + y $_sgt 0 v x - 2 y $_sle 4 = steps');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains('noacotada'));
      expect(norm(r.exactResultLatex), isNot(contains('emptyset')));
      expectLesson(r, minSteps: 3);
    });
  });
}
