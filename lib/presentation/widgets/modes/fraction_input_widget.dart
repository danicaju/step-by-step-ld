import 'package:flutter/material.dart';

import '../lcd/lcd_dropdown_selector.dart';
import '../lcd/lcd_input_box.dart';
import '../lcd/lcd_palette.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Entrada de fracciones algebraicas con fracciones verticales reales.
///
/// Simplificar: una fraccion. Suma/Resta/Producto/Cociente: dos fracciones separadas por
/// el operador. Foco: 0 = operador/selector, luego P1, Q1 (y P2, Q2) del [ModeFormState].
/// El operador es un selector compacto estilo LCD (`[ Simplificar ▾ ]`, `[ + ▾ ]`...) de 36 px,
/// alineado con la barra de fraccion; las casillas son [LcdInputBox] amplias y auto-expandibles.
class FractionInputWidget extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;

  /// Pulsacion directa sobre el desplegable: elige la operacion.
  final ValueChanged<int>? onSelector;
  final String keyPrefix;

  const FractionInputWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    this.onSelector,
    this.keyPrefix = 'xform',
  });

  static const List<String> operatorSymbols = ['', '+', '−', '×', '÷'];
  static const double selectorHeight = 36;
  static const double boxMinWidth = 190;

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final night = theme == LcdTheme.night;
    final fg = night ? const Color(0xFFE8F3EE) : FormCellBox.ink;
    final two = form.selector != 0;
    final selActive = form.focus == 0;
    final labels = ['Simplificar', ...operatorSymbols.skip(1)];

    // Operador: el foco del D-Pad se marca con un aro ambar (sin bloque oscuro).
    final selector = Container(
      key: Key('${keyPrefix}_selector'),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selActive ? LcdInputBox.amber : Colors.transparent, width: 2),
      ),
      child: LcdDropdownSelector<int>(
        widgetKey: Key('${keyPrefix}_selector_dropdown'),
        value: form.selector,
        items: [
          for (var i = 0; i < labels.length; i++)
            LcdDropdownItem(value: i, label: labels[i], key: Key('${keyPrefix}_op_$i')),
        ],
        isOledDark: night,
        height: selectorHeight,
        fontSize: 14,
        columns: 1,
        onChanged: (v) => onSelector?.call(v),
      ),
    );

    Widget box(int i, String caption) => FormCellBox(
          field: form.fields[i],
          active: form.focus == i + form.base,
          cellKey: Key('${keyPrefix}_cell_$i'),
          onTap: () => onFocus(i + form.base),
          fg: fg,
          pal: pal,
          minWidth: boxMinWidth,
          caption: caption,
        );
    Widget fraction(int num, int den, String n, String d) => IntrinsicWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            box(num, n),
            Container(
                key: Key('${keyPrefix}_bar_$num'),
                height: 2,
                color: night ? fg : LcdInputBox.ink,
                margin: const EdgeInsets.symmetric(vertical: 4)),
            box(den, d),
          ]),
        );
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
