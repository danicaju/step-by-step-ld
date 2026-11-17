part of 'calculator_screen.dart';

/// Replay ▲/▼ del historial: solo recorre entradas del modo activo.
extension _CalculatorScreenReplay on _CalculatorScreenState {
  bool _replayMatches(ClassHistoryEntry e) {
    final mode = e.calculatorMode;
    if (mode != null) return mode == _calculatorMode;
    return _calculatorMode == 1 && e.modeName.startsWith('M1');
  }

  /// Siguiente indice con entrada del modo actual desde [from] en direccion [step].
  int _nextReplayIndex(int from, int step) {
    for (var i = from + step; i >= 0 && i < _historyEntries.length; i += step) {
      if (_replayMatches(_historyEntries[i])) return i;
    }
    return -1;
  }

  void _setReplayText(String text) {
    if (_calculatorMode == 2) {
      _restoreMode2EquationString(text);
    } else {
      _rawInput = text.isEmpty ? '0' : text;
      _cursorPos = _rawInput.length;
    }
  }

  void _cycleHistoryReplayUp() {
    final next = _nextReplayIndex(_replayIndex, 1);
    if (next < 0) return;
    if (_replayIndex == -1) {
      _draftBeforeReplay =
          _calculatorMode == 2 ? '$_eqLeftRaw = $_eqRightRaw' : _rawInput;
    }
    _replayIndex = next;
    _setReplayText(_entryToEditableRaw(_historyEntries[next]));
  }

  void _cycleHistoryReplayDown() {
    if (_replayIndex < 0) return;
    final next = _nextReplayIndex(_replayIndex, -1);
    if (next >= 0) {
      _replayIndex = next;
      _setReplayText(_entryToEditableRaw(_historyEntries[next]));
    } else {
      _replayIndex = -1;
      _setReplayText(_draftBeforeReplay);
    }
  }
}
