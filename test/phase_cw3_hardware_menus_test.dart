import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/classwiz_constants.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/classwiz_rewrites.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/classwiz_key_actions.dart';
import 'package:casio_tutor_calc/domain/math_engine/arithmetic/unit_conversions.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/rational.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/trig_and_angles_solver.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_blink.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_status_bar.dart';

import 'support/e2e_helpers.dart';

Future<void> optn(WidgetTester t) async {
  await tapF(t, find.text('SHIFT'));
  await tapF(t, find.text('CALC'));
}

Future<void> goMode(WidgetTester t, int n) async {
  await tapF(t, find.text('MODE'));
  if (n > 4) await tapF(t, find.byKey(const Key('menu_page_next')));
  if (n > 8) await tapF(t, find.byKey(const Key('menu_page_next')));
  await tapF(t, find.byKey(Key('menu_mode_$n')));
}

String listTitle(WidgetTester t) => t.widget<Text>(find.byKey(const Key('list_title'))).data!;

StatusBadge badge(WidgetTester t, String label) =>
    t.widget<StatusBadge>(find.byWidgetPredicate((w) => w is StatusBadge && w.label == label));

void main() {
  setUp(CalculatorSettings.reset);

  group('Dominio: constantes y conversiones', () {
    test('catalogo CONST con las 11 constantes y valores CODATA', () {
      expect(ClassWizConstants.all.length, 11);
      expect(ClassWizConstants.byToken('&c')!.value, 299792458);
      expect(ClassWizConstants.byToken('&h')!.value, 6.62607015e-34);
      expect(ClassWizConstants.byToken('&NA')!.value, 6.02214076e23);
    });

    test('evaluacion con constantes en double y notacion cientifica', () {
      expect(ClassWizConstants.evaluate('2&c'), 2 * 299792458);
      expect(ClassWizConstants.evaluate('&h*&c'), closeTo(1.98644586e-25, 1e-33));
      expect(ClassWizConstants.solve('2&c').exactResultLatex, r'5,99584916 \times 10^{8}');
      expect(() => ClassWizConstants.evaluate('&c+'), throwsFormatException);
    });

    test('CONV: factores exactos', () {
      Rational conv(String label, Rational v) =>
          UnitConversions.all.firstWhere((c) => c.label == label).apply(v);
      expect(conv('km/h►m/s', Rational(72)), Rational(20));
      expect(conv('m/s►km/h', Rational(20)), Rational(72));
      expect(conv('atm►Pa', Rational(1)), Rational(101325));
      expect(conv('Pa►atm', Rational(101325)), Rational(1));
      expect(conv('in►cm', Rational(10)), Rational(254, 10));
      expect(conv('cm►in', Rational(254, 10)), Rational(10));
      expect(conv('cal►J', Rational(125)), Rational(523 * 1));
      expect(conv('J►cal', Rational(523)), Rational(125));
      expect(conv('°C►K', Rational(0)), Rational(27315, 100));
      expect(conv('K►°C', Rational(300)), Rational(2685, 100));
      expect(UnitConversions.all.length, 10);
    });

    test('reescrituras: hiperbolicas, sufijos y unidades angulares', () {
      expect(ClassWizRewrites.rewriteHyperbolics('cosh(0)'), '((ℯ^(0)+ℯ^(-(0)))/2)');
      expect(ClassWizRewrites.prepare('5#k', AngleUnit.deg), '5*(1000)');
      expect(ClassWizRewrites.prepare('3#m', AngleUnit.deg), '3*(1/1000)');
      expect(ClassWizRewrites.rewriteAngleSuffix('90#g', AngleUnit.deg), '(90*9/10)');
      expect(ClassWizRewrites.rewriteAngleSuffix('3#r', AngleUnit.deg), '(3*180/π)');
      expect(ClassWizRewrites.rewriteAngleSuffix('3#r', AngleUnit.rad), '(3*1)');
      expect(ClassWizKeyActions.factorLatex(Rational(12)), isNotNull);
    });

    test('LcdBlink: cursor oculto, claro en tema oscuro y nunca azul', () {
      const cur = r'1\textcolor{#1A2530}{\lcdcursor}2';
      expect(LcdBlink.apply(cur, on: false, dark: false), r'1\phantom{\lcdcursor}2');
      expect(LcdBlink.apply(cur, on: true, dark: true), r'1\textcolor{#C8D6CD}{\lcdcursor}2');
      expect(LcdBlink.apply(cur, on: true, dark: false), cur);
      expect(cur.contains('2E86DE'), isFalse);
    });
  });

  group('CW-3.1 indicadores LCD', () {
    testWidgets('M solo se activa con memoria distinta de cero', (t) async {
      await boot(t);
      expect(badge(t, 'M').active, isFalse);
      await keys(t, ['5', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '(');
      expect(badge(t, 'STO').inverted, isTrue);
      await key(t, 'ANS'); // STO -> M
      expect(badge(t, 'M').active, isTrue);
      expect(badge(t, 'M').inverted, isTrue);
    });

    testWidgets('FIX se ve en cajetin invertido tras SETUP Fix', (t) async {
      await boot(t);
      expect(find.text('FIX'), findsNothing);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      await keys(t, ['2', '2', '2']);
      expect(find.text('FIX'), findsOneWidget);
      expect(badge(t, 'FIX').inverted, isTrue);
    });

    testWidgets('SCI se ve tras SETUP Sci', (t) async {
      await boot(t);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      await keys(t, ['2', '3', '5']);
      expect(find.text('SCI'), findsOneWidget);
    });

    testWidgets('las flechas ▲▼ de borde ya no dependen del historial', (t) async {
      await boot(t);
      await keys(t, ['1', '+', '1', '=', 'AC']);
      expect(find.byKey(const Key('edge_up')), findsNothing);
      await pad(t, 'up');
      expect(find.byKey(const Key('edge_down')), findsNothing);
    });

    testWidgets('flechas ◀▶ siguen al cursor', (t) async {
      await boot(t);
      await keys(t, ['1', '2']);
      expect(find.byKey(const Key('edge_left')), findsOneWidget);
      expect(find.byKey(const Key('edge_right')), findsNothing);
      await pad(t, 'left');
      expect(find.byKey(const Key('edge_right')), findsOneWidget);
    });
  });

  group('CW-3.2 OPTN en la LCD', () {
    testWidgets('M1: 5 categorias, AC sube de nivel y cierra', (t) async {
      await boot(t);
      await optn(t);
      expect(find.byKey(const Key('lcd_list_menu')), findsOneWidget);
      expect(find.text('1: Funciones Hiperbólicas'), findsOneWidget);
      expect(find.text('2: Sufijos Ingeniería'), findsOneWidget);
      expect(find.text('3: Unidades Angulares'), findsOneWidget);
      await key(t, '1');
      expect(find.text('1: sinh'), findsOneWidget);
      await key(t, 'AC');
      expect(listTitle(t), 'OPTN');
      await key(t, 'AC');
      expect(find.byKey(const Key('lcd_list_menu')), findsNothing);
    });

    testWidgets('navegacion con ▲▼ y = elige', (t) async {
      await boot(t);
      await optn(t);
      await pad(t, 'down');
      await pad(t, 'down'); // Unidades angulares
      await key(t, '=');
      expect(find.text('1: °'), findsOneWidget);
      expect(find.text('2: r'), findsOneWidget);
      expect(find.text('3: g'), findsOneWidget);
    });

    testWidgets('cosh(0) = 1 desde OPTN', (t) async {
      await boot(t);
      await optn(t);
      await keys(t, ['1', '2', '0', '=']);
      expect(result(t), '1');
    });

    testWidgets('5 k = 5000 con sufijo de ingenieria', (t) async {
      await boot(t);
      await key(t, '5');
      await optn(t);
      await keys(t, ['2', '1', '=']);
      expect(result(t), '5000');
    });

    testWidgets('M9: MatA / MatB / Trn', (t) async {
      await boot(t);
      await goMode(t, 9);
      await optn(t);
      expect(listTitle(t), 'OPTN · Matrices');
      expect(find.text('1: MatA'), findsOneWidget);
      expect(find.text('2: MatB'), findsOneWidget);
      expect(find.text('3: Trn'), findsOneWidget);
      await key(t, '2');
      expect(find.byKey(const Key('lcd_list_menu')), findsNothing);
    });

    testWidgets('M10: VctA / VctB', (t) async {
      await boot(t);
      await goMode(t, 10);
      await optn(t);
      expect(listTitle(t), 'OPTN · Vectores');
      expect(find.text('1: VctA'), findsOneWidget);
      expect(find.text('2: VctB'), findsOneWidget);
      await key(t, '2');
      expect(find.byKey(const Key('lcd_list_menu')), findsNothing);
    });
  });

  group('CW-3.3 CONST y CONV', () {
    testWidgets('SHIFT + 7 abre CONST paginado y 1 inserta c', (t) async {
      await boot(t);
      await shiftKey(t, '7');
      expect(listTitle(t), 'CONST');
      expect(find.text('1/3'), findsOneWidget);
      await pad(t, 'right');
      expect(find.text('2/3'), findsOneWidget);
      await pad(t, 'left');
      await key(t, '1');
      expect(find.byKey(const Key('lcd_list_menu')), findsNothing);
      await key(t, '=');
      expect(result(t), r'2,99792458 \times 10^{8}');
    });

    testWidgets('h * c evalua con constantes', (t) async {
      await boot(t);
      await shiftKey(t, '7');
      await pad(t, 'down');
      await pad(t, 'down');
      await pad(t, 'down'); // h
      await key(t, '=');
      await key(t, '×');
      await shiftKey(t, '7');
      await key(t, '1');
      await key(t, '=');
      expect(find.textContaining('Sintaxis'), findsNothing);
      expect(result(t), contains(r'\times 10^{-25}'));
    });

    testWidgets('SHIFT + 8: 72 km/h = 20 m/s al pulsar =', (t) async {
      await boot(t);
      await keys(t, ['7', '2', '=']);
      await shiftKey(t, '8');
      expect(listTitle(t), 'CONV');
      expect(find.text('1: km/h►m/s'), findsOneWidget);
      await key(t, '=');
      expect(result(t), '20');
    });

    testWidgets('CONV: 5 C -> K y cierre con AC', (t) async {
      await boot(t);
      await keys(t, ['5', '=']);
      await shiftKey(t, '8');
      await pad(t, 'right');
      await pad(t, 'right');
      await key(t, '1'); // pagina 3 -> 9: °C►K
      expect(result(t), r'\frac{5563}{20}');
      await shiftKey(t, '8');
      await key(t, 'AC');
      expect(find.byKey(const Key('lcd_list_menu')), findsNothing);
    });
  });

  group('CW-3.4 chasis y comportamiento', () {
    testWidgets('panel solar en la cabecera', (t) async {
      await boot(t);
      expect(find.byKey(const Key('solar_panel')), findsOneWidget);
      expect(find.text('STEP-BY-STEP LD'), findsOneWidget);
    });

    testWidgets('dos zonas tactiles: cientificas mas oscuras y sin azul', (t) async {
      await boot(t);
      CasioPhysicalKey k(String l) => t.widget<CasioPhysicalKey>(
          find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == l).first);
      final sin = k('sin').backgroundColor!;
      final five = k('5').backgroundColor ?? const Color(0xFF3B4049);
      expect(sin.computeLuminance(), lessThan(five.computeLuminance()));
      for (final c in [sin, five, k('ANS').backgroundColor!, k('×10ˣ').backgroundColor!]) {
        expect(c.b, lessThanOrEqualTo(c.r + 0.1)); // nunca azulados
      }
    });

    testWidgets('DEL mantenido repite el borrado', (t) async {
      await boot(t);
      await keys(t, ['1', '2', '3', '4', '5']);
      final del = find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == 'DEL');
      final g = await t.startGesture(t.getCenter(del.first));
      await t.pump(const Duration(milliseconds: 560));
      await g.up();
      await t.pump();
      expect(live(t).length, lessThanOrEqualTo(3));
    });

    testWidgets('un toque corto en DEL borra solo uno', (t) async {
      await boot(t);
      await keys(t, ['1', '2', '3']);
      await key(t, 'DEL');
      expect(live(t), '12');
    });

    testWidgets('flecha ◀ mantenida repite el desplazamiento', (t) async {
      await boot(t);
      await keys(t, ['1', '2', '3', '4']);
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('replay_left'))));
      await t.pump(const Duration(milliseconds: 560));
      await g.up();
      await t.pump();
      await key(t, '9');
      expect(live(t), '19234');
    });

    testWidgets('parpadeo del cursor cada 530 ms', (t) async {
      LcdBlink.enabled = true;
      addTearDown(() => LcdBlink.enabled = false);
      final seen = <bool>[];
      await t.pumpWidget(MaterialApp(
        home: LcdBlinkBuilder(builder: (c, on) {
          seen.add(on);
          return Text('$on');
        }),
      ));
      expect(find.text('true'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 530));
      expect(find.text('false'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 530));
      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('el cursor de la LCD ya no es azul', (t) async {
      await boot(t);
      await keys(t, ['1', '2']);
      expect(lcd(t).currentInputLatex.contains('2E86DE'), isFalse);
      expect(lcd(t).currentInputLatex.contains('#1A2530'), isTrue);
    });
  });
}
