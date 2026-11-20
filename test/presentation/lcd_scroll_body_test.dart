import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/screens/calculator_screen.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casio_tutor_calc/presentation/widgets/common/lcd_scroll_body.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = StepByStepResolution(
  originalInputLatex: r'x^{2}-5x+6=0',
  steps: [
    MathStep(
        index: 1,
        shortTitle: 'Paso uno',
        latexExpression: r'x^{2}-5x+6=0',
        pedagogicalNote: 'Nota uno'),
    MathStep(
        index: 2,
        shortTitle: 'Paso dos',
        latexExpression: r'x=2,\ x=3',
        pedagogicalNote: 'Nota dos'),
  ],
  exactResultLatex: r'x=2,\ x=3',
  decimalApproxLatex: r'x=2,\ x=3',
);

Widget _lcd(Size size,
        {StepByStepResolution? res,
        int step = 0,
        bool header = false,
        double? minH}) =>
    MaterialApp(
      home: Scaffold(
          body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CasioLcdScreen(
            currentInputLatex: '7',
            currentResolution: res,
            activeStepIndex: step,
            isShiftActive: false,
            isAlphaActive: false,
            showDecimalApprox: false,
            modeLabel: 'M3',
            headerCanWrap: true,
            bodyMinHeight: minH,
            headerSelectorsBuilder: header
                ? (wrap) => Wrap(
                      children: [
                        for (var i = 0; i < 3; i++)
                          SizedBox(key: Key('h$i'), width: 90, height: 22)
                      ],
                    )
                : null,
          ),
        ),
      )),
    );

void main() {
  for (final size in const [
    Size(900, 103),
    Size(360, 103),
    Size(390, 220),
    Size(900, 500)
  ]) {
    for (final withSteps in [false, true]) {
      testWidgets(
          'LCD ${size.width.toInt()}x${size.height.toInt()} steps=$withSteps sin overflow',
          (t) async {
        await t
            .pumpWidget(_lcd(size, res: withSteps ? _res : null, header: true));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('lcd_scroll_body')), findsOneWidget);
      });
    }
  }

  testWidgets(
      'hay pista visual y arrastre con raton solo si hay desbordamiento',
      (t) async {
    await t.pumpWidget(
        _lcd(const Size(400, 100), res: _res, step: 1, header: true));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('lcd_scroll_hint')), findsOneWidget);
    final scrollable = find
        .descendant(
            of: find.byKey(const Key('lcd_scroll_body')),
            matching: find.byType(Scrollable))
        .first;
    final before = t.state<ScrollableState>(scrollable).position.pixels;
    await t.drag(find.byKey(const Key('lcd_scroll_body')), const Offset(0, -60),
        kind: PointerDeviceKind.mouse);
    await t.pumpAndSettle();
    expect(t.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(before));
    expect(t.takeException(), isNull);
  });

  testWidgets('sin desbordamiento no hay pista visual', (t) async {
    await t.pumpWidget(_lcd(const Size(400, 600), res: _res));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('lcd_scroll_hint')), findsNothing);
  });

  testWidgets('al cambiar de paso el scroll vuelve arriba', (t) async {
    await t.pumpWidget(
        _lcd(const Size(400, 100), res: _res, step: 0, header: true));
    await t.pumpAndSettle();
    final scrollable = find
        .descendant(
            of: find.byKey(const Key('lcd_scroll_body')),
            matching: find.byType(Scrollable))
        .first;
    await t.drag(
        find.byKey(const Key('lcd_scroll_body')), const Offset(0, -60));
    await t.pumpAndSettle();
    expect(
        t.state<ScrollableState>(scrollable).position.pixels, greaterThan(0));
    await t.pumpWidget(
        _lcd(const Size(400, 100), res: _res, step: 1, header: true));
    await t.pumpAndSettle();
    expect(t.state<ScrollableState>(scrollable).position.pixels, 0);
  });

  testWidgets('lockScroll bloquea el scroll del cuerpo', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 100,
                child: LcdScrollBody(
                  ink: Colors.black,
                  background: Colors.white,
                  minContentHeight: 300,
                  lockScroll: true,
                  builder: (c, h) => Container(height: h, color: Colors.green),
                ),
              ))),
    ));
    final sc = find
        .descendant(
            of: find.byKey(const Key('lcd_scroll_body')),
            matching: find.byType(Scrollable))
        .first;
    await t.drag(
        find.byKey(const Key('lcd_scroll_body')), const Offset(0, -80));
    await t.pumpAndSettle();
    expect(t.state<ScrollableState>(sc).position.pixels, 0);
  });

  testWidgets('LcdEnsureVisible desplaza la celda activa a la vista',
      (t) async {
    Widget app(int active) => MaterialApp(
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 100,
                    child: LcdScrollBody(
                      ink: Colors.black,
                      background: Colors.white,
                      minContentHeight: 400,
                      builder: (c, h) => Column(
                        children: [
                          for (var i = 0; i < 8; i++)
                            LcdEnsureVisible(
                                active: i == active,
                                child: SizedBox(key: Key('c$i'), height: 50)),
                        ],
                      ),
                    ),
                  ))),
        );
    await t.pumpWidget(app(0));
    await t.pumpAndSettle();
    await t.pumpWidget(app(7));
    await t.pumpAndSettle();
    final sc = find
        .descendant(
            of: find.byKey(const Key('lcd_scroll_body')),
            matching: find.byType(Scrollable))
        .first;
    expect(t.state<ScrollableState>(sc).position.pixels, greaterThan(100));
    expect(t.getRect(find.byKey(const Key('c7'))).bottom,
        lessThanOrEqualTo(100.5));
  });

  testWidgets(
      'M3 movil 390x844: cabecera en 2 filas sin overflow y desplegables tocables',
      (t) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CalculatorScreen())));
    await t.pumpAndSettle();
    await t.tap(find.text('MODE'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('menu_mode_3')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('lcd_scroll_body')), findsWidgets);
    final wrap = find.byKey(const Key('lcd_header_wrap'));
    expect(wrap, findsOneWidget);
    {
      await t.tap(find
          .descendant(
              of: wrap,
              matching: find.byWidgetPredicate((w) =>
                  w.runtimeType.toString().startsWith('LcdDropdownSelector')))
          .first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });
}
