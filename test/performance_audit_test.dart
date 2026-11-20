@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:casio_tutor_calc/domain/math_engine/functions/function_family.dart';
import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/domain/services/class_history_service.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_key_points.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/widgets/calculator_bezel_widgets.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/blinking_cursor_builder.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_status_bar.dart';
import 'package:casio_tutor_calc/presentation/widgets/side_panel/side_panel_chalkboard_view.dart';
import 'package:casio_tutor_calc/presentation/widgets/side_panel/side_panel_history_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

bool _hasPhantom(GreenNode? n) => n is PhantomNode || (n?.children.any(_hasPhantom) ?? false);

bool _lcdCursorVisible(WidgetTester t) {
  final maths = find.byType(Math).evaluate().map((e) => e.widget as Math).toList();
  return !maths.any((m) => m.ast != null && _hasPhantom(m.ast!.greenRoot));
}

CasioPhysicalKey _key(WidgetTester t, String label) =>
    t.widget<CasioPhysicalKey>(find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label).first);

void main() {
  tearDown(() => ThemeController.instance.resetForTests());

  group('1. Parpadeo aislado', () {
    testWidgets('un tick de 530 ms solo reconstruye la formula, no la barra de estado ni el teclado', (t) async {
      LcdBlink.enabled = true;
      addTearDown(() => LcdBlink.enabled = false);
      await boot(t, size: kDesktop);
      await key(t, '7');
      final statusBefore = t.widget<LcdStatusBar>(find.byType(LcdStatusBar));
      final keyBefore = _key(t, '8');
      final seen = <bool>{};
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 550));
        seen.add(_lcdCursorVisible(t));
      }
      expect(seen, {true, false}, reason: 'el cursor sigue parpadeando');
      expect(identical(t.widget<LcdStatusBar>(find.byType(LcdStatusBar)), statusBefore), isTrue,
          reason: 'la barra de estado no se reconstruye con el parpadeo');
      expect(identical(_key(t, '8'), keyBefore), isTrue, reason: 'el teclado no se reconstruye con el parpadeo');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('sin cursor en el LaTeX no hay temporizador', (t) async {
      LcdBlink.enabled = true;
      addTearDown(() => LcdBlink.enabled = false);
      await boot(t, size: kDesktop);
      await seq(t, '1 + 1 =');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(BlinkingCursorBuilder), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('2. Teclado cacheado', () {
    testWidgets('un digito no reconstruye las teclas; SHIFT y el tema si', (t) async {
      await boot(t, size: kDesktop);
      final before = _key(t, '8');
      await key(t, '5');
      expect(identical(_key(t, '8'), before), isTrue, reason: 'teclear un digito no cambia el teclado');
      await seq(t, '+ 3');
      expect(identical(_key(t, '8'), before), isTrue);
      await tapF(t, find.text('SHIFT'));
      expect(identical(_key(t, '8'), before), isFalse, reason: 'SHIFT cambia las caras');
      await tapF(t, find.text('SHIFT'));
      final again = _key(t, '8');
      ThemeController.instance.select(HardwareThemes.rosa, persist: false);
      await t.pumpAndSettle();
      expect(identical(_key(t, '8'), again), isFalse, reason: 'el tema cambia las teclas');
    });
  });

  group('3. Listas perezosas', () {
    StepByStepResolution longResolution(int n) => StepByStepResolution(
          originalInputLatex: 'x',
          steps: [
            for (var i = 0; i < n; i++)
              MathStep(index: i, shortTitle: 'Paso $i', latexExpression: 'x+$i', pedagogicalNote: 'nota $i'),
          ],
          exactResultLatex: '1',
          decimalApproxLatex: '1',
        );

    testWidgets('DESGLOSE PASO A PASO construye solo los pasos visibles', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: SidePanelChalkboardView(
              resolution: longResolution(80),
              activeStepIndex: 0,
              onSelectStep: (_) {},
              onExportSticker: () {},
              onCopyLatex: () {},
              onOpenAiTutor: () {},
            ),
          ),
        ),
      ));
      await t.pump();
      final built = find.byType(StepBoardTile).evaluate().length;
      expect(built, greaterThan(0));
      expect(built, lessThan(20), reason: 'con 80 pasos solo se construye lo visible, no todo');
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('HISTORIAL con 120 ejercicios es lazy y aisla cada tarjeta', (t) async {
      final res = longResolution(2);
      final entries = [
        for (var i = 0; i < 120; i++)
          ClassHistoryEntry(id: 'e$i', timestamp: DateTime(2026, 1, 1, 10, i % 60), modeName: 'M1', resolution: res),
      ];
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: SidePanelHistoryTab(
              entries: entries,
              historyService: ClassHistoryService(),
              onSelectEntry: (_) {},
              onToggleFavorite: (_) {},
              onDeleteEntry: (_) {},
            ),
          ),
        ),
      ));
      await t.pump();
      final list = find.byType(ListView);
      expect(list, findsOneWidget);
      final cards = find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey<String>);
      expect(cards.evaluate().length, lessThan(25));
      expect(find.byType(Math).evaluate().length, lessThan(40));
      // Cada item de ListView.builder lleva su RepaintBoundary (addRepaintBoundaries).
      final boundaries = find.descendant(of: list, matching: find.byType(RepaintBoundary));
      expect(boundaries.evaluate().length, greaterThanOrEqualTo(cards.evaluate().length));
    });
  });

  group('4. shouldRepaint reales', () {
    test('CarbonTexturePainter: solo repinta si cambian acabado o color', () {
      const a = CarbonTexturePainter(finish: ChassisFinish.carbonDots, color: Color(0x0AFFFFFF));
      const same = CarbonTexturePainter(finish: ChassisFinish.carbonDots, color: Color(0x0AFFFFFF));
      const other = CarbonTexturePainter(finish: ChassisFinish.grain, color: Color(0x14000000));
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(other), isTrue);
    });

    test('KeyPoint compara por valor', () {
      expect(const KeyPoint(1, 2, 'A'), const KeyPoint(1, 2, 'A'));
      expect(const KeyPoint(1, 2, 'A') == const KeyPoint(1, 3, 'A'), isFalse);
      expect(FunctionFamily.values, isNotEmpty);
    });

    testWidgets('el cambio de tema repinta la textura de la carcasa', (t) async {
      await boot(t, size: kDesktop);
      ThemeController.instance.select(HardwareThemes.arena, persist: false);
      await t.pumpAndSettle();
      final painters = find
          .byType(CustomPaint)
          .evaluate()
          .map((e) => (e.widget as CustomPaint).painter)
          .whereType<CarbonTexturePainter>();
      expect(painters.single.finish, ChassisFinish.grain);
    });
  });

  group('5. Arranque web sin flash', () {
    final html = File('web/index.html').readAsStringSync();

    test('el script de tema va antes de flutter_bootstrap.js', () {
      final script = html.indexOf('flutter.selected_hardware_theme');
      expect(script, greaterThan(0));
      expect(script, lessThan(html.indexOf('flutter_bootstrap.js')));
      expect(html, contains("document.documentElement.style.backgroundColor"));
      expect(html, contains('meta[name="theme-color"]'));
    });

    test('los colores del script coinciden con outerBg de cada tema', () {
      for (final theme in HardwareThemes.all) {
        final hex = '#${(theme.outerBg.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
        final entry = RegExp('${theme.id}"?\\s*:\\s*"$hex"', caseSensitive: false);
        expect(entry.hasMatch(html), isTrue, reason: '${theme.id} debe mapear a $hex');
      }
    });

    test('manifest.json usa el fondo real del tema Predeterminado', () {
      final m = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(m['background_color'], '#121418');
      expect(m['theme_color'], '#121418');
      expect(HardwareThemes.defaultTheme.webColorHex, '#121418');
    });

    test('se conserva el desregistro de service workers', () {
      expect(html, contains('getRegistrations'));
    });
  });

  test('ningun .dart de lib/ supera las 500 lineas', () {
    final tooLong = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.dart') && f.readAsLinesSync().length >= 500) tooLong.add(f.path);
    }
    expect(tooLong, isEmpty);
  });
}
