import 'package:flutter/material.dart';

import '../lcd/lcd_palette.dart';
import 'expr_key_input.dart';

/// Campo de un formulario: `expr` = expresion en x; si no, numero (`0-9 . - /`).
class ModeField {
  final String label;
  final bool expr;
  String text;
  ModeField(this.label, {this.expr = false, this.text = ''});
}

/// Formulario generico de las vistas nuevas (sin TextField: teclado fisico + D-Pad).
///
/// Foco 0 = selector ciclico (si lo hay); luego los campos de la disposicion activa.
/// ◀ ▶ cambian de campo (o de opcion con el selector enfocado), ▲ ▼ mueven por filas.
class ModeFormState {
  final List<String> selectorLabels;
  final List<List<ModeField>> layouts;
  final int cols;

  /// Navegacion de fracciones verticales: foco 0 = operador; 1/2 = num/den izquierda
  /// (o unica); 3/4 = num/den derecha. ▲▼ cambian num/den (o la operacion en el operador).
  final bool fractionStyle;

  int selector = 0;
  int focus = 0;

  ModeFormState({
    this.selectorLabels = const [],
    required this.layouts,
    this.cols = 1,
    this.fractionStyle = false,
  });

  bool get hasSelector => selectorLabels.isNotEmpty;
  int get base => hasSelector ? 1 : 0;
  List<ModeField> get fields => layouts[selector];
  bool get atTop => fractionStyle ? (focus == 1 || focus == 3) : focus == 0;
  ModeField? get active => focus - base >= 0 && focus - base < fields.length ? fields[focus - base] : null;
  String text(int i) => fields[i].text;

  /// D-Pad. `true` siempre (el formulario consume la pulsacion).
  void dpad(String dir) {
    if (fractionStyle) {
      _fractionDpad(dir);
      return;
    }
    final last = base + fields.length - 1;
    switch (dir) {
      case 'left':
        if (hasSelector && focus == 0) {
          selector = (selector + layouts.length - 1) % layouts.length;
        } else if (focus > 0) {
          focus--;
        }
      case 'right':
        if (hasSelector && focus == 0) {
          selector = (selector + 1) % layouts.length;
        } else if (focus < last) {
          focus++;
        }
      case 'up':
        if (focus - cols >= base) {
          focus -= cols;
        } else if (hasSelector && focus > 0) {
          focus = 0;
        }
      case 'down':
        if (hasSelector && focus == 0) {
          focus = fields.isEmpty ? 0 : 1;
        } else if (focus + cols <= last) {
          focus += cols;
        }
    }
    if (focus > last) focus = last;
  }

  void _fractionDpad(String dir) {
    final two = selector != 0;
    switch (dir) {
      case 'left':
        if (focus == 0) {
          if (two) focus = 1;
        } else if (!two || focus >= 3) {
          focus = 0;
        }
      case 'right':
        if (focus == 0) {
          focus = two ? 3 : 1;
        } else if (two && focus <= 2) {
          focus = 0;
        }
      case 'up':
        if (focus == 0) {
          selector = (selector + layouts.length - 1) % layouts.length;
        } else if (focus == 2 || focus == 4) {
          focus--;
        }
      case 'down':
        if (focus == 0) {
          selector = (selector + 1) % layouts.length;
        } else if (focus == 1 || focus == 3) {
          focus++;
        }
    }
    final last = base + fields.length - 1;
    if (focus > last) focus = last;
  }

  /// Aplica una tecla al campo activo. `true` si la consumio.
  bool key(String k, {bool alpha = false}) {
    final f = active;
    if (f == null) return false;
    final next = f.expr ? ExprKeyInput.apply(f.text, k, alpha: alpha) : ExprKeyInput.applyNumber(f.text, k);
    if (next == null) return false;
    f.text = next;
    return true;
  }

  /// `=`: avanza al siguiente campo; devuelve `true` si estaba en el ultimo (hay que resolver).
  bool advance() {
    final last = base + fields.length - 1;
    if (focus < last) {
      focus++;
      return false;
    }
    return true;
  }

  void clear() {
    for (final l in layouts) {
      for (final f in l) {
        f.text = '';
      }
    }
    selector = 0;
    focus = 0;
  }
}

/// Vista LCD del formulario (solo pinta; las teclas las gestiona la pantalla).
class ModeFormWidget extends StatelessWidget {
  final ModeFormState form;
  final LcdTheme theme;
  final ValueChanged<int> onFocus;
  final String keyPrefix;
  final String? title;

  const ModeFormWidget({
    super.key,
    required this.form,
    required this.theme,
    required this.onFocus,
    this.keyPrefix = 'mode_form',
    this.title,
  });

  static const Color _ink = Color(0xFF1A2530);
  static const Color _amber = Color(0xFFE5A93C);
  static const Color _border = Color(0xFF7A8A7E);

  @override
  Widget build(BuildContext context) {
    final pal = LcdPalette.of(theme);
    final fg = theme == LcdTheme.night ? const Color(0xFFE8F3EE) : _ink;
    final rows = <List<int>>[];
    for (var i = 0; i < form.fields.length; i += form.cols) {
      rows.add([for (var j = i; j < i + form.cols && j < form.fields.length; j++) j]);
    }
    return Container(
      key: Key('${keyPrefix}_widget'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Text(title!, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
            if (form.hasSelector) ...[
              GestureDetector(
                onTap: () => onFocus(0),
                child: Container(
                  key: Key('${keyPrefix}_selector'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: form.focus == 0 ? _ink : pal.inset,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: form.focus == 0 ? _amber : _border, width: form.focus == 0 ? 2.2 : 1),
                  ),
                  child: Text(
                    '◀ ${form.selectorLabels[form.selector]} ▶',
                    style: TextStyle(
                      color: form.focus == 0 ? const Color(0xFFC8D6CD) : fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
            for (final row in rows) ...[
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final i in row) ...[_cell(i, fg, pal), const SizedBox(width: 6)],
              ]),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(int i, Color fg, LcdPalette pal) {
    final f = form.fields[i];
    final active = form.focus == i + form.base;
    return GestureDetector(
      onTap: () => onFocus(i + form.base),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(f.label, style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 10)),
        Container(
          key: Key('${keyPrefix}_cell_$i'),
          constraints: BoxConstraints(minWidth: f.expr ? 120 : 52, minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active ? _ink : pal.inset,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? _amber : _border, width: active ? 2.2 : 1),
          ),
          child: Text(
            f.text + (active ? '_' : ''),
            style: TextStyle(
              color: active ? const Color(0xFFC8D6CD) : fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    );
  }
}
