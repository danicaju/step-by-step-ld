import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Entrada de la division en caja espanola: dividendo P(x) a la izquierda y divisor Q(x)
/// dentro de la caja (raya vertical gruesa + raya horizontal), con C(x) debajo.
class BoxDivisionInputWidget extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;
  final String keyPrefix;

  const BoxDivisionInputWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    this.keyPrefix = 'xform',
  });

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : FormCellBox.ink;
    return Container(
      key: Key('${keyPrefix}_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 14),
              child: FormCellBox(
                field: form.fields[0],
                active: form.focus == 0,
                cellKey: Key('${keyPrefix}_cell_0'),
                onTap: () => onFocus(0),
                fg: fg,
                pal: pal,
                minWidth: 120,
                caption: 'P(x) Dividendo',
              ),
            ),
            Container(
              key: const Key('box_input_vline'),
              width: 2,
              height: 78,
              color: FormCellBox.ink,
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(
                key: const Key('box_input_hline'),
                padding: const EdgeInsets.fromLTRB(10, 0, 0, 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: FormCellBox.ink, width: 2)),
                ),
                child: FormCellBox(
                  field: form.fields[1],
                  active: form.focus == 1,
                  cellKey: Key('${keyPrefix}_cell_1'),
                  onTap: () => onFocus(1),
                  fg: fg,
                  pal: pal,
                  minWidth: 110,
                  caption: 'Q(x) Divisor',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 4),
                child: Text(
                  'C(x) (Cociente)',
                  key: const Key('box_input_quotient_label'),
                  style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 11),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
