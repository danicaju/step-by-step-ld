import 'package:flutter/material.dart';

import '../lcd/lcd_dropdown_selector.dart';
import '../lcd/lcd_input_box.dart';
import '../lcd/lcd_palette.dart';
import '../modes/form_cell_box.dart';
import '../modes/mode_form.dart';
import 'triangle_diagram_painter.dart';
import 'triangle_slot_layout.dart';

/// Editor de triangulos: un triangulo real dibujado con las casillas junto a cada lado y angulo.
///
/// Foco del [ModeFormState]: 0 = desplegable de tipo; luego los campos `a, b, c, A°, B°[, C°]`
/// (en rectangulo no hay `C°`: el angulo recto se fija en 90°). Los huecos en blanco son las
/// incognitas. D-Pad: ◀ ▶ siguiente/anterior, ▲ ▼ saltan de lado a angulo (±3).
class TriangleVisualEditor extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;
  final ValueChanged<int> onSelector;
  final GlobalKey? boundsKey;

  const TriangleVisualEditor({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    required this.onSelector,
    this.boundsKey,
  });

  static const List<String> kinds = [
    'Rectángulo (Pitágoras / Trig.)',
    'Cualquier triángulo (Seno / Coseno)',
  ];

  bool get right => form.selector == 0;

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final night = theme == LcdTheme.night;
    final fg = night ? pal.formula : LcdInputBox.ink;
    final layout = TriangleSlotLayout.of(right: right);

    Widget slot(int field, String label, Offset at) {
      final f = form.fields[field];
      return Positioned(
        left: at.dx,
        top: at.dy,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 20,
            child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          FormCellBox(
            field: f,
            active: form.focus == field + 1,
            cellKey: Key('xform_cell_$field'),
            onTap: () => onFocus(field + 1),
            fg: fg,
            pal: pal,
            minWidth: 56,
            fracNumerator: form.fracNum,
          ),
        ]),
      );
    }

    final selActive = form.focus == 0;
    final selector = Container(
      key: const Key('xform_selector'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selActive ? LcdInputBox.amber : Colors.transparent, width: 2),
      ),
      child: LcdDropdownSelector<int>(
        widgetKey: const Key('xform_selector_dropdown'),
        prefix: 'Tipo',
        value: form.selector,
        items: [
          for (var i = 0; i < kinds.length; i++) LcdDropdownItem(value: i, label: kinds[i], key: Key('tri_form_$i')),
        ],
        isOledDark: night,
        height: 28,
        fontSize: 12,
        columns: 1,
        boundsKey: boundsKey,
        onChanged: onSelector,
      ),
    );

    final diagram = SizedBox(
      key: const Key('triangle_editor_canvas'),
      width: TriangleSlotLayout.canvas.width,
      height: TriangleSlotLayout.canvas.height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: TriangleDiagramPainter(layout: layout, right: right, palette: pal)),
          ),
        ),
        for (var i = 0; i < 3; i++) slot(i, kTriLabels[i], layout.sides[i]),
        for (var i = 0; i < 3; i++)
          if (layout.angles[i] != null) slot(3 + i, kTriLabels[3 + i], layout.angles[i]!),
      ]),
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
          children: [selector, const SizedBox(height: 4), diagram],
        ),
      ),
    );
  }

  static const List<String> kTriLabels = ['a', 'b', 'c', 'A°', 'B°', 'C°'];
}
