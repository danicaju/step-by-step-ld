part of 'calculator_screen.dart';

/// Flechas de borde de la LCD segun pasos y cursor. Las flechas ▲▼ ya no navegan por el
/// historial: el historial solo se consulta desde HIST / HISTORIAL.
extension _CalculatorScreenEdgeArrows on _CalculatorScreenState {
  LcdEdgeFlags _edgeFlags() {
    if (_calculatorMode != 1 && _calculatorMode != 2) return const LcdEdgeFlags();
    final res = _activeResolution;
    if (res != null) {
      return LcdEdgeFlags(
        left: _activeStepIndex > 0,
        right: _activeStepIndex < res.steps.length - 1,
      );
    }
    return LcdEdgeFlags(
      left: _calculatorMode == 1 && _cursorPos > 0 && _rawInput != '0',
      right: _calculatorMode == 1 && _cursorPos < _rawInput.length,
    );
  }
}
