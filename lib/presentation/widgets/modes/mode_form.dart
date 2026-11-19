import 'package:flutter/material.dart';

import '../../../domain/math_engine/parser/expression_parser.dart';
import '../../utils/cell_fraction_editor.dart';
import '../../utils/expr_cursor_nav.dart';
import '../lcd/lcd_palette.dart';
import 'expr_key_input.dart';
import 'form_cell_box.dart';

/// Campo de un formulario: `expr` = expresion en x; si no, numero (`0-9 . - /`).
class ModeField {
  final String label;
  final bool expr;
  String text;

  /// Posicion del cursor en [text] (solo campos `expr`; por defecto, al final).
  int cursor;
  ModeField(this.label, {this.expr = false, this.text = ''}) : cursor = text.length;

  int get pos => cursor.clamp(0, text.length);

  void set(String t, int c) {
    text = t;
    cursor = c.clamp(0, t.length);
  }
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
  int _focus = 0;

  /// En un campo numerico con fraccion abierta: `true` edita el numerador, `false` el denominador.
  bool fracNum = false;

  int get focus => _focus;
  set focus(int v) {
    if (v != _focus) fracNum = false;
    _focus = v;
  }

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

  /// D-Pad. Dentro de una casilla se navega primero por su contenido (fraccion numerica,
  /// plantillas de la expresion, numerador/denominador internos); solo si no hay
  /// movimiento interno se cambia de casilla. Nunca sale del formulario hacia la cabecera.
  void dpad(String dir) {
    final cur = active;
    if (cur != null && !cur.expr) {
      final next = CellFractionEditor.dpad(cur.text, fracNum, dir);
      if (next != null) {
        fracNum = next;
        return;
      }
    }
    if (cur != null && cur.expr && _exprDpad(cur, dir)) return;
    final before = focus;
    if (fractionStyle) {
      _fractionDpad(dir);
    } else {
      _linearDpad(dir);
    }
    final now = active;
    if (focus != before && now != null && now.expr) {
      now.cursor = dir == 'right' ? 0 : now.text.length;
    }
  }

  /// Movimiento interno en una casilla de expresion; `true` si lo consume.
  bool _exprDpad(ModeField f, String dir) {
    final raw = f.text;
    final pos = f.pos;
    switch (dir) {
      case 'left':
      case 'right':
        final (r, c) = dir == 'left' ? ExprCursorNav.left(raw, pos) : ExprCursorNav.right(raw, pos);
        if (r == raw && c == pos) return false;
        f.set(r, c);
        return true;
      default:
        final j = ExprCursorNav.vertical(raw, pos, up: dir == 'up');
        if (j == null || j == pos) return false;
        f.cursor = j;
        return true;
    }
  }

  void _linearDpad(String dir) {
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
    if (f.expr) return _exprKey(f, k, alpha);
    if (_fractionKey(f, k)) return true;
    final next = ExprKeyInput.applyNumber(f.text, k);
    if (next == null) return false;
    f.text = next;
    return true;
  }

  /// Edicion de expresion en la posicion del cursor (`a/b` abre una fraccion vertical real).
  bool _exprKey(ModeField f, String k, bool alpha) {
    final pos = f.pos;
    if (k == 'DEL') {
      final (r, c) = ExpressionParser.deleteAtCursor(f.text, pos, emptyResult: '', emptyCursor: 0);
      f.set(r, c);
      return true;
    }
    if (k == '/') {
      final (r, c) = FractionTemplate.insert(f.text, pos);
      f.set(r, c);
      return true;
    }
    final token = ExprKeyInput.tokenFor(k, alpha: alpha);
    if (token == null) return false;
    final (r, c) = ExpressionParser.insertAtCursor(f.text, pos, token, keepLeadingZero: true);
    f.set(r, c);
    return true;
  }

  /// Teclas de un campo numerico con a/b: se puede abrir la fraccion con el campo vacio.
  bool _fractionKey(ModeField f, String k) {
    final isDigitLike = RegExp(r'^[0-9.\-]$').hasMatch(k);
    if (k == '/') {
      final (text, num) = CellFractionEditor.slash(f.text, fracNum);
      f.text = text;
      fracNum = num;
      return true;
    }
    if (!f.text.contains('/')) return false;
    if (k == 'DEL') {
      final (text, num) = CellFractionEditor.backspace(f.text, fracNum);
      f.text = text;
      fracNum = num;
      return true;
    }
    if (!isDigitLike) return false;
    f.text = CellFractionEditor.append(f.text, k, fracNum);
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
        f.set('', 0);
      }
    }
    selector = 0;
    focus = 0;
    fracNum = false;
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
    return FormCellBox(
      field: f,
      active: form.focus == i + form.base,
      cellKey: Key('${keyPrefix}_cell_$i'),
      onTap: () => onFocus(i + form.base),
      fg: fg,
      pal: pal,
      minWidth: f.expr ? 120 : 52,
      caption: f.label,
      fracNumerator: form.fracNum,
    );
  }
}
