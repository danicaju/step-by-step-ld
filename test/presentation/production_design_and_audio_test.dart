import 'dart:typed_data';

import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/polynomial_equation_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/utils/key_click_sound.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyClickSound Synthesizer (RAM WAV PCM 16-bit mono)', () {
    setUp(() {
      KeyClickSound.setMuted(false);
    });

    test('Sintetiza buffers RIFF/WAVE válidos de ~12 ms con frecuencias distintas (180 Hz vs 320 Hz)', () {
      final ctrlWav = KeyClickSound.buildWavBytes(KeyClickTone.control);
      final stdWav = KeyClickSound.buildWavBytes(KeyClickTone.standard);

      // 44 bytes cabecera + 529 muestras * 2 bytes = 1102 bytes
      expect(ctrlWav.length, equals(44 + KeyClickSound.sampleCount * 2));
      expect(stdWav.length, equals(44 + KeyClickSound.sampleCount * 2));

      expect(String.fromCharCodes(ctrlWav.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(ctrlWav.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(ctrlWav.sublist(12, 16)), equals('fmt '));
      expect(String.fromCharCodes(ctrlWav.sublist(36, 40)), equals('data'));

      final ctrlData = ByteData.sublistView(ctrlWav);
      expect(ctrlData.getUint16(20, Endian.little), equals(1)); // Linear PCM
      expect(ctrlData.getUint16(22, Endian.little), equals(1)); // Mono
      expect(ctrlData.getUint32(24, Endian.little), equals(44100));
      expect(ctrlData.getUint16(34, Endian.little), equals(16)); // 16-bit

      // Las formas de onda control (180 Hz) y estándar (320 Hz) deben diferir
      bool differs = false;
      for (int i = 44; i < ctrlWav.length; i++) {
        if (ctrlWav[i] != stdWav[i]) {
          differs = true;
          break;
        }
      }
      expect(differs, isTrue);

      // La cola debe decaer a casi silencio (< 250 / 32767) para evitar chasquidos
      final lastSample = ctrlData.getInt16(ctrlWav.length - 2, Endian.little).abs();
      expect(lastSample, lessThan(250));
    });

    test('resolveToneForLabel asigna tono grave (~180 Hz) a teclas de control y agudo (~320 Hz) al resto', () {
      for (final label in ['=', 'AC', 'DEL', 'SHIFT', 'ALPHA', 'MODE', 'CALC', '◀', '▶']) {
        expect(KeyClickSound.resolveToneForLabel(label), equals(KeyClickTone.control));
      }
      for (final label in ['7', '0', '+', '×', 'a/b', 'sin', 'ANS']) {
        expect(KeyClickSound.resolveToneForLabel(label), equals(KeyClickTone.standard));
      }
    });

    testWidgets('Botón de silencio lcd_sound_toggle alterna KeyClickSound.isMuted y su icono', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
      );
      await tester.pumpAndSettle();

      expect(KeyClickSound.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('lcd_sound_toggle')));
      await tester.pumpAndSettle();

      expect(KeyClickSound.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('lcd_sound_toggle')));
      await tester.pumpAndSettle();
      expect(KeyClickSound.isMuted, isFalse);
    });
  });

  group('Refactorización de Álgebra, Fracciones y UI STEP-BY-STEP LD', () {
    test('6x = 5 y 2x^2 - 5x = x^2 - 6 resuelven limpio sin 0x, +0, 1x ni /1', () {
      final lin = PolynomialEquationSolver.solveEquationString('6x = 5');
      expect(lin.exactResultLatex, equals(r'x = \frac{5}{6}'));
      expect(lin.steps.first.latexExpression, contains(r'6x = 5 \implies x = \frac{5}{6}'));
      expect(lin.steps.every((s) => s.shortTitle != 'Agrupar incógnitas y términos independientes'), isTrue);

      final direct = PolynomialEquationSolver.solveEquationString('x = 4');
      expect(direct.steps.first.shortTitle, equals('Solución directa'));
      expect(direct.exactResultLatex, equals('x = 4'));

      final quad = PolynomialEquationSolver.solveEquationString('2x^2 - 5x = x^2 - 6');
      expect(quad.exactResultLatex, contains('3'));
      expect(quad.exactResultLatex, contains('2'));

      for (final res in [lin, direct, quad]) {
        for (final step in res.steps) {
          expect(step.latexExpression, isNot(matches(RegExp(r'\b0x\b'))));
          expect(step.latexExpression, isNot(matches(RegExp(r'\b1x\b'))));
          expect(step.latexExpression, isNot(contains('+ 0')));
        }
      }
    });

    test('ExpressionParser renderiza divisiones complejas (x+1)/(x-2) en vertical sin barra /', () {
      final tex = ExpressionParser.rawToLiveLatex('(x+1)/(x-2)');
      expect(tex, contains(r'\frac{'));
      expect(tex, isNot(contains('/')));
    });

    testWidgets('Tecla log■□ muestra subíndice menor (8.5 vs 13) y chasis cumple proporciones LCD en móvil y desktop', (tester) async {
      for (final size in [const Size(390, 844), const Size(1280, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final lcdSize = tester.getSize(find.byType(CasioLcdScreen));
        expect(lcdSize.height, greaterThanOrEqualTo(195.0));

        final baseText = tester.widget<Text>(find.byKey(const Key('log_key_subscript_base')));
        final argText = tester.widget<Text>(find.byKey(const Key('log_key_argument')));
        expect(baseText.style?.fontSize, equals(8.5));
        expect(argText.style?.fontSize, equals(13.0));
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
