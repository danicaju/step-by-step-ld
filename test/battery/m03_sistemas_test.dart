import 'package:flutter_test/flutter_test.dart';

import '../support/exercise_dsl.dart';

void main() {
  group('M3 Sistemas 2x2', () {
    for (final m in ['sustitucion', 'igualacion', 'reduccion']) {
      bothSizes('1. 2x - y = 5, 3x + 2y = 4 por $m -> x = 2, y = -1', (t) async {
        await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef pick:hdr_sys_method:sys_method_$m 2 = - 1 = 5 = 3 = 2 = 4 =');
        final r = res(t);
        final text = norm(lessonText(r));
        expect(text, contains('x=2'));
        expect(text, contains('y=-1'));
        expectLesson(r, minSteps: 3);
      });
    }

    bothSizes('2. con denominadores x/2 + y/3 = 4, x - y = 3 -> x = 6, y = 3', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef frac 1 > 2 = frac 1 > 3 = 4 = 1 = - 1 = 3 =');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains('x=6'));
      expect(text, contains('y=3'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3. incompatible (rectas paralelas) -> SI', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef 2 = - 4 = 6 = 1 = - 2 = 5 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, anyOf(contains('SI'), contains('incompatible'), contains('Incompatible')));
      expect(text.toLowerCase(), contains('sin solucion'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('4. compatible indeterminado -> SCI', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef 3 = - 6 = 9 = 1 = - 2 = 3 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, anyOf(contains('SCI'), contains('indeterminado'), contains('Indeterminado')));
      expect(text.toLowerCase(), contains('infinitas'));
      expectLesson(r, minSteps: 2);
    });
  });

  group('M3 Sistemas 3x3', () {
    bothSizes('5. x+y+z=6, 2x-y+z=3, x+2y-z=2 por Gauss -> (1, 2, 3)', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef pick:hdr_sys_size:sys_dim_3 1 = 1 = 1 = 6 = 2 = - 1 = 1 = 3 = 1 = 2 = - 1 = 2 =');
      final r = res(t);
      final text = norm(lessonText(r));
      expect(text, contains('x=1'));
      expect(text, contains('y=2'));
      expect(text, contains('z=3'));
      expect(text.toLowerCase(), contains('gauss'));
      expectLesson(r, minSteps: 3);
    });
  });
}
