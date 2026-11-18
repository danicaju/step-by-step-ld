import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'form_cell_text.dart';
import 'mode_form.dart';

/// Celda editable de un [ModeFormState] (misma estetica Casio que `ModeFormWidget`).
class FormCellBox extends StatelessWidget {
  final ModeField field;
  final bool active;
  final Key cellKey;
  final VoidCallback onTap;
  final Color fg;
  final LcdPalette pal;
  final double minWidth;
  final String? caption;

  const FormCellBox({
    super.key,
    required this.field,
    required this.active,
    required this.cellKey,
    required this.onTap,
    required this.fg,
    required this.pal,
    this.minWidth = 96,
    this.caption,
  });

  static const Color ink = Color(0xFF1A2530);
  static const Color amber = Color(0xFFE5A93C);
  static const Color border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    // Las celdas de expresion se pintan en LaTeX: fondo claro (el cursor es oscuro).
    final latex = field.expr;
    final activeFill = latex ? Color.alphaBlend(amber.withValues(alpha: 0.22), pal.inset) : ink;
    final activeInk = latex ? fg : const Color(0xFFC8D6CD);
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (caption != null)
          Text(caption!, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 10)),
        Container(
          key: cellKey,
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active ? activeFill : pal.inset,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? amber : border, width: active ? 2.2 : 1),
          ),
          child: FormCellText(
            text: field.text,
            active: active,
            latex: latex,
            color: active ? activeInk : fg,
          ),
        ),
      ]),
    );
  }
}
