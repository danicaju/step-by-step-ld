import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../lcd/lcd_dropdown_selector.dart';
import '../lcd/lcd_input_box.dart';
import '../lcd/lcd_palette.dart';
import '../modes/form_cell_box.dart';
import '../modes/mode_form.dart';
import '../safe_math.dart';

/// Entrada de la recta con notacion matematica real y huecos [LcdInputBox] integrados.
///
/// Foco del [ModeFormState]: 0 = desplegable `Datos`, luego los campos de la forma elegida.
/// Orden de campos (para que ▲ ▼ salten de numerador a denominador / de A a B):
/// 2 puntos `x1 y1 x2 y2`, punto y vector `x0 y0 v1 v2`, punto y pendiente `x0 y0 m`,
/// explicita `m n`, general `A B C`, continua `x0 y0 v1 v2`.
class LineEquationsVisualEditor extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;
  final ValueChanged<int> onSelector;
  final GlobalKey? boundsKey;

  const LineEquationsVisualEditor({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    required this.onSelector,
    this.boundsKey,
  });

  static const List<String> forms = [
    '2 puntos A y B',
    'Punto P y vector v',
    'Punto P y pendiente m',
    'Ecuación explícita (y = mx + n)',
    'Ecuación general (Ax + By + C = 0)',
    'Ecuación continua',
  ];

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final night = theme == LcdTheme.night;
    final fg = night ? pal.formula : LcdInputBox.ink;
    final selActive = form.focus == 0;

    Widget txt(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(s, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700)),
        );
    Widget tex(String s) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SafeMath.tex(s,
              mathStyle: MathStyle.text,
              textStyle: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700)),
        );
    Widget box(int i, {double w = 58}) => FormCellBox(
          field: form.fields[i],
          active: form.focus == i + 1,
          cellKey: Key('xform_cell_$i'),
          onTap: () => onFocus(i + 1),
          fg: fg,
          pal: pal,
          minWidth: w,
          fracNumerator: form.fracNum,
        );
    Widget row(List<Widget> c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: c),
        );
    Widget frac(String label, int num, int den) => Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [txt(label), box(num)]),
          Container(height: 2, width: 128, margin: const EdgeInsets.symmetric(vertical: 3), color: fg),
          box(den, w: 74),
        ]);

    final template = switch (form.selector) {
      0 => [
          row([txt('A('), box(0), txt(','), box(1), txt(')')]),
          row([txt('B('), box(2), txt(','), box(3), txt(')')]),
        ],
      1 => [
          row([txt('P('), box(0), txt(','), box(1), txt(')')]),
          row([tex(r'\vec{v} = ('), box(2), txt(','), box(3), txt(')')]),
        ],
      2 => [
          row([txt('P('), box(0), txt(','), box(1), txt(')')]),
          row([txt('m ='), box(2)]),
        ],
      3 => [
          row([txt('y ='), box(0), txt('x +'), box(1)]),
        ],
      4 => [
          row([box(0), txt('x +'), box(1), txt('y +'), box(2), txt('= 0')]),
        ],
      _ => [
          row([frac('x −', 0, 2), txt('='), frac('y −', 1, 3)]),
        ],
    };

    // El foco del D-Pad en el desplegable se marca con un aro ambar (como las fracciones de M4).
    final selector = Container(
      key: const Key('xform_selector'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selActive ? LcdInputBox.amber : Colors.transparent, width: 2),
      ),
      child: LcdDropdownSelector<int>(
        widgetKey: const Key('xform_selector_dropdown'),
        prefix: 'Datos',
        value: form.selector,
        items: [
          for (var i = 0; i < forms.length; i++)
            LcdDropdownItem(value: i, label: forms[i], key: Key('line_form_$i')),
        ],
        isOledDark: night,
        height: 28,
        fontSize: 12,
        columns: 1,
        boundsKey: boundsKey,
        onChanged: onSelector,
      ),
    );

    return Container(
      key: const Key('xform_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.topLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [selector, const SizedBox(height: 6), ...template],
        ),
      ),
    );
  }
}
