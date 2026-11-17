import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/core/calculator_settings.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_palette.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_powered_off.dart';

import 'support/e2e_helpers.dart';

Future<void> openSetup(WidgetTester t) async {
  await tapF(t, find.text('SHIFT'));
  await tapF(t, find.text('MODE'));
}

Future<void> alpha(WidgetTester t, String label) async {
  await tapF(t, find.text('ALPHA'));
  await key(t, label);
}

Future<void> openMemViewer(WidgetTester t) async {
  await key(t, 'AC');
  await tapF(t, find.text('CALC'));
  expect(find.byKey(const Key('lcd_memory_viewer')), findsOneWidget);
}

StatusBadge badge(WidgetTester t, String label) =>
    t.widget<StatusBadge>(find.byWidgetPredicate((w) => w is StatusBadge && w.label == label));

String? modeLabel(WidgetTester t) => lcd(t).modeLabel;

void main() {
  setUp(CalculatorSettings.reset);

  group('SETUP (SHIFT + MODE)', () {
    testWidgets('Fix 2 redondea la aproximacion de 1/3', (t) async {
      await boot(t);
      await openSetup(t);
      await keys(t, ['2', '2', '2']);
      await keys(t, ['1', '÷', '3', '=']);
      await shiftKey(t, 'S⬄D');
      await tapF(t, find.text('SHIFT'));
      await key(t, '=');
      expect(lcd(t).showDecimalApprox, isTrue);
      expect(lcd(t).currentResolution!.decimalApproxLatex, '0,33');
    });

    testWidgets('GRA actualiza el indicador y sin(100) = 1', (t) async {
      await boot(t);
      await openSetup(t);
      await keys(t, ['1', '3']);
      expect(
        find.descendant(of: find.byKey(const Key('lcd_angle_badge')), matching: find.text('GRA')),
        findsOneWidget,
      );
      await keys(t, ['sin', '1', '0', '0', '=']);
      expect(result(t), '1');
    });

    testWidgets('ab/c muestra 7/2 como numero mixto', (t) async {
      await boot(t);
      await openSetup(t);
      await keys(t, ['3', '2']);
      await keys(t, ['7', '÷', '2', '=']);
      expect(result(t), r'3\frac{1}{2}');
    });

    testWidgets('▲▼ mueven entre opciones y = confirma; AC sube de nivel', (t) async {
      await boot(t);
      await openSetup(t);
      await key(t, '4'); // Separador decimal, opcion actual: Coma
      expect(CalculatorSettings.decimalComma, isTrue);
      await pad(t, 'down'); // Coma -> Punto (vuelta)
      await key(t, '=');
      expect(CalculatorSettings.decimalComma, isFalse);
      await openSetup(t);
      await key(t, '4');
      await key(t, 'AC');
      expect(find.byKey(const Key('lcd_setup_menu')), findsOneWidget);
      await key(t, 'AC');
      expect(find.byKey(const Key('lcd_setup_menu')), findsNothing);
    });

    testWidgets('Tema LCD Nocturno', (t) async {
      await boot(t);
      await openSetup(t);
      await keys(t, ['5', '3']);
      expect(lcd(t).lcdTheme, LcdTheme.night);
    });

    testWidgets('Reset 1 limpia memorias y Reset 2 restaura la configuracion', (t) async {
      await boot(t);
      await keys(t, ['5', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '('); // STO
      await key(t, '7'); // A = 5
      await openSetup(t);
      await keys(t, ['8', '1']); // Limpiar memorias
      await key(t, 'AC');
      await alpha(t, '7');
      await keys(t, ['+', '1', '=']);
      expect(result(t), '1');
      CalculatorSettings.numberFormat = NumberFormatMode.sci;
      await key(t, 'AC');
      await openSetup(t);
      await keys(t, ['8', '2']); // Restaurar config
      expect(CalculatorSettings.numberFormat, NumberFormatMode.norm);
    });
  });

  group('SHIFT + AC (OFF)', () {
    testWidgets('apaga, bloquea teclas y AC enciende limpia', (t) async {
      await boot(t);
      await keys(t, ['5', '+']);
      await shiftKey(t, 'AC');
      expect(find.byType(LcdPoweredOff), findsOneWidget);
      expect(find.text('STEP-BY-STEP LD'), findsWidgets);
      await keys(t, ['7', '=']);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('ALPHA'));
      await pad(t, 'up');
      await pad(t, 'left');
      expect(find.byType(LcdPoweredOff), findsOneWidget);
      await key(t, 'AC');
      expect(find.byType(LcdPoweredOff), findsNothing);
      expect(live(t), '0');
    });
  });

  group('SHIFT + = (≈)', () {
    testWidgets('1/3 muestra directamente el decimal', (t) async {
      await boot(t);
      await keys(t, ['1', '÷', '3']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '=');
      expect(lcd(t).showDecimalApprox, isTrue);
      expect(lcd(t).currentResolution!.exactResultLatex, r'\frac{1}{3}');
    });
  });

  group('SHIFT + + / - (Pol / Rec)', () {
    testWidgets('Pol(1,1) da r y θ paso a paso', (t) async {
      await boot(t);
      await shiftKey(t, '+');
      expect(live(t), contains('Pol'));
      await keys(t, ['1']);
      await pad(t, 'right');
      await keys(t, ['1', '=']);
      final res = lcd(t).currentResolution!;
      expect(res.steps.length, greaterThanOrEqualTo(2));
      expect(res.originalInputLatex, contains('Pol'));
      expect(find.textContaining('Pol/Rec necesita'), findsNothing);
    });

    testWidgets('Rec(2,0) se resuelve y guarda X e Y', (t) async {
      await boot(t);
      await shiftKey(t, '-');
      await keys(t, ['2']);
      await pad(t, 'right');
      await keys(t, ['0', '=']);
      expect(lcd(t).currentResolution!.originalInputLatex, contains('Rec'));
      await openMemViewer(t);
      expect(find.text('X=2'), findsOneWidget);
    });

    testWidgets('Pol con un solo argumento avisa', (t) async {
      await boot(t);
      await shiftKey(t, '+');
      await keys(t, ['1', '=']);
      expect(find.textContaining('Pol/Rec necesita'), findsOneWidget);
    });
  });

  group('SHIFT + DEL (INS)', () {
    testWidgets('alterna insercion y sobrescritura con badge y cursor bloque', (t) async {
      await boot(t);
      await keys(t, ['1', '2']);
      await pad(t, 'left');
      expect(lcd(t).currentInputLatex.contains(r'\blacksquare'), isFalse);
      await shiftKey(t, 'DEL');
      expect(badge(t, 'INS').active, isTrue);
      expect(lcd(t).currentInputLatex.contains(r'\blacksquare'), isTrue);
      await shiftKey(t, 'DEL');
      expect(find.byWidgetPredicate((w) => w is StatusBadge && w.label == 'INS'), findsNothing);
      expect(lcd(t).currentInputLatex.contains(r'\blacksquare'), isFalse);
    });
  });

  group('Memorias M+ / M- y visor', () {
    testWidgets('M+ (SHIFT+ANS) y M- (ALPHA+0) actualizan M y el badge', (t) async {
      await boot(t);
      expect(badge(t, 'M').active, isFalse);
      await keys(t, ['5', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, 'ANS'); // M+ -> M = 5
      expect(badge(t, 'M').active, isTrue);
      await keys(t, ['AC', '3', '=']);
      await alpha(t, '0'); // M- -> M = 2
      await openMemViewer(t);
      expect(find.text('M=2'), findsOneWidget);
    });

    testWidgets('visor: tabla, DEL pone 0, Limpiar y ◀ vuelve', (t) async {
      await boot(t);
      await keys(t, ['4', '=']);
      await tapF(t, find.text('SHIFT'));
      await key(t, '(');
      await key(t, '7'); // A = 4
      await openMemViewer(t);
      for (final n in ['A=4', 'B=0', 'C=0', 'D=0', 'E=0', 'F=0', 'X=0', 'Y=0', 'M=0']) {
        expect(find.text(n), findsOneWidget);
      }
      await key(t, 'DEL'); // A = 0
      expect(find.text('A=0'), findsOneWidget);
      await key(t, '='); // A = Ans
      expect(find.text('A=4'), findsOneWidget);
      await tapF(t, find.byKey(const Key('mem_clear_all')));
      expect(find.text('A=0'), findsOneWidget);
      await pad(t, 'left');
      expect(find.byKey(const Key('lcd_memory_viewer')), findsNothing);
    });
  });

  group('MODE 2D y digitos', () {
    testWidgets('◀ desde la pagina 1 salta a la ultima y = entra en M10', (t) async {
      await boot(t);
      await tapF(t, find.text('MODE'));
      await pad(t, 'left');
      await key(t, '=');
      expect(modeLabel(t), startsWith('M10'));
    });

    for (final n in [5, 6, 7, 8, 9]) {
      testWidgets('digito $n entra directo en M$n', (t) async {
        await boot(t);
        await tapF(t, find.text('MODE'));
        await key(t, '$n');
        expect(modeLabel(t), startsWith('M$n:'));
      });
    }

    testWidgets('1 y 0 entran en M10; 1 solo en M1 tras la espera', (t) async {
      await boot(t);
      await tapF(t, find.text('MODE'));
      await keys(t, ['1', '0']);
      expect(modeLabel(t), startsWith('M10'));
      await tapF(t, find.text('MODE'));
      await key(t, '1');
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(modeLabel(t), startsWith('M1:'));
    });

    testWidgets('▼ y ▶ mueven el foco 2D', (t) async {
      await boot(t);
      await tapF(t, find.text('MODE'));
      await pad(t, 'right');
      await pad(t, 'down');
      await key(t, '=');
      expect(modeLabel(t), startsWith('M4'));
    });
  });

  test('CasioLcdScreen expone showIns y la paleta oliva', () {
    expect(LcdPalette.of(LcdTheme.classic).formula, isNotNull);
    expect(CasioLcdScreen.menuItemCount, 12);
  });
}
