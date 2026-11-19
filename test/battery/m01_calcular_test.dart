import 'package:casio_tutor_calc/domain/math_engine/proportion/proportion_conversion_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e_helpers.dart';
import '../support/exercise_dsl.dart';

void main() {
  group('M1.1 Natural-V.P.A.M.', () {
    bothSizes('1. castillo de fracciones con salida a la derecha = 41/22', (t) async {
      await seq(t, 'frac 2 + 4 v 3 + 1 > + frac 1 v 2 + frac 3 v 4 > > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{41}{22}');
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2. -3^2 + (-3)^2 + 2^10 = 1024 (exponente de dos digitos)', (t) async {
      await seq(t, '- 3 sq + ( - 3 ) sq + 2 S:pow 1 0 > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '1024');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('3. radicales con fracciones = 4/3 - 8 sqrt(5)/9', (t) async {
      await seq(t, 'sqrt frac 1 6 v 9 > > - sqrt frac 2 0 v 9 > > × sqrt frac 1 6 v 9 > > =');
      final r = res(t);
      expect(
        norm(r.exactResultLatex),
        anyOf(r'\frac{4}{3}-\frac{8\sqrt{5}}{9}', r'\frac{12-8\sqrt{5}}{9}', r'\frac{4}{3}-\frac{8}{9}\sqrt{5}'),
      );
      expectLesson(r, minSteps: 3);
    });

    bothSizes('4. racionalizacion = 2 sqrt(3) + 3 + sqrt(5)', (t) async {
      await seq(t, 'frac 6 v sqrt 3 > > + frac 4 v 3 - sqrt 5 > > =');
      final r = res(t);
      expect(norm(r.exactResultLatex), anyOf(r'2\sqrt{3}+3+\sqrt{5}', r'3+2\sqrt{3}+\sqrt{5}', r'3+\sqrt{5}+2\sqrt{3}'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('5. sqrt(-16/9) -> LcdErrorScreen limpio y ◀ vuelve a editar', (t) async {
      await seq(t, 'sqrt frac - 1 6 v 9 > > =');
      expect(find.byType(LcdErrorScreen), findsOneWidget);
      final msg = t.widget<LcdErrorScreen>(find.byType(LcdErrorScreen)).message;
      expect(msg, isNot(contains('Exception')));
      expect(msg, isNot(contains('Instance of')));
      expect(msg, isNot(contains('FormatException')));
      await pad(t, 'left');
      expect(find.byType(LcdErrorScreen), findsNothing);
      expect(find.byKey(const Key('lcd_error_screen')), findsNothing);
    });
  });

  group('M1.2 x simbolica, Arsenal Iberia y Proporcion', () {
    bothSizes('1. 2x + 3x - (x - 1) = 4x + 1 (x minuscula no es 0)', (t) async {
      await seq(t, '2 x + 3 x - ( x - 1 ) =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '4x+1');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('2. decimal periodico mixto 2,1^6 = 13/6 con 100x - 10x', (t) async {
      await seq(t, 'optn > 2 1 2 . 1 > 6 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'\frac{13}{6}');
      expect(lessonText(r), contains('100'));
      expect(lessonText(r), contains('10x'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3a. combinatoria: C(8,3) + V(5,2) = 76', (t) async {
      await seq(t, '8 optn > 2 3 3 + 5 optn > 2 4 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '76');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('3b. 47 ÷R 5 -> C = 9, R = 2', (t) async {
      await seq(t, '4 7 optn > 2 2 5 =');
      final r = res(t);
      final text = lessonText(r);
      expect(text, contains('9'));
      expect(text, contains('2'));
      expect(norm(r.exactResultLatex), anyOf(contains('9'), contains('C')));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('4a. regla de 3 directa: 4 kg -> 6 EUR, 10 kg -> 15', (t) async {
      await seq(t, 'optn > 2 > 2 4 = 6 = 1 0 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '15');
      expectLesson(r, minSteps: 2);
    });

    bothSizes('4b. regla de 3 inversa: 6 obreros -> 12 dias, 9 obreros -> 8', (t) async {
      await seq(t, 'optn > 2 > 3 6 = 1 2 = 9 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), '8');
      expect(lessonText(r).toLowerCase(), contains('inversa'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('5a. conversion 72 km/h -> 20 m/s', (t) async {
      await seq(t, 'optn > 2 > 4 7 2 = = =');
      final r = res(t);
      expect(norm(r.exactResultLatex), startsWith('20'));
      expectLesson(r, minSteps: 2);
    });

    bothSizes('5b. conversion 2,5 g/cm3 -> 2500 kg/m3', (t) async {
      final units = ConversionCatalog.units;
      int idx(String l) => units.indexWhere((u) => u.label == l);
      final n = units.length;
      await seq(t, 'optn > 2 > 4 2 . 5 =');
      final fromSteps = (idx('g/cm3') - idx('km/h') + n) % n;
      for (var i = 0; i < fromSteps; i++) {
        await pad(t, 'down');
      }
      await key(t, '=');
      final toSteps = (idx('kg/m3') - idx('m/s') + n) % n;
      for (var i = 0; i < toSteps; i++) {
        await pad(t, 'down');
      }
      await key(t, '=');
      final r = res(t);
      expect(norm(r.exactResultLatex), startsWith('2500'));
      expectLesson(r, minSteps: 2);
    });
  });
}
