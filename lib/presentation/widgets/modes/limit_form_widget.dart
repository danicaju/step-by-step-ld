import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'expr_key_input.dart';

/// Estado del formulario de limites: `lim f(x)` cuando `x -> a`.
class LimitFormState {
  static const List<String> modeLabels = ['a', 'a⁻', 'a⁺', '+∞', '−∞'];

  String f = '';
  String a = '';

  /// 0 = a, 1 = a por la izquierda, 2 = a por la derecha, 3 = +inf, 4 = -inf.
  int mode = 0;

  /// 0 = f(x), 1 = punto de aproximacion.
  int focus = 0;

  bool get needsNumber => mode <= 2;

  /// ◀▶ cambian de casilla; ▲▼ sobre el punto cambian el modo (a, a⁻, a⁺, +∞, −∞).
  void dpad(String dir) {
    switch (dir) {
      case 'left':
        focus = 0;
      case 'right':
        focus = 1;
      case 'up':
        if (focus == 1) mode = (mode + modeLabels.length - 1) % modeLabels.length;
      case 'down':
        if (focus == 1) mode = (mode + 1) % modeLabels.length;
    }
  }

  bool key(String k, {bool alpha = false}) {
    if (focus == 0) {
      final next = ExprKeyInput.apply(f, k, alpha: alpha);
      if (next == null) return false;
      f = next;
      return true;
    }
    if (!needsNumber) return false;
    final next = ExprKeyInput.applyNumber(a, k);
    if (next == null) return false;
    a = next;
    return true;
  }

  void clear() {
    f = '';
    a = '';
    mode = 0;
    focus = 0;
  }
}

/// Vista LCD del formulario de limites (solo pinta).
class LimitFormWidget extends StatelessWidget {
  final LimitFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;

  const LimitFormWidget({super.key, required this.form, required this.theme, required this.onFocus});

  static const Color _ink = Color(0xFF1A2530);
  static const Color _amber = Color(0xFFE5A93C);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : _ink;
    Widget box(int i, String text, {double minW = 150, String? hint}) {
      final active = form.focus == i;
      return GestureDetector(
        onTap: () => onFocus(i),
        child: Container(
          key: Key('limit_cell_$i'),
          constraints: BoxConstraints(minWidth: minW, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active ? _ink : pal.inset,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? _amber : _border, width: active ? 2.2 : 1),
          ),
          child: Text(
            text.isEmpty && !active ? (hint ?? '') : text + (active ? '_' : ''),
            style: TextStyle(
              color: active ? const Color(0xFFC8D6CD) : fg,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    final modeText = LimitFormState.modeLabels[form.mode];
    return Container(
      key: const Key('limit_form_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('lim  f(x) = ', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
              box(0, form.f, minW: 170),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('x → ', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
              if (form.needsNumber) box(1, form.a, minW: 70) else box(1, modeText, minW: 70),
              const SizedBox(width: 8),
              Container(
                key: const Key('limit_mode_label'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  form.focus == 1 ? '▲ $modeText ▼' : modeText,
                  style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
