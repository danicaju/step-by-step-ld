import 'package:flutter/material.dart';

import '../../../core/editor/cell_expression_input.dart';
import '../../../domain/math_engine/parser/live_latex_formatter.dart';
import '../casio_cell_value_text.dart';
import '../lcd/lcd_input_box.dart';
import '../lcd/lcd_palette.dart';
import 'mode_form.dart';

/// Celda editable de un [ModeFormState]: una [LcdInputBox] con su rotulo encima.
///
/// Las celdas de expresion se pintan como LaTeX en vivo (`x^{2}`, fracciones verticales,
/// raices...) con el cursor parpadeante en su posicion; las numericas muestran el texto
/// (o la fraccion `a/b` vertical) con el cursor en la parte activa.
class FormCellBox extends StatelessWidget {
  final ModeField field;
  final bool active;
  final Key cellKey;
  final VoidCallback onTap;
  final Color fg;
  final LcdPalette pal;
  final double minWidth;
  final String? caption;

  /// Campo numerico con fraccion activa: `true` = cursor en el numerador.
  final bool fracNumerator;

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
    this.fracNumerator = false,
  });

  static const Color ink = LcdInputBox.ink;
  static const Color amber = LcdInputBox.amber;
  static const Color border = Color(0xFF7A8A7E);

  /// LaTeX de [field] con el cursor (`#1A2530`) si esta [active]; `null` = usar texto plano.
  static String? latexOf(ModeField field, {required bool active, required bool fracNumerator}) {
    final text = field.text;
    if (field.expr) {
      if (text.isEmpty) return null;
      return LiveLatexFormatter.rawToLiveLatex(text, cursorPos: active ? field.pos : null);
    }
    if (field.scalar && CellExpressionInput.isExpression(text)) {
      return CasioCellValueText.fractionTex(text, activePart: active ? 1 : null, coloredCursor: true);
    }
    if (text.contains('/')) {
      return CasioCellValueText.fractionTex(text,
          activePart: active ? (fracNumerator ? 0 : 1) : null, coloredCursor: true);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(caption!, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 10)),
        ),
      LcdInputBox(
        key: cellKey,
        active: active,
        palette: pal,
        latex: latexOf(field, active: active, fracNumerator: fracNumerator),
        text: field.text,
        fontSize: 14,
        minWidth: minWidth,
        minHeight: 30,
        expandable: field.expr,
        onTap: onTap,
      ),
    ]);
  }
}
