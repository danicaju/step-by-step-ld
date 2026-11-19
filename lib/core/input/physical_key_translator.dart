import 'package:flutter/services.dart';

/// Accion de calculadora producida por una tecla del teclado fisico.
enum PhysicalActionKind { key, dpad, undo }

class PhysicalAction {
  final PhysicalActionKind kind;
  final String value;
  const PhysicalAction.key(this.value) : kind = PhysicalActionKind.key;
  const PhysicalAction.dpad(this.value) : kind = PhysicalActionKind.dpad;
  const PhysicalAction.undo()
      : kind = PhysicalActionKind.undo,
        value = '';

  @override
  String toString() => '${kind.name}:$value';
}

/// Traduce eventos del teclado fisico a pulsaciones de la calculadora.
///
/// Mantiene un buffer de letras para detectar `sin(`, `cos(`, `tan(`, `log(`, `ln(` y `sqrt(`;
/// `x`, `y`, `e` e `i` se emiten como variables cuando no forman parte de una funcion.
class PhysicalKeyTranslator {
  String _pending = '';

  static const Map<String, List<String>> _functions = {
    'sin': ['sin'],
    'cos': ['cos'],
    'tan': ['tan'],
    'log': ['LOG'],
    'ln': ['ALPHA', 'LOG'],
    'sqrt': ['√'],
  };

  static const Map<String, List<String>> _variables = {
    'x': ['ALPHA', ')'],
    'y': ['ALPHA', '('],
    'e': ['ALPHA', 'SCI10'],
    'i': ['i'],
  };

  static final Map<LogicalKeyboardKey, String> _dpad = {
    LogicalKeyboardKey.arrowLeft: 'left',
    LogicalKeyboardKey.arrowRight: 'right',
    LogicalKeyboardKey.arrowUp: 'up',
    LogicalKeyboardKey.arrowDown: 'down',
  };

  bool _isPrefix(String s) => _functions.keys.any((f) => f.startsWith(s));

  List<PhysicalAction> _flush() {
    final out = <PhysicalAction>[];
    for (final ch in _pending.split('')) {
      final v = _variables[ch];
      if (v != null) out.addAll(v.map(PhysicalAction.key));
    }
    _pending = '';
    return out;
  }

  /// Acciones para la pulsacion, o `null` si la tecla no pertenece a la calculadora.
  List<PhysicalAction>? translate({
    required LogicalKeyboardKey logical,
    String? character,
    bool shift = false,
    bool ctrlOrMeta = false,
    bool alt = false,
  }) {
    if (ctrlOrMeta) {
      if (logical == LogicalKeyboardKey.keyZ) return [const PhysicalAction.undo()];
      return null; // Ctrl+C, Ctrl+V...: del navegador
    }
    if (alt) {
      return logical == LogicalKeyboardKey.keyP ? [const PhysicalAction.key('PI')] : null;
    }
    final dir = _dpad[logical];
    if (dir != null) return [..._flush(), PhysicalAction.dpad(dir)];
    String? ctrl;
    if (logical == LogicalKeyboardKey.enter || logical == LogicalKeyboardKey.numpadEnter) {
      ctrl = '=';
    } else if (logical == LogicalKeyboardKey.backspace) {
      ctrl = 'DEL';
    } else if (logical == LogicalKeyboardKey.escape || logical == LogicalKeyboardKey.delete) {
      ctrl = 'AC';
    }
    if (ctrl != null) {
      final drop = ctrl == 'DEL' && _pending.isNotEmpty;
      if (drop) {
        _pending = _pending.substring(0, _pending.length - 1);
        return const [];
      }
      return [..._flush(), PhysicalAction.key(ctrl)];
    }
    if (logical == LogicalKeyboardKey.slash || logical == LogicalKeyboardKey.numpadDivide) {
      return [..._flush(), PhysicalAction.key(shift ? ':' : '/')];
    }
    final ch = (character ?? '').toLowerCase();
    if (ch.length != 1) return null;
    if (RegExp(r'[a-z]').hasMatch(ch)) {
      final next = _pending + ch;
      if (_isPrefix(next)) {
        _pending = next;
        return const [];
      }
      final out = _flush();
      if (_isPrefix(ch)) {
        _pending = ch;
        return out;
      }
      return [...out, ...?_variables[ch]?.map(PhysicalAction.key)];
    }
    if (ch == '(' && _functions.containsKey(_pending)) {
      final keys = _functions[_pending]!;
      _pending = '';
      // La funcion abre su propio parentesis: no se envia `(` aparte.
      return keys.map(PhysicalAction.key).toList();
    }
    final out = _flush();
    final mapped = switch (ch) {
      ',' || '.' => ['.'],
      '^' => ['SHIFT', '^2'],
      ':' || '÷' => [':'],
      '×' => ['*'],
      '+' || '-' || '*' || '(' || ')' => [ch],
      _ => RegExp(r'^[0-9]$').hasMatch(ch) ? [ch] : null,
    };
    if (mapped == null) return out.isEmpty ? null : out;
    return [...out, ...mapped.map(PhysicalAction.key)];
  }
}
