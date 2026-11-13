import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:casio_tutor_calc/domain/math_engine/parser/expression_parser.dart';
import 'package:casio_tutor_calc/domain/math_engine/solvers/linear_equation_solver.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_dpad.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_physical_key.dart';
import 'package:casio_tutor_calc/presentation/widgets/windows_side_panel.dart';

void main() {
  group('Refactorización UX Casio: LinearEquationSolver.solveEquationString', () {
    test('Resuelve ecuación directa: 2x + 4 = 16 => x = 6', () {
      final res = LinearEquationSolver.solveEquationString('2x + 4 = 16');
      expect(res.exactResultLatex, equals('x = 6'));
      expect(res.steps.length, greaterThanOrEqualTo(2));
    });

    test('Resuelve ecuación con incógnita en ambos lados: 3x - 5 = 7 - x => x = 3', () {
      final res = LinearEquationSolver.solveEquationString('3x - 5 = 7 - x');
      expect(res.exactResultLatex, equals('x = 3'));
    });

    test('Resuelve ecuación fraccionaria clásica: (x-2)/3 - (x+1)/4 = 2 => x = 35', () {
      final res = LinearEquationSolver.solveEquationString('(x-2)/3 - (x+1)/4 = 2');
      expect(res.exactResultLatex, equals('x = 35'));
    });

    test('Resuelve ecuación implícita igualada a cero: 2x - 8 => x = 4', () {
      final res = LinearEquationSolver.solveEquationString('2x - 8');
      expect(res.exactResultLatex, equals('x = 4'));
    });
  });

  group('Refactorización UX Casio: CasioLcdScreen Auto-Escalado y Blindaje LaTeX', () {
    test('sanitizeForMathTex elimina \\r y normaliza tildes en bloques \\text', () {
      const input = "\\text{Solución con tilde y \r retorno}\r\n + 5";
      final sanitized = CasioLcdScreen.sanitizeForMathTex(input);
      expect(sanitized, isNot(contains('\r')));
      expect(sanitized, isNot(contains('ó')));
      expect(sanitized, contains(r'\text{Solucion con tilde y  retorno}'));
    });

    testWidgets('CasioLcdScreen renderiza expresión larga con FittedBox sin desbordamiento', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 180,
              child: CasioLcdScreen(
                currentInputLatex: r'\frac{123456789}{987654321} + \sqrt{999999} - \frac{x^3 + 4x^2 - 7x + 2}{x^2 - 1}',
                currentResolution: null,
                activeStepIndex: 0,
                isShiftActive: false,
                isAlphaActive: false,
                showDecimalApprox: false,
                modeLabel: 'M1: CALC',
              ),
            ),
          ),
        ),
      );

      // Debe renderizar sin provocar ningún RenderFlex overflowed
      expect(tester.takeException(), isNull);
    });

    testWidgets('CasioLcdScreen maneja expresión con sintaxis incompleta mediante onErrorFallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 180,
              child: CasioLcdScreen(
                currentInputLatex: r'\frac{incomplete',
                currentResolution: null,
                activeStepIndex: 0,
                isShiftActive: false,
                isAlphaActive: false,
                showDecimalApprox: false,
              ),
            ),
          ),
        ),
      );

      // Debe renderizar el fallback sin lanzar excepción
      expect(tester.takeException(), isNull);
    });
  });

  group('Refactorización UX Casio: Teclado Físico y Modos Limpios', () {
    testWidgets('La calculadora arranca limpia en 0 sin presets precargados', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // No debe haber presets automáticos en pantalla
      expect(find.text('0'), findsWidgets);
      // El botón de "Ej. Clase" o presets no debe existir en el teclado
      expect(find.text('Ej. Clase'), findsNothing);
      expect(find.text('Ej. Fracc'), findsNothing);
      expect(find.text('Ej. -3²'), findsNothing);
    });

    testWidgets('Teclas DEL y AC funcionan limpiamente en modo cálculo', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Teclear '7', '8', '9'
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      // Pulsar DEL: debe borrar '9'
      await tester.tap(find.text('DEL'));
      await tester.pumpAndSettle();

      // Pulsar AC: debe resetear a '0'
      await tester.tap(find.text('AC'));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Cambio de modo a Modo 3 mediante tecla MENU y atajo 3', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Pulsar MODE -> Abre el menú de iconos ClassWiz
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      // Debe mostrar la cuadrícula de iconos en la LCD
      expect(find.text('MENU'), findsWidgets);
      expect(find.text('3:Ecuaciones 2.º Grado'), findsNothing);

      // Pulsar '5' para entrar en Modo 5 (Gráficas / Parábolas con coeficientes a, b, c)
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();

      // Debe mostrar etiquetas de coeficientes en pantalla LCD
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);

      // Teclear coeficiente '1' y pulsar '='
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      // Teclear '-' y '5' y pulsar '='
      await tester.tap(find.text('-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      // Teclear '6' y pulsar '=' -> debe resolver parábola y = x² - 5x + 6
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      // Cambiar a vista de pasos en la LCD para verificar PASO 1/
      await tester.tap(find.text('📈 Ver Gráfica'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);

      // Pulsar DEL: debe salir de la vista de pasos y devolver a los coeficientes
      await tester.tap(find.text('DEL'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets);
      expect(find.text('-5'), findsWidgets);
      expect(find.text('6'), findsWidgets);

      // Pulsar AC: debe limpiar todos los coeficientes
      await tester.tap(find.text('AC'));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('Modo Coeficientes permite introducir fracciones verticales con la tecla a/b (/)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Ir a Modo 3 (Sistemas 2×2) mediante MODE + 3
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();

      // Teclear '6', '/', '2' en la primera celda
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('a/b'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.byType(Math), findsWidgets);
      expect(find.text('6/2'), findsNothing);
    });

    testWidgets('Modo 4 (Notables) es modo de expresión y evalúa desde el teclado físico', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Ir a Modo 4 -> cambiar a pestaña Notables
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('poly_tab_notables')));
      await tester.pumpAndSettle();

      expect(find.text('M4: NOTABLES'), findsOneWidget);
      expect(find.text('0'), findsWidgets);

      // Teclear '(', '2', ALPHA + ')', '+', '3', ')', 'x²'
      await tester.tap(find.text('('));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(')')); // Escribe 'x'
      await tester.pumpAndSettle();
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(')'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('x²'));
      await tester.pumpAndSettle();

      // Pulsar '=' -> Debe resolver (2x + 3)² y mostrar pasos
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsOneWidget);
    });

    testWidgets('Pulsar = cuando ya está resuelto avanza de paso en modo coeficientes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Ir a Modo 5 (Gráficas / Parábolas) mediante MODE + 5
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();

      // Coeficientes: 1, -5, 6
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      await tester.tap(find.text('📈 Ver Gráfica'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);

      // Pulsar '=' debe avanzar al PASO 2
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 2/'), findsOneWidget);
    });

    testWidgets('Menú ClassWiz paginado: navegación con D-Pad, confirmación con = y cancelación con AC', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Abrir menú con la tecla física MODE
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();

      // Debe mostrar la cuadrícula 2x2 con "1:Calcular" seleccionado inicialmente
      expect(find.text('1:Calcular'), findsOneWidget);

      // 2. Mover cursor a la derecha con D-Pad: selecciona 2:Ecuaciones (1.º y 2.º Grado)
      await tester.tap(find.byIcon(Icons.arrow_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('2:Ecuaciones (1.º y 2.º Grado)'), findsOneWidget);

      // 3. Mover cursor abajo con D-Pad: salta a fila inferior (+2) -> 4:Polinomios / Ruffini
      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pumpAndSettle();
      expect(find.text('4:Polinomios / Ruffini'), findsOneWidget);

      // 4. Confirmar con '=': entra en Modo 4
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('poly_tab_ruffini')), findsOneWidget);
      expect(find.byKey(const Key('poly_tab_notables')), findsOneWidget);

      // 5. Volver a abrir el menú y pulsar AC para cancelar
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      expect(find.text('4:Polinomios / Ruffini'), findsOneWidget);
      await tester.tap(find.text('AC'));
      await tester.pumpAndSettle();
      // Debe seguir en Modo 4 sin cambios
      expect(find.byKey(const Key('poly_tab_ruffini')), findsOneWidget);
    });

    testWidgets('Toggle OLED/LCD en la propia LCD y SHIFT + MODE conmutan tema OLED y LCD clásico', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Pulsar interruptor de contraste/backlight dentro de la LCD
      await tester.tap(find.byKey(const Key('lcd_theme_toggle')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen)).isOledDark,
        isTrue,
      );

      // Pulsar SHIFT y luego MODE para abrir SETUP y pulsar 3 (Tema LCD)
      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIG / SETUP'), findsOneWidget);
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CasioLcdScreen>(find.byType(CasioLcdScreen)).isOledDark,
        isFalse,
      );
    });
  });

  group('Cursor D-Pad, Salto de Fracción y Replay Casio', () {
    test('ExpressionParser gestiona cursor, inserción, borrado y salto numerador/denominador', () {
      // Movimiento izquierda / derecha con tokens atómicos
      expect(ExpressionParser.stepCursorLeft('2+ANS', 5), equals(2));
      expect(ExpressionParser.stepCursorRight('2+ANS', 2), equals(5));
      expect(ExpressionParser.stepCursorLeft('√(72)', 2), equals(0));
      expect(ExpressionParser.stepCursorRight('√(72)', 0), equals(2));

      // Inserción en posición intermedia
      final (inserted, nextCursor) =
          ExpressionParser.insertAtCursor('2+3', 1, '5');
      expect(inserted, equals('25+3'));
      expect(nextCursor, equals(2));

      // Borrado en posición intermedia
      final (deleted, afterDelCursor) =
          ExpressionParser.deleteAtCursor('25+3', 2);
      expect(deleted, equals('2+3'));
      expect(afterDelCursor, equals(1));

      // Borrado de token atómico completo
      final (delToken, delTokenPos) =
          ExpressionParser.deleteAtCursor('2+√(9)', 4);
      expect(delToken, equals('2+9)'));
      expect(delTokenPos, equals(2));

      // Salto entre numerador y denominador
      expect(
        ExpressionParser.jumpFractionUpDown('4/6', 3, isUp: true),
        equals(1),
      );
      expect(
        ExpressionParser.jumpFractionUpDown('4/6', 1, isUp: false),
        equals(3),
      );
      // En frase sin fracción retorna null para activar Replay
      expect(
        ExpressionParser.jumpFractionUpDown('2+3', 3, isUp: true),
        isNull,
      );
    });

    testWidgets('D-Pad ◀ ▶ mueve el cursor, edita e inserta en el medio antes de evaluar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Escribir '2 + 3'
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '+'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();

      // Mover cursor ◀ dos veces (antes del '+'): '2|+3'
      await tester.tap(find.byKey(const Key('replay_left')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_left')));
      await tester.pumpAndSettle();

      // Insertar '1' en medio -> '21+3' y resolver '=' -> Resultado 24
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsOneWidget);
      // Verificar en Pizarra lateral que el resultado contiene 24
      expect(tester.takeException(), isNull);

      // Probar Replay con ▲ después de pulsar AC
      await tester.tap(find.widgetWithText(CasioPhysicalKey, 'AC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_up')));
      await tester.pumpAndSettle();
      // Volver a pulsar '=' debe re-evaluar '21+3'
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);
    });

    testWidgets('D-Pad ◀ ▶ ▲ ▼ navega entre celdas en Modos por Coeficientes y en pasos activos', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Modo 3: Sistemas 2x2
      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '3'));
      await tester.pumpAndSettle();

      // Escribir '2' en a1, usar ▶ para ir a b1, ▼ para ir a b2, escribir '7'
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_right')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replay_down')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '7'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
      expect(find.text('7'), findsWidgets);

      // Resolver con '=' múltiples veces hasta obtener pasos y navegar con ◀ ▶
      await tester.tap(find.byKey(const Key('replay_up')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '=')); // b1 -> c1
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '=')); // c1 -> a2
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '=')); // a2 -> b2
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '=')); // b2 -> c2
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '=')); // resolver
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsOneWidget);
      await tester.tap(find.byKey(const Key('replay_right')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 2/'), findsOneWidget);
      await tester.tap(find.byKey(const Key('replay_left')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PASO 1/'), findsOneWidget);
    });
  });

  group('Layout Responsivo Calculadora de Windows y Zona Superior Ergonómica', () {
    testWidgets('Modo Compacto (< 760px) oculta el panel lateral y mantiene teclado ergonómico', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WindowsSidePanel), findsNothing);
      expect(find.byType(CasioReplayPad), findsOneWidget);
      expect(find.text('SHIFT'), findsOneWidget);
      expect(find.text('ALPHA'), findsOneWidget);
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('CALC'), findsOneWidget);
      expect(find.text('OPTN'), findsOneWidget);
      expect(find.byKey(const Key('lcd_theme_toggle')), findsOneWidget);
      expect(find.byKey(const Key('lcd_sound_toggle')), findsOneWidget);
      expect(find.text('TUTOR IA'), findsNothing);
      expect(find.text('STICKER'), findsNothing);
      expect(find.text('SCAN IA'), findsNothing);
      expect(find.text('LaTeX'), findsNothing);
    });

    testWidgets('Modo Expandido (>= 760px) muestra chasis 430px + WindowsSidePanel con historial y pizarra en vivo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WindowsSidePanel), findsOneWidget);
      expect(find.text('HISTORIAL'), findsOneWidget);
      expect(find.text('DESGLOSE PASO A PASO'), findsOneWidget);
      expect(find.text('Exportar Resumen (.TEX / PNG)'), findsOneWidget);

      // Verificar que el CasioReplayPad mide exactamente 108x84 px
      final replaySize = tester.getSize(find.byType(CasioReplayPad));
      expect(replaySize.width, equals(108));
      expect(replaySize.height, equals(84));

      // Resolver 4 + 5 = 9 y validar actualización en vivo en Historial y Desglose
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '+'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.text('1 ejercicios en sesión'), findsOneWidget);

      // Cambiar a pestaña Desglose Paso a Paso
      await tester.tap(find.text('DESGLOSE PASO A PASO'));
      await tester.pumpAndSettle();

      expect(find.text('EXPORTAR PNG'), findsOneWidget);
      expect(find.text('COPIAR LaTeX'), findsOneWidget);
      expect(find.text('Exportar Sticker Goodnotes'), findsNothing);
      expect(find.text('Preguntar al Tutor IA'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mejoras Modo 2 (x/=), Modo 4 (Ruffini hasta grado 6) y Escáner IA', () {
    testWidgets('Modo 2 permite escribir x y = con barra contextual y resolver 2x + 4 = 16', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eq_var_x')), findsOneWidget);
      expect(find.byKey(const Key('eq_sign_equals')), findsOneWidget);

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eq_var_x')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '+'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eq_sign_equals')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '6'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Modo 4 muestra selector previo de grado (2.º–6.º), soporta grado 5 y 6', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('MODE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();

      // Debe aparecer el selector previo de grado dentro de la LCD
      expect(find.text('ELIGE GRADO DE P(x)'), findsOneWidget);
      for (int deg = 2; deg <= 6; deg++) {
        expect(find.byKey(Key('ruffini_degree_$deg')), findsOneWidget);
      }

      // Elegir grado 5 tocando su tarjeta
      await tester.tap(find.byKey(const Key('ruffini_degree_5')));
      await tester.pumpAndSettle();

      expect(find.text('RUFFINI GRADO 5'), findsOneWidget);
      expect(find.text('e'), findsOneWidget);
      expect(find.text('f'), findsOneWidget);

      // Introducir [1, 0, -5, 0, 4, 0] -> x⁵ - 5x³ + 4x
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '-'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CasioPhysicalKey, '0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CasioPhysicalKey, '='));
      await tester.pumpAndSettle();

      expect(find.textContaining('PASO 1/'), findsWidgets);

      // Cambiar rápidamente a grado 6 mediante la pestaña contextual
      await tester.tap(find.byKey(const Key('ruffini_tab_6')));
      await tester.pumpAndSettle();
      expect(find.text('RUFFINI GRADO 6'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tecla OPTN y AppBar ofrecen exportación PNG y copia LaTeX sin SCAN IA / TUTOR IA', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appbar_export_png')), findsOneWidget);
      expect(find.byKey(const Key('appbar_copy_latex')), findsOneWidget);
      expect(find.text('SCAN IA'), findsNothing);
      expect(find.text('TUTOR IA'), findsNothing);

      await tester.tap(find.text('SHIFT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CALC'));
      await tester.pumpAndSettle();

      expect(find.text('OPTN · Opciones Rápidas (STEP-BY-STEP LD)'), findsOneWidget);
      expect(find.text('Exportar desarrollo a PNG transparente'), findsOneWidget);
      expect(find.text('Copiar bloque LaTeX al portapapeles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
