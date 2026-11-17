import 'package:flutter/material.dart';

import '../../../domain/math_engine/calculus/function_table.dart';
import '../lcd/lcd_palette.dart';
import 'expr_key_input.dart';

/// Estado del modo TABLE: `f(x)`, `g(x)` opcional, Inicio, Fin y Paso.
class FunctionTableFormState {
  static const List<String> labels = ['f(x)', 'g(x)', 'Inicio', 'Fin', 'Paso'];

  final List<String> cells = ['', '', '', '', ''];

  /// 0 f, 1 g, 2 Inicio, 3 Fin, 4 Paso.
  int focus = 0;
  bool showRows = false;
  int scroll = 0;
  List<TableRowData> rows = const [];

  static const int visibleRows = 5;

  bool get atTop => showRows ? scroll == 0 : focus == 0;

  /// D-Pad dentro del formulario o de la tabla de resultados.
  void dpad(String dir) {
    if (showRows) {
      final max = (rows.length - visibleRows).clamp(0, rows.length);
      if (dir == 'down') scroll = (scroll + 1).clamp(0, max);
      if (dir == 'up') scroll = (scroll - 1).clamp(0, max);
      return;
    }
    switch (dir) {
      case 'left':
        if (focus > 0) focus--;
      case 'right':
        if (focus < 4) focus++;
      case 'up':
        if (focus >= 1) focus = focus >= 3 ? 1 : focus - 1;
      case 'down':
        if (focus == 0) {
          focus = 1;
        } else if (focus == 1) {
          focus = 2;
        }
    }
  }

  /// Aplica una tecla al campo activo. `true` si la consumio.
  bool key(String k, {bool alpha = false}) {
    final cur = cells[focus];
    final next = focus <= 1 ? ExprKeyInput.apply(cur, k, alpha: alpha) : ExprKeyInput.applyNumber(cur, k);
    if (next == null) return false;
    cells[focus] = next;
    return true;
  }

  void clear() {
    for (var i = 0; i < cells.length; i++) {
      cells[i] = '';
    }
    focus = 0;
    showRows = false;
    scroll = 0;
    rows = const [];
  }
}

/// Vista LCD de TABLE (solo pinta; las teclas las gestiona la pantalla).
class FunctionTableWidget extends StatelessWidget {
  final FunctionTableFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;

  const FunctionTableWidget({super.key, required this.form, required this.theme, required this.onFocus});

  static const Color _ink = Color(0xFF1A2530);
  static const Color _amber = Color(0xFFE5A93C);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : _ink;
    return Container(
      key: const Key('function_table_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.transparent,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: form.showRows ? _rows(fg, pal) : _formBody(fg, pal),
      ),
    );
  }

  Widget _formBody(Color fg, LcdPalette pal) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(0, fg, pal, wide: true),
          const SizedBox(height: 4),
          _field(1, fg, pal, wide: true),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 2; i < 5; i++) ...[_field(i, fg, pal), const SizedBox(width: 6)],
          ]),
        ],
      );

  Widget _field(int i, Color fg, LcdPalette pal, {bool wide = false}) {
    final active = form.focus == i;
    final text = form.cells[i];
    final label = i == 0 ? 'f(x) =' : (i == 1 ? 'g(x) =' : FunctionTableFormState.labels[i]);
    final box = GestureDetector(
      onTap: () => onFocus(i),
      child: Container(
        key: Key('table_cell_$i'),
        constraints: BoxConstraints(minWidth: wide ? 190 : 58, minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: active ? _ink : pal.inset,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? _amber : _border, width: active ? 2.2 : 1),
        ),
        child: Text(
          text.isEmpty && !active ? (i == 1 ? 'opcional' : '') : text + (active ? '_' : ''),
          style: TextStyle(
            color: active ? const Color(0xFFC8D6CD) : (text.isEmpty ? fg.withValues(alpha: 0.5) : fg),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
    return wide
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 48, child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700))),
            box,
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 10)),
            box,
          ]);
  }

  Widget _rows(Color fg, LcdPalette pal) {
    final hasG = form.cells[1].trim().isNotEmpty;
    final end = (form.scroll + FunctionTableFormState.visibleRows).clamp(0, form.rows.length);
    TextStyle st(bool err) => TextStyle(
          color: err ? const Color(0xFFE05D5D) : fg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        );
    Widget cell(String t, {bool err = false, double w = 84}) =>
        SizedBox(width: w, child: Text(t, style: st(err), overflow: TextOverflow.visible, softWrap: false));
    return Column(
      key: const Key('table_rows'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          cell('x', w: 60),
          cell('f(x)'),
          if (hasG) cell('g(x)'),
        ]),
        Divider(height: 4, color: fg.withValues(alpha: 0.5)),
        for (var i = form.scroll; i < end; i++)
          Row(children: [
            cell(FunctionTable.xText(form.rows[i].x), w: 60),
            cell(FunctionTable.cell(form.rows[i].f), err: form.rows[i].f == null),
            if (hasG) cell(FunctionTable.cell(form.rows[i].g), err: form.rows[i].g == null),
          ]),
        Text(
          '${form.scroll + 1}-$end de ${form.rows.length}   ▲▼ filas · AC volver',
          style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 10),
        ),
      ],
    );
  }
}
