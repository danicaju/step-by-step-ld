import 'dart:io';

import 'package:casio_tutor_calc/domain/math_engine/functions/function_family_study_solver.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_key_points.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_label_layout.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_smart_viewport.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_viewport_calculator.dart';
import 'package:casio_tutor_calc/presentation/painters/graph_viewport_controller.dart';
import 'package:casio_tutor_calc/presentation/painters/universal_function_painter.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

FamilyStudy _study(String raw) => FunctionFamilyStudySolver.study(raw);

const Size _canvas = Size(300, 180);

Widget _host(GraphViewportController c, FamilyStudy s) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: _canvas.width,
          height: _canvas.height,
          child: UniversalGraphView(model: s.result.model, asymptotes: s.result.asymptotes, info: s.info, controller: c),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ThemeController.instance.resetForTests());

  group('1. GraphViewportController', () {
    GraphViewportController fresh() => GraphViewportController()..fit(const GraphWindow(-6, 6, -4, 4));

    test('arrastre: el contenido sigue al dedo', () {
      final c = fresh();
      c.panByPixels(30, 0, _canvas); // 30 px a la derecha = el mundo se mueve a la derecha
      expect(c.window.xMin, lessThan(-6));
      expect(c.window.width, closeTo(12, 1e-9));
      c.panByPixels(0, 18, _canvas);
      expect(c.window.yMin, greaterThan(-4));
    });

    test('zoom mantiene anclado el punto focal', () {
      final c = fresh();
      const focal = Offset(75, 45); // 25 % del ancho y del alto
      double mathX(GraphWindow w) => w.xMin + focal.dx / _canvas.width * w.width;
      final before = mathX(c.window);
      c.zoomAt(focal, 2, _canvas);
      expect(c.window.width, closeTo(6, 1e-9));
      expect(mathX(c.window), closeTo(before, 1e-9));
    });

    test('limites de seguridad 0.2 y 1000 unidades, sin NaN ni division por cero', () {
      final c = fresh();
      for (var i = 0; i < 80; i++) {
        c.zoomIn();
      }
      expect(c.window.width, greaterThanOrEqualTo(GraphViewportController.minSpan - 1e-9));
      expect(c.window.height, greaterThanOrEqualTo(GraphViewportController.minSpan - 1e-9));
      for (var i = 0; i < 200; i++) {
        c.zoomOut();
      }
      expect(c.window.width, lessThanOrEqualTo(GraphViewportController.maxSpan + 1e-6));
      expect(c.window.height, lessThanOrEqualTo(GraphViewportController.maxSpan + 1e-6));
      c.zoomAt(const Offset(0, 0), double.nan, _canvas);
      c.zoomAt(const Offset(0, 0), 0, _canvas);
      c.panByPixels(10, 10, Size.zero);
      expect([c.window.xMin, c.window.xMax, c.window.yMin, c.window.yMax].every((v) => v.isFinite), isTrue);
    });

    test('rueda: dy negativo acerca, positivo aleja', () {
      final c = fresh();
      c.zoomByWheel(-120, const Offset(150, 90), _canvas);
      expect(c.window.width, lessThan(12));
      c.zoomByWheel(240, const Offset(150, 90), _canvas);
      expect(c.window.width, greaterThan(12 * 0.99));
    });

    test('recentrar y doble toque restauran el encuadre inicial', () {
      final c = fresh();
      c.panByPixels(50, 20, _canvas);
      c.zoomIn();
      c.reset();
      expect(c.window, c.initial);
      c.panByPixels(50, 20, _canvas);
      final t0 = DateTime(2026, 1, 1, 10);
      expect(c.registerTap(t0, const Offset(100, 100)), isFalse);
      expect(c.registerTap(t0.add(const Duration(milliseconds: 150)), const Offset(104, 98)), isTrue);
      expect(c.window, c.initial);
      // Dos toques separados no cuentan.
      expect(c.registerTap(t0, const Offset(0, 0)), isFalse);
      expect(c.registerTap(t0.add(const Duration(seconds: 2)), const Offset(0, 0)), isFalse);
    });
  });

  group('2. computeSmartViewport', () {
    test('parabola 5x^2-4x+3 no estira Y y deja el vertice visible y centrado', () {
      final s = _study('5x^2-4x+3');
      final w = computeSmartViewport(s.result.model, s.result.asymptotes, info: s.info, aspect: 0.6);
      expect(w.yMax, lessThan(15), reason: 'antes llegaba a y = 80');
      expect(0.4 > w.xMin && 0.4 < w.xMax, isTrue);
      expect(2.2 > w.yMin && 2.2 < w.yMax, isTrue);
      expect(3 > w.yMin && 3 < w.yMax, isTrue);
      expect(((w.xMin + w.xMax) / 2 - 0.4).abs(), lessThan(1.0));
      expect(((w.yMin + w.yMax) / 2 - 2.6).abs(), lessThan(1.0));
      expect(w.height / w.width, closeTo(0.6, 0.35));
    });

    test('GraphViewportCalculator.window usa el encuadre inteligente', () {
      final s = _study('x^2-4x+3');
      final w = GraphViewportCalculator.window(s.result.model, s.result.asymptotes, info: s.info);
      expect(w.yMax - w.yMin, lessThan(20));
    });

    test('sin puntos notables -> encuadre limpio centrado en el origen', () {
      final s = _study('x');
      final w = computeSmartViewport(s.result.model, s.result.asymptotes, info: s.info, aspect: 0.5);
      expect((w.xMin + w.xMax) / 2, closeTo(0, 1e-9));
      expect(w.width, closeTo(12, 1e-9));
      expect(w.height, closeTo(6, 1e-9));
    });

    test('la ventana contiene los cortes y los extremos de una cubica', () {
      final s = _study('x^3-3x');
      final w = computeSmartViewport(s.result.model, s.result.asymptotes, info: s.info);
      for (final p in const [Offset(-1, 2), Offset(1, -2), Offset(0, 0)]) {
        expect(p.dx > w.xMin && p.dx < w.xMax && p.dy > w.yMin && p.dy < w.yMax, isTrue, reason: '$p');
      }
    });
  });

  group('3. Etiquetas', () {
    test('formato con punto decimal y coma-espacio entre coordenadas', () {
      expect(GraphKeyPoints.formatCoord(2.2), '2.2');
      expect(GraphKeyPoints.formatCoord(0.4), '0.4');
      expect(GraphKeyPoints.formatCoord(3), '3');
      expect(GraphKeyPoints.formatCoord(-0.5), '-0.5');
      expect(GraphKeyPoints.formatCoord(1.005), anyOf('1', '1.01', '1'));
      expect(GraphKeyPoints.formatCoord(-0.001), '0');
      final s = _study('5x^2-4x+3');
      final w = computeSmartViewport(s.result.model, s.result.asymptotes, info: s.info);
      final labels = GraphKeyPoints.of(s.result.model, w, info: s.info).map((k) => k.label).toList();
      expect(labels, contains('(0.4, 2.2)'));
      expect(labels, contains('(0, 3)'));
      expect(labels.any((l) => l.contains('2,20') || l.contains('0,40')), isFalse);
    });

    test('anti-colision: dos puntos muy juntos reciben cajas disjuntas dentro del lienzo', () {
      final layout = GraphLabelLayout(_canvas);
      const label = Size(60, 14);
      final a = layout.place(const Offset(150, 90), label);
      final b = layout.place(const Offset(153, 92), label);
      final c = layout.place(const Offset(151, 91), label);
      expect(a.overlaps(b), isFalse);
      expect(a.overlaps(c), isFalse);
      expect(b.overlaps(c), isFalse);
      for (final r in [a, b, c]) {
        expect(r.left >= 0 && r.top >= 0 && r.right <= _canvas.width && r.bottom <= _canvas.height, isTrue);
      }
    });

    test('evita ejes y numeros de ejes reservados', () {
      final axisX = Rect.fromLTWH(0, 88, _canvas.width, 4);
      final tick = Rect.fromLTWH(155, 94, 14, 10);
      final layout = GraphLabelLayout(_canvas, occupied: [axisX, tick]);
      final r = layout.place(const Offset(150, 90), const Size(50, 14));
      expect(r.overlaps(axisX), isFalse);
      expect(r.overlaps(tick), isFalse);
    });

    test('shouldRepaint solo reacciona a funcion, tema y viewport', () {
      final s = _study('x^2');
      UniversalFunctionPainter p({GraphWindow w = const GraphWindow(-6, 6, -4, 4), Color bg = const Color(0xFFC8D6CD)}) =>
          UniversalFunctionPainter(
              model: s.result.model, asymptotes: s.result.asymptotes, window: w, background: bg);
      expect(p().shouldRepaint(p()), isFalse);
      expect(p().shouldRepaint(p(w: const GraphWindow(-5, 6, -4, 4))), isTrue);
      expect(p().shouldRepaint(p(bg: const Color(0xFFDCE3DC))), isTrue);
    });
  });

  group('4. Visor interactivo', () {
    testWidgets('arrastre con un dedo, pellizco, rueda, botones y doble toque', (t) async {
      final s = _study('x^2-4x+3');
      final c = GraphViewportController();
      await t.pumpWidget(_host(c, s));
      final init = c.window;
      expect(c.initial, init);

      // Arrastre.
      await t.drag(find.byKey(const Key('universal_graph_gestures')), const Offset(-60, 0));
      await t.pump();
      expect(c.window.xMin, greaterThan(init.xMin));
      expect(c.window.width, closeTo(init.width, 1e-6));

      // Pellizco: dos dedos que se separan acercan.
      final center = t.getCenter(find.byKey(const Key('universal_graph_gestures')));
      final w0 = c.window.width;
      final g1 = await t.startGesture(center - const Offset(20, 0), pointer: 11);
      final g2 = await t.startGesture(center + const Offset(20, 0), pointer: 12);
      await g1.moveBy(const Offset(-40, 0));
      await g2.moveBy(const Offset(40, 0));
      await g1.up();
      await g2.up();
      await t.pump();
      expect(c.window.width, lessThan(w0));

      // Rueda del raton centrada en el puntero.
      final wheelBefore = c.window.width;
      final mouse = TestPointer(21, PointerDeviceKind.mouse);
      await t.sendEventToBinding(mouse.hover(center));
      await t.sendEventToBinding(mouse.scroll(const Offset(0, -150)));
      await t.pump();
      expect(c.window.width, lessThan(wheelBefore));

      // Botones flotantes.
      final zin = c.window.width;
      await t.tap(find.byKey(const Key('graph_zoom_out')));
      await t.pump();
      expect(c.window.width, greaterThan(zin));
      await t.tap(find.byKey(const Key('graph_zoom_in')));
      await t.pump();
      await t.tap(find.byKey(const Key('graph_zoom_reset')));
      await t.pump();
      expect(c.window, c.initial);

      // Doble toque tras mover.
      await t.drag(find.byKey(const Key('universal_graph_gestures')), const Offset(40, 20));
      await t.pump(const Duration(milliseconds: 400));
      expect(c.window, isNot(c.initial));
      await t.tapAt(center);
      await t.pump(const Duration(milliseconds: 80));
      await t.tapAt(center);
      await t.pump();
      expect(c.window, c.initial);
      expect(t.takeException(), isNull);
    });

    for (final theme in [HardwareThemes.defaultTheme, HardwareThemes.rosa]) {
      testWidgets('controles flotantes con los colores del tema ${theme.name}', (t) async {
        ThemeController.instance.select(theme, persist: false);
        final s = _study('x^2-4x+3');
        await t.pumpWidget(_host(GraphViewportController(), s));
        for (final k in ['graph_zoom_in', 'graph_zoom_out', 'graph_zoom_reset']) {
          final box = find.descendant(of: find.byKey(Key(k)), matching: find.byType(Container));
          final deco = t.widget<Container>(box.first).decoration! as BoxDecoration;
          expect(deco.color!.withValues(alpha: 1), theme.lcdBackground);
        }
        final clip = t.widget<Container>(find.descendant(of: find.byKey(const Key('universal_graph_clip')), matching: find.byType(Container)).first);
        expect(clip.color, theme.lcdBackground);
      });
    }
  });

  group('5. M5 Auto: deteccion sin elegir tipo', () {
    final cases = <String, FunctionFamily>{
      '(x-2)^2-3': FunctionFamily.quadratic,
      '(2x+1)/(x-3)': FunctionFamily.rational,
      'sqrt(2x-4)': FunctionFamily.radicalEven,
      'log_2(x-1)': FunctionFamily.logarithmic,
      '2^x': FunctionFamily.exponential,
      'sin(x)': FunctionFamily.sine,
    };
    cases.forEach((expr, fam) {
      test('$expr -> $fam', () {
        final s = FunctionFamilyStudySolver.study(expr, degrees: false);
        expect(s.family, fam);
        expect(s.result.resolution.steps, isNotEmpty);
        final w = GraphViewportCalculator.window(s.result.model, s.result.asymptotes, info: s.info);
        expect(w.width > 0 && w.height > 0, isTrue);
      });
    });

    test('la primera opcion del desplegable es Auto (f(x) libre)', () {
      expect(kM5KindLabels.first, 'Auto (f(x) libre)');
    });

    testWidgets('M5 arranca en Auto, sin conmutador antes de = y estudia sqrt(2x-4)', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:5');
      expect(find.byKey(const Key('hdr_graph_kind')), findsOneWidget);
      expect(find.textContaining('Auto'), findsWidgets);
      await seq(t, 'sqrt 2 x - 4 >');
      expect(find.byKey(const Key('mode5_view_toggle')), findsNothing);
      await key(t, '=');
      expect(find.byKey(const Key('universal_graph_clip')), findsOneWidget);
      expect(find.byKey(const Key('mode5_view_toggle')), findsOneWidget);
      expect(find.byKey(const Key('graph_zoom_in')), findsOneWidget);
      await seq(t, 'steps');
      expect(res(t).steps, isNotEmpty);
    });
  });

  group('6. El D-Pad no accede al historial', () {
    Future<void> hammer(WidgetTester t) async {
      for (var i = 0; i < 4; i++) {
        await pad(t, 'up');
        await pad(t, 'down');
        await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await t.pump();
    }

    testWidgets('tras operaciones y AC, ▲▼ (D-Pad y teclado) dejan la pantalla vacia', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, '1 + 1 = AC 2 + 2 = AC 3 + 3 = AC');
      final empty = live(t);
      await hammer(t);
      expect(live(t), empty);
      expect(find.byKey(const Key('edge_up')), findsNothing);
      expect(find.byKey(const Key('edge_down')), findsNothing);
    });

    testWidgets('tampoco recupera operaciones tras vaciar el historial', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, '4 + 5 = AC');
      await t.pumpAndSettle();
      await tapF(t, find.byKey(const Key('appbar_history')));
      await t.pumpAndSettle();
      final clear = find.byIcon(Icons.delete_outline_rounded);
      if (clear.evaluate().isNotEmpty) {
        await tapF(t, clear);
        await tapF(t, find.text('Borrar Todo'));
      }
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      await hammer(t);
      expect(live(t).contains('4'), isFalse);
      expect(live(t).contains('5'), isFalse);
    });

    test('ya no existe el codigo de Replay', () {
      final dir = Directory('lib/presentation/screens');
      final offenders = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('_replayIndex') || f.readAsStringSync().contains('_cycleHistoryReplay'))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
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
