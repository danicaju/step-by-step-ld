part of 'calculator_screen.dart';

/// Visor de variables y memorias (A-F, X, Y, M, ANS) abierto con OPTN / CALC en Modo 1.
extension _CalculatorScreenMemoryView on _CalculatorScreenState {
  String _memText(Rational r) =>
      r.denominator == 1 ? '${r.numerator}' : '${r.numerator}/${r.denominator}';

  Rational _memValue(String name) =>
      name == 'M' ? _memory.independentMemoryM : _memory.getVariable(name);

  void _openMemoryViewer() {
    _isShiftActive = false;
    _isAlphaActive = false;
    _memCursor = 0;
    _isMemViewOpen = true;
  }

  Widget _buildMemoryViewer() {
    return LcdMemoryViewer(
      theme: _lcdTheme,
      values: [for (final n in kMemoryNames) _memText(_memValue(n))],
      ansText: _memText(_memory.ans),
      focus: _memCursor,
      onTapCell: (i) => updateState(() => _memCursor = i),
      onClearAll: () => updateState(_clearAllMemories),
      onClose: () => updateState(() => _isMemViewOpen = false),
    );
  }

  void _clearAllMemories() {
    _memory.clearAllVariables();
    _memory.mClear();
  }

  void _storeInMemory(String name, Rational value) {
    if (name == 'M') {
      _memory.mClear();
      _memory.mPlus(value);
    } else {
      _memory.storeVariable(name, value);
    }
  }

  /// Teclado físico con el visor abierto. Siempre consume la pulsación.
  bool _handleMemViewKey(String key) {
    _isShiftActive = false;
    _isAlphaActive = false;
    final name = kMemoryNames[_memCursor];
    switch (key) {
      case 'AC':
        _isMemViewOpen = false;
      case '=':
        _storeInMemory(name, _memory.ans);
      case 'DEL':
        _storeInMemory(name, Rational(0));
      case '+':
        _memory.mPlus(_memory.ans);
      case '-':
        _memory.mMinus(_memory.ans);
    }
    return true;
  }

  /// D-Pad 2D sobre la tabla 3x3; ◀ en la primera columna vuelve a la calculadora.
  void _memViewDpad(String dir) {
    final row = _memCursor ~/ 3;
    final col = _memCursor % 3;
    switch (dir) {
      case 'left':
        if (col == 0) {
          _isMemViewOpen = false;
        } else {
          _memCursor--;
        }
      case 'right':
        if (col < 2) _memCursor++;
      case 'up':
        _memCursor = ((row + 2) % 3) * 3 + col;
      case 'down':
        _memCursor = ((row + 1) % 3) * 3 + col;
    }
  }
}
