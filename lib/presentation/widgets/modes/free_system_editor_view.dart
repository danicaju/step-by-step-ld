import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'form_cell_box.dart';
import 'mode_form.dart';

/// Editor LCD de un sistema 2x2 / 3x3 / 4x4 en entrada libre: cada ecuacion son dos casillas
/// (`miembro izquierdo` `=` `miembro derecho`) con cursor parpadeante y D-Pad ◀ ▶ ▲ ▼.
/// La lista de ecuaciones hace scroll vertical y sigue a la fila activa.
class FreeSystemEditorView extends StatefulWidget {
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

  @override
  State<FreeSystemEditorView> createState() => _FreeSystemEditorViewState();
}

class _FreeSystemEditorViewState extends State<FreeSystemEditorView> {
  static const Color _ink = Color(0xFF1A2530);
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = List.generate(4, (_) => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followActiveRow() {
    final f = widget.form;
    final row = ((f.focus - f.base) ~/ 2).clamp(0, widget.equations - 1);
    final ctx = _rowKeys[row].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 90), alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(widget.theme);
    final fg = widget.theme == LcdTheme.night ? const Color(0xFFE8F3EE) : _ink;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followActiveRow();
    });
    final n = widget.equations;
    return Container(
      key: const Key('sys_free_editor'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.trackpad},
        ),
        child: Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            key: const Key('sys_free_scroll'),
            controller: _scroll,
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('{', style: TextStyle(color: fg, fontSize: 30.0 * n, fontWeight: FontWeight.w200, height: 1)),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var e = 0; e < n; e++) ...[
                          if (e > 0) const SizedBox(height: 6),
                          Row(
                            key: _rowKeys[e],
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(int i, Color fg, LcdPalette pal) => FormCellBox(
        field: widget.form.fields[i],
        active: widget.form.focus == i + widget.form.base,
        cellKey: Key('sys_free_cell_$i'),
        onTap: () => widget.onFocus(i + widget.form.base),
        fg: fg,
        pal: pal,
        minWidth: 104,
      );
}
