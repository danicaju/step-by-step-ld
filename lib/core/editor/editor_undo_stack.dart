/// Estado del editor que se puede restaurar: expresion y posicion del cursor.
class EditorSnapshot {
  final String expression;
  final int cursorIndex;
  const EditorSnapshot(this.expression, this.cursorIndex);

  @override
  bool operator ==(Object other) =>
      other is EditorSnapshot && other.expression == expression && other.cursorIndex == cursorIndex;

  @override
  int get hashCode => Object.hash(expression, cursorIndex);
}

/// Pila de deshacer (hasta [maxStates] estados) previa a `AC`, `DEL` o reemplazo de plantilla.
class EditorUndoStack {
  static const int maxStates = 30;
  final List<EditorSnapshot> _states = [];

  int get length => _states.length;
  bool get isEmpty => _states.isEmpty;

  /// Guarda el estado actual; ignora estados vacios (`0`) y repetidos consecutivos.
  /// Devuelve `true` si queda un estado restaurable.
  bool push(String expression, int cursorIndex) {
    if (expression.isEmpty || expression == '0') return false;
    final snap = EditorSnapshot(expression, cursorIndex);
    if (_states.isNotEmpty && _states.last == snap) return true;
    _states.add(snap);
    if (_states.length > maxStates) _states.removeAt(0);
    return true;
  }

  EditorSnapshot? pop() => _states.isEmpty ? null : _states.removeLast();

  void clear() => _states.clear();
}
