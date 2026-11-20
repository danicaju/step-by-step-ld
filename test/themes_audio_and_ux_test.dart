@Tags(['slow'])
library;

import 'dart:io';

import 'package:casio_tutor_calc/core/audio/hardware_sound_synthesizer.dart';
import 'package:casio_tutor_calc/core/editor/editor_undo_stack.dart';
import 'package:casio_tutor_calc/core/editor/ghost_parentheses_helper.dart';
import 'package:casio_tutor_calc/core/input/physical_key_translator.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/utils/key_click_sound.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_dpad.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_palette.dart';
import 'package:casio_tutor_calc/presentation/widgets/windows_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

BoxDecoration _keyDecoration(WidgetTester t, String label) {
  final key = find.byWidgetPredicate((w) => w is CasioPhysicalKey && w.label == label);
  final box = find.descendant(of: key.first, matching: find.byType(AnimatedContainer));
  return t.widget<AnimatedContainer>(box.first).decoration! as BoxDecoration;
}

Future<void> _type(WidgetTester t, String ch, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(key, character: ch);
  await t.sendKeyUpEvent(key);
  await t.pump();
}

Future<void> _press(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(key);
  await t.sendKeyUpEvent(key);
  await t.pump();
}

void main() {
  setUp(() {
    ThemeController.instance.resetForTests();
    KeyClickSound.setMuted(false);
  });
  tearDown(() {
    ThemeController.instance.resetForTests();
    KeyClickSound.setMuted(false);
  });

  group('1. Predeterminado intacto', () {
    test('colores, formas y sonido originales', () {
      final d = HardwareThemes.defaultTheme;
      expect(d.keyShape, KeyCapShape.defaultOriginal);
      expect(d.dpad, DPadMorphology.defaultOriginal);
      expect(d.sound, KeySoundProfile.defaultOriginal);
      expect(d.chassisMid, const Color(0xFF1C1E22));
      expect(d.outerBg, const Color(0xFF121418));
      expect(d.lcdBackground, const Color(0xFFC8D6CD));
      expect(d.keyStyle('7', null, null).background, const Color(0xFF3B4049));
      expect(d.keyStyle('sin', const Color(0xFF1F2227), null).background, const Color(0xFF1F2227));
      expect(d.keyStyle('DEL', const Color(0xFF4A4F5C), null).background, const Color(0xFF4A4F5C));
      expect(d.keyStyle('7', null, null).radius, 6);
      const c = Color(0xFF16191E);
      expect(d.panel(c), c, reason: 'el panel original no se remapea');
      expect(ThemeController.current.id, 'default');
      expect(HardwareSoundSynthesizer.effective, KeySoundProfile.defaultOriginal);
    });

    testWidgets('teclas, D-Pad y LCD siguen igual', (t) async {
      await boot(t, size: kDesktop);
      final deco = _keyDecoration(t, '7');
      expect(deco.color, const Color(0xFF3B4049));
      expect((deco.borderRadius! as BorderRadius).topLeft.x, 6);
      expect(_keyDecoration(t, 'sin').color, const Color(0xFF1F2227));
      expect(t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF121418));
      expect(LcdPalette.of(LcdTheme.classic).background, const Color(0xFFC8D6CD));
      expect(find.byType(CasioReplayPad), findsOneWidget);
      // El sonido original no pasa por los perfiles.
      await key(t, '7');
      expect(HardwareSoundSynthesizer.lastEvent, isNull);
    });
  });

  group('2. Cambio global de tema', () {
    final specs = <(CalculatorHardwareTheme, double, KeyCapShape)>[
      (HardwareThemes.rosa, 15, KeyCapShape.roundedPill),
      (HardwareThemes.arena, 2, KeyCapShape.retroWedge),
      (HardwareThemes.menta, 9, KeyCapShape.flatChiclet),
      (HardwareThemes.perla, 9, KeyCapShape.flatChiclet),
    ];
    for (final (theme, radius, shape) in specs) {
      testWidgets('${theme.name}: fondo, barra, carcasa, teclas, LCD y panel', (t) async {
        await boot(t, size: kDesktop);
        ThemeController.instance.select(theme, persist: false);
        await t.pumpAndSettle();
        expect(t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, theme.outerBg);
        expect(t.widget<AppBar>(find.byType(AppBar)).backgroundColor, theme.appBarBg);
        final chassis = find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == theme.chassisMid);
        expect(chassis, findsWidgets);
        final deco = _keyDecoration(t, '7');
        expect(deco.color, theme.numKey);
        expect((deco.borderRadius! as BorderRadius).topLeft.x, radius);
        expect(theme.keyShape, shape);
        expect(_keyDecoration(t, 'DEL').color, theme.delAcKey);
        expect(LcdPalette.of(LcdTheme.classic).background, theme.lcdBackground);
        final panel = find.descendant(of: find.byType(WindowsSidePanel), matching: find.byType(Container)).first;
        expect((t.widget<Container>(panel).decoration! as BoxDecoration).color, theme.panelBg);
        expect(theme.webColorHex, '#${(theme.outerBg.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}');
      });
    }

    test('colores exactos pedidos', () {
      expect(HardwareThemes.rosa.chassisMid, const Color(0xFFE89EB8));
      // C95D82 -> C34A73: con el rosa original el texto blanco quedaba en 3.9:1 (auditoria WCAG).
      expect(HardwareThemes.rosa.funcKey, const Color(0xFFC34A73));
      expect(HardwareThemes.rosa.panelBg, const Color(0xFFF5DCE5));
      expect(HardwareThemes.rosa.panelCard, const Color(0xFFFFF7FA));
      expect(HardwareThemes.arena.chassisMid, const Color(0xFFD8CEBC));
      expect(HardwareThemes.arena.outerBg, const Color(0xFFC4B8A3));
      expect(HardwareThemes.arena.delAcKey, const Color(0xFFB85446));
      expect(HardwareThemes.menta.chassisMid, const Color(0xFF88AD98));
      expect(HardwareThemes.menta.delAcKey, const Color(0xFFB85A4A));
      expect(HardwareThemes.perla.chassisMid, const Color(0xFFE3E6EC));
      expect(HardwareThemes.perla.panelBg, const Color(0xFFECEFF4));
      expect(HardwareThemes.rosa.dpad, DPadMorphology.circularPetal);
      expect(HardwareThemes.arena.dpad, DPadMorphology.retroCross);
      expect(HardwareThemes.menta.dpad, DPadMorphology.minimalRing);
      expect(HardwareThemes.perla.dpad, DPadMorphology.defaultOriginal);
      expect(HardwareThemes.all.length, 5);
    });

    test('el panel oscuro original se traduce al tema', () {
      expect(HardwareThemes.rosa.panel(const Color(0xFF16191E)), HardwareThemes.rosa.panelBg);
      expect(HardwareThemes.rosa.panel(const Color(0xFFE2E8F0)), HardwareThemes.rosa.panelText);
      expect(HardwareThemes.arena.panel(const Color(0xFFE5A93C)), HardwareThemes.arena.panelAccent);
    });

    test('index.html sin bordes blancos en movil', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('viewport-fit=cover'));
      expect(html, contains('overscroll-behavior: none'));
      expect(html, contains('theme-color'));
    });

    testWidgets('el selector TEMA cambia el tema', (t) async {
      await boot(t, size: kDesktop);
      await tapF(t, find.byKey(const Key('appbar_theme')));
      expect(find.byKey(const Key('theme_picker_card')), findsOneWidget);
      await tapF(t, find.byKey(const Key('theme_option_menta')));
      expect(ThemeController.current.id, 'menta');
      expect(find.byKey(const Key('theme_picker_card')), findsNothing);
    });

    testWidgets('SETUP elige el tema con D-Pad y teclas', (t) async {
      await boot(t, size: kDesktop);
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      expect(find.text('SETUP  1/4'), findsOneWidget);
      await key(t, '9');
      await key(t, '2');
      expect(ThemeController.current.id, 'rosa');
    });
  });

  group('3. Perfiles de sonido', () {
    test('un perfil por tema', () {
      expect(HardwareThemes.rosa.sound, KeySoundProfile.softSilicone);
      expect(HardwareThemes.arena.sound, KeySoundProfile.retroMechanical);
      expect(HardwareThemes.menta.sound, KeySoundProfile.minimalChiclet);
      expect(HardwareThemes.perla.sound, KeySoundProfile.studioCrisp);
      ThemeController.instance.select(HardwareThemes.arena, persist: false);
      expect(HardwareSoundSynthesizer.effective, KeySoundProfile.retroMechanical);
    });

    test('cada perfil sintetiza impulsos y diferencia categorias', () {
      for (final p in KeySoundProfile.values.skip(1)) {
        for (final c in SoundCategory.values) {
          expect(HardwareSoundSynthesizer.pulsesFor(p, c), isNotEmpty, reason: '$p $c');
        }
      }
      expect(HardwareSoundSynthesizer.pulsesFor(KeySoundProfile.defaultOriginal, SoundCategory.digit), isEmpty);
      final rDigit = HardwareSoundSynthesizer.pulsesFor(KeySoundProfile.retroMechanical, SoundCategory.digit);
      expect(rDigit.length, 2, reason: 'doble transitorio');
      final sDigit = HardwareSoundSynthesizer.pulsesFor(KeySoundProfile.studioCrisp, SoundCategory.digit);
      final sEq = HardwareSoundSynthesizer.pulsesFor(KeySoundProfile.studioCrisp, SoundCategory.equals);
      expect(sDigit.first.freq != sEq.first.freq, isTrue);
      expect(HardwareSoundSynthesizer.categoryForLabel('='), SoundCategory.equals);
      expect(HardwareSoundSynthesizer.categoryForLabel('AC'), SoundCategory.delete);
      expect(HardwareSoundSynthesizer.categoryForLabel('7'), SoundCategory.digit);
    });

    testWidgets('al pulsar suena el perfil del tema; SETUP lo sobrescribe', (t) async {
      await boot(t, size: kDesktop);
      ThemeController.instance.select(HardwareThemes.rosa, persist: false);
      await t.pumpAndSettle();
      await key(t, '7');
      expect(HardwareSoundSynthesizer.lastEvent?.profile, KeySoundProfile.softSilicone);
      expect(HardwareSoundSynthesizer.lastEvent?.category, SoundCategory.digit);
      await key(t, '=');
      expect(HardwareSoundSynthesizer.lastEvent?.category, SoundCategory.equals);

      // SETUP -> fila 10 "Sonido Teclas" (tecla 0) -> opcion 4 "Retro Mecanico".
      await tapF(t, find.text('SHIFT'));
      await tapF(t, find.text('MODE'));
      await key(t, '0');
      await key(t, '4');
      expect(HardwareSoundSynthesizer.override, KeySoundProfile.retroMechanical);
      await key(t, '7');
      expect(HardwareSoundSynthesizer.lastEvent?.profile, KeySoundProfile.retroMechanical);
    });

    testWidgets('con el altavoz apagado ningun perfil suena', (t) async {
      await boot(t, size: kDesktop);
      ThemeController.instance.select(HardwareThemes.perla, persist: false);
      await t.pumpAndSettle();
      HardwareSoundSynthesizer.lastEvent = null;
      KeyClickSound.setMuted(true);
      await key(t, '7');
      await pad(t, 'left');
      expect(HardwareSoundSynthesizer.lastEvent, isNull);
    });
  });

  group('4. Teclado fisico', () {
    test('traduccion de teclas y funciones', () {
      final tr = PhysicalKeyTranslator();
      List<String> run(LogicalKeyboardKey k, String? ch, {bool shift = false}) =>
          (tr.translate(logical: k, character: ch, shift: shift) ?? []).map((a) => a.toString()).toList();
      expect(run(LogicalKeyboardKey.digit2, '2'), ['key:2']);
      expect(run(LogicalKeyboardKey.comma, ','), ['key:.']);
      expect(run(LogicalKeyboardKey.slash, '/'), ['key:/']);
      expect(run(LogicalKeyboardKey.slash, '/', shift: true), ['key::']);
      expect(run(LogicalKeyboardKey.enter, null), ['key:=']);
      expect(run(LogicalKeyboardKey.arrowUp, null), ['dpad:up']);
      expect(run(LogicalKeyboardKey.keyX, 'x'), ['key:ALPHA', 'key:)']);
      // sin( -> tecla sin
      expect(run(LogicalKeyboardKey.keyS, 's'), isEmpty);
      expect(run(LogicalKeyboardKey.keyI, 'i'), isEmpty);
      expect(run(LogicalKeyboardKey.keyN, 'n'), isEmpty);
      expect(run(LogicalKeyboardKey.parenthesisLeft, '('), ['key:sin']);
      // sqrt( y ln(
      for (final c in 'sqrt'.split('')) {
        run(LogicalKeyboardKey.keyA, c);
      }
      expect(run(LogicalKeyboardKey.parenthesisLeft, '('), ['key:√']);
      for (final c in 'ln'.split('')) {
        run(LogicalKeyboardKey.keyA, c);
      }
      expect(run(LogicalKeyboardKey.parenthesisLeft, '('), ['key:ALPHA', 'key:LOG']);
      expect(tr.translate(logical: LogicalKeyboardKey.keyZ, ctrlOrMeta: true)!.single.kind, PhysicalActionKind.undo);
      expect(tr.translate(logical: LogicalKeyboardKey.keyP, alt: true)!.single.value, 'PI');
      expect(tr.translate(logical: LogicalKeyboardKey.keyC, character: 'c', ctrlOrMeta: true), isNull);
    });

    testWidgets('2+3*4 + Enter = 14; Backspace; Escape; Ctrl+Z', (t) async {
      await boot(t, size: kDesktop);
      await _type(t, '2', LogicalKeyboardKey.digit2);
      await _type(t, '+', LogicalKeyboardKey.numpadAdd);
      await _type(t, '3', LogicalKeyboardKey.digit3);
      await _type(t, '*', LogicalKeyboardKey.numpadMultiply);
      await _type(t, '4', LogicalKeyboardKey.digit4);
      await _press(t, LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(norm(res(t).exactResultLatex), '14');

      // Escape = AC; Ctrl+Z restaura la expresion.
      await _press(t, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('lcd_undo_pill')), findsOneWidget);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await _press(t, LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(lcd(t).currentInputLatex, contains('4'));
      expect(find.byKey(const Key('lcd_undo_pill')), findsNothing);

      // Backspace borra el ultimo digito.
      await _press(t, LogicalKeyboardKey.backspace);
      expect(lcd(t).currentInputLatex.contains('4'), isFalse);
    });

    testWidgets('la pastilla DESHACER restaura tras AC', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, '7 + 8 AC');
      expect(find.byKey(const Key('lcd_undo_pill')), findsOneWidget);
      await tapF(t, find.byKey(const Key('lcd_undo_pill')));
      expect(lcd(t).currentInputLatex, contains('8'));
      expect(find.byKey(const Key('lcd_undo_pill')), findsNothing);
    });

    testWidgets('con un desplegable abierto, las teclas operan dentro', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:2');
      await tapF(t, find.byKey(const Key('hdr_eq_kind')));
      expect(find.byKey(const Key('lcd_dropdown_panel')), findsOneWidget);
      await _press(t, LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('lcd_dropdown_panel')), findsNothing);
    });
  });

  group('5. Parentesis fantasma y Undo', () {
    test('helper de parentesis', () {
      expect(GhostParenthesesHelper.pendingCount(r'\sin(30'), 1);
      expect(GhostParenthesesHelper.pendingCount('((2+3)'), 1);
      expect(GhostParenthesesHelper.pendingCount('(1)'), 0);
      expect(GhostParenthesesHelper.closeAll('sin(30'), 'sin(30)');
      expect(GhostParenthesesHelper.ghostLatex('2+3', ink: Colors.black, background: Colors.white), '');
      expect(GhostParenthesesHelper.ghostLatex('((1', ink: Colors.black, background: Colors.white), contains('))'));
      expect(GhostParenthesesHelper.ghostOpacity, 0.35);
    });

    test('pila de deshacer: maximo 30 estados', () {
      final s = EditorUndoStack();
      expect(s.push('0', 1), isFalse);
      for (var i = 1; i <= 35; i++) {
        s.push('$i+1', 1);
      }
      expect(s.length, 30);
      expect(s.pop()!.expression, '35+1');
      expect(s.pop()!.expression, '34+1');
    });

    testWidgets('sin(30 dibuja el cierre fantasma y = lo cierra', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'sin 3 0 > DEL');
      final pal = LcdPalette.of(LcdTheme.classic);
      final ghost = GhostParenthesesHelper.ghostLatex('sin(30', ink: pal.formula, background: pal.background);
      expect(ghost, isNotEmpty);
      expect(lcd(t).currentInputLatex, contains(ghost));
      await key(t, '=');
      await t.pumpAndSettle();
      expect(norm(res(t).exactResultLatex), r'\frac{1}{2}');
    });
  });

  group('6. Copia rapida', () {
    testWidgets('tocar el resultado copia y muestra la insignia Copiado 1,8 s', (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await boot(t, size: kDesktop);
      await seq(t, '1 + 1 =');
      for (var i = 0; i < 8 && find.byKey(const Key('lcd_result_copy')).evaluate().isEmpty; i++) {
        await key(t, '=');
      }
      expect(find.byKey(const Key('lcd_result_copy')), findsOneWidget);
      expect(find.byKey(const Key('lcd_copy_icon')), findsOneWidget);
      await t.tap(find.byKey(const Key('lcd_result_copy')));
      await t.pump();
      await t.pump();
      expect(copied, '2');
      expect(find.byKey(const Key('lcd_copied_badge')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1700));
      expect(find.byKey(const Key('lcd_copied_badge')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('lcd_copied_badge')), findsNothing);
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
