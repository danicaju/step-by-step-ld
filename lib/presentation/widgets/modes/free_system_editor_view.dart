import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Editor LCD de un sistema 2x2 / 3x3 en entrada libre: cada ecuacion son dos casillas
/// (`miembro izquierdo` `=` `miembro derecho`) con cursor parpadeante y D-Pad ◀ ▶ ▲ ▼.
class FreeSystemEditorView extends StatelessWidget {
  final ModeFormState form;
  final int equations;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;

  const FreeSystemEditorView({
    super.key,
    required this.form,
    required this.equations,
    required this.theme,
    required this.onFocus,
  });

  static const Color _ink = Color(0xFF1A2530);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : _ink;
    return Container(
      key: const Key('sys_free_editor'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('{', style: TextStyle(color: fg, fontSize: 30.0 * equations, fontWeight: FontWeight.w200, height: 1)),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var e = 0; e < equations; e++) ...[
                  if (e > 0) const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _cell(2 * e, fg, pal),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '=',
                          key: Key('sys_free_eq_$e'),
                          style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _cell(2 * e + 1, fg, pal),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i, Color fg, LcdPalette pal) => FormCellBox(
        field: form.fields[i],
        active: form.focus == i + form.base,
        cellKey: Key('sys_free_cell_$i'),
        onTap: () => onFocus(i + form.base),
        fg: fg,
        pal: pal,
        minWidth: 104,
      );
}
