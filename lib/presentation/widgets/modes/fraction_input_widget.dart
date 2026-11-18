import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Entrada de fracciones algebraicas con fracciones verticales reales.
///
/// Simplificar: una fraccion. Suma/Resta/Producto/Cociente: dos fracciones separadas por
/// el operador. Foco: 0 = operador/selector, luego P1, Q1 (y P2, Q2) del [ModeFormState].
class FractionInputWidget extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;
  final String keyPrefix;

  const FractionInputWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    this.keyPrefix = 'xform',
  });

  static const List<String> operatorSymbols = ['', '+', '−', '·', '÷'];

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : FormCellBox.ink;
    final two = form.selector != 0;
    final selActive = form.focus == 0;
    final selector = GestureDetector(
      onTap: () => onFocus(0),
      child: Container(
        key: Key('${keyPrefix}_selector'),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selActive ? FormCellBox.ink : pal.inset,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selActive ? FormCellBox.amber : FormCellBox.border,
            width: selActive ? 2.2 : 1,
          ),
        ),
        child: Text(
          two ? '[ ${operatorSymbols[form.selector]} ]' : form.selectorLabels[0],
          style: TextStyle(
            color: selActive ? const Color(0xFFC8D6CD) : fg,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    Widget fraction(int num, int den, String n, String d) => Column(mainAxisSize: MainAxisSize.min, children: [
          FormCellBox(
            field: form.fields[num],
            active: form.focus == num + form.base,
            cellKey: Key('${keyPrefix}_cell_$num'),
            onTap: () => onFocus(num + form.base),
            fg: fg,
            pal: pal,
            minWidth: 92,
            caption: n,
          ),
          Container(key: Key('${keyPrefix}_bar_$num'), height: 2, width: 104, color: FormCellBox.ink,
              margin: const EdgeInsets.symmetric(vertical: 3)),
          FormCellBox(
            field: form.fields[den],
            active: form.focus == den + form.base,
            cellKey: Key('${keyPrefix}_cell_$den'),
            onTap: () => onFocus(den + form.base),
            fg: fg,
            pal: pal,
            minWidth: 92,
            caption: d,
          ),
        ]);
    return Container(
      key: Key('${keyPrefix}_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          if (!two) ...[
            selector,
            fraction(0, 1, 'P(x) Numerador', 'Q(x) Denominador'),
          ] else ...[
            fraction(0, 1, 'P1(x)', 'Q1(x)'),
            selector,
            fraction(2, 3, 'P2(x)', 'Q2(x)'),
          ],
        ]),
      ),
    );
  }
}
