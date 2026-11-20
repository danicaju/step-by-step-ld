import 'dart:io';

import 'package:casio_tutor_calc/presentation/painters/system_lines_data.dart';
import 'package:casio_tutor_calc/presentation/theme/calculator_themes.dart';
import 'package:casio_tutor_calc/presentation/theme/theme_controller.dart';
import 'package:casio_tutor_calc/presentation/widgets/feasible_region_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/exercise_dsl.dart';

const _sge = 'pick:hdr_ineqsys_sign:ineq_sign_greaterOrEqual';
const _sle = 'pick:hdr_ineqsys_sign:ineq_sign_lessOrEqual';

void main() {
  tearDown(() => ThemeController.instance.resetForTests());

  group('Datos de las rectas del sistema 2x2', () {
    test('solucion unica: corte y ecuaciones con punto decimal', () {
      const s = SystemLines2x2(2, -1, 5, 3, 2, 4); // x = 2, y = -1
      expect(s.kind, SystemLinesKind.unique);
      expect(s.intersection!.dx, closeTo(2, 1e-9));
      expect(s.intersection!.dy, closeTo(-1, 1e-9));
      expect(s.eq1, '2x - y = 5');
      expect(s.eq2, '3x + 2y = 4');
      expect(SystemLines2x2.equationText(0.5, 0, 1.25), '0.5x = 1.25');
      expect(SystemLines2x2.equationText(-1, 1, 0), '-x + y = 0');
    });

    test('paralelas y coincidentes no tienen corte', () {
      expect(const SystemLines2x2(2, -4, 6, 1, -2, 5).kind, SystemLinesKind.parallel);
      expect(const SystemLines2x2(2, -4, 6, 1, -2, 3).kind, SystemLinesKind.coincident);
      expect(const SystemLines2x2(2, -4, 6, 1, -2, 5).intersection, isNull);
    });

    test('el encuadre inicial incluye el corte y los cortes con los ejes', () {
      const s = SystemLines2x2(2, -1, 5, 3, 2, 4);
      final w = computeSystemViewport(s, aspect: 0.6);
      for (final p in s.notablePoints()) {
        expect(p.dx > w.xMin && p.dx < w.xMax && p.dy > w.yMin && p.dy < w.yMax, isTrue, reason: '$p');
      }
      expect(w.height / w.width, inInclusiveRange(0.3, 1.3));
    });
  });

  group('M3: grafica del sistema 2x2', () {
    bothSizes('el conmutador muestra las dos rectas y vuelve a los pasos', (t) async {
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef 2 = - 1 = 5 = 3 = 2 = 4 =');
      expect(find.byKey(const Key('sys2_graph_toggle')), findsOneWidget);
      expect(find.byKey(const Key('system_graph_clip')), findsNothing, reason: 'por defecto se ven los pasos');
      await tapF(t, find.byKey(const Key('sys2_graph_toggle')));
      expect(find.byKey(const Key('system_graph_clip')), findsOneWidget);
      expect(find.byKey(const Key('graph_zoom_in')), findsOneWidget);
      await tapF(t, find.byKey(const Key('sys2_graph_toggle')));
      expect(find.byKey(const Key('system_graph_clip')), findsNothing);
      expect(res(t).steps, isNotEmpty);
    });

    testWidgets('sin conmutador antes de resolver ni en sistemas 3x3', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef');
      expect(find.byKey(const Key('sys2_graph_toggle')), findsNothing);
      await seq(t, 'pick:hdr_sys_size:sys_dim_3 1 = 1 = 1 = 6 = 2 = - 1 = 1 = 3 = 1 = 2 = - 1 = 2 =');
      expect(find.byKey(const Key('sys2_graph_toggle')), findsNothing);
    });

    testWidgets('gestos: arrastre, rueda, botones y doble toque', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef 2 = - 1 = 5 = 3 = 2 = 4 =');
      await tapF(t, find.byKey(const Key('sys2_graph_toggle')));
      final gestures = find.byKey(const Key('system_graph_gestures'));
      final center = t.getCenter(gestures);
      final before = t.widget<CustomPaint>(find.byKey(const Key('system_graph_paint'))).painter! as dynamic;
      final w0 = before.window;

      await t.drag(gestures, const Offset(-50, 0));
      await t.pump();
      final afterDrag = (t.widget<CustomPaint>(find.byKey(const Key('system_graph_paint'))).painter! as dynamic).window;
      expect(afterDrag.xMin, greaterThan(w0.xMin));

      final mouse = TestPointer(31, PointerDeviceKind.mouse);
      await t.sendEventToBinding(mouse.hover(center));
      await t.sendEventToBinding(mouse.scroll(const Offset(0, -150)));
      await t.pump();
      final afterWheel = (t.widget<CustomPaint>(find.byKey(const Key('system_graph_paint'))).painter! as dynamic).window;
      expect(afterWheel.width, lessThan(afterDrag.width));

      await t.tap(find.byKey(const Key('graph_zoom_reset')));
      await t.pump();
      final afterReset = (t.widget<CustomPaint>(find.byKey(const Key('system_graph_paint'))).painter! as dynamic).window;
      expect(afterReset, w0);
      expect(t.takeException(), isNull);
    });

    for (final theme in [HardwareThemes.defaultTheme, HardwareThemes.menta]) {
      testWidgets('colores del tema ${theme.name}', (t) async {
        ThemeController.instance.select(theme, persist: false);
        await boot(t, size: kDesktop);
        await seq(t, 'mode:3 pick:hdr_sys_input:sys_input_coef 2 = 3 = 6 = 1 = - 2 = 5 =');
        await tapF(t, find.byKey(const Key('sys2_graph_toggle')));
        final c = t.widget<Container>(find.descendant(of: find.byKey(const Key('system_graph_clip')), matching: find.byType(Container)).first);
        expect(c.color, theme.lcdBackground);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('M7: region factible 2D interactiva', () {
    testWidgets('zoom, arrastre, rueda y recentrado sobre la region', (t) async {
      await boot(t, size: kDesktop);
      await seq(t, 'mode:7 pick:hdr_ineqsys_unknowns:ineqsys_unk_2 pick:hdr_ineqsys_rows:ineqsys_rows_3 x $_sge 0 v y $_sge 0 v x + y $_sle 4 =');
      expect(find.byType(FeasibleRegionCanvas), findsOneWidget);
      expect(find.byKey(const Key('region_clip')), findsOneWidget);
      final canvas = t.widget<FeasibleRegionCanvas>(find.byType(FeasibleRegionCanvas));
      final ctrl = canvas.controller!;
      final init = ctrl.window;
      // El encuadre abarca los vertices (0,0), (4,0), (0,4).
      for (final p in const [Offset(0, 0), Offset(4, 0), Offset(0, 4)]) {
        expect(p.dx >= init.xMin && p.dx <= init.xMax && p.dy >= init.yMin && p.dy <= init.yMax, isTrue, reason: '$p');
      }
      await t.drag(find.byKey(const Key('region_gestures')), const Offset(-40, 10));
      await t.pump();
      expect(ctrl.window, isNot(init));
      await t.tap(find.byKey(const Key('graph_zoom_in')));
      await t.pump();
      expect(ctrl.window.width, lessThan(init.width));
      final center = t.getCenter(find.byKey(const Key('region_gestures')));
      final mouse = TestPointer(41, PointerDeviceKind.mouse);
      await t.sendEventToBinding(mouse.hover(center));
      await t.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
      await t.pump();
      await t.tap(find.byKey(const Key('graph_zoom_reset')));
      await t.pump();
      expect(ctrl.window, ctrl.initial);
      expect(t.takeException(), isNull);
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
