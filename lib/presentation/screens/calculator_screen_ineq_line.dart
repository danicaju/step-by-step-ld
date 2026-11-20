part of 'calculator_screen.dart';

extension _CalculatorScreenIneqLine on _CalculatorScreenState {
  /// `true` si el paso activo es el estudio de signos / interseccion en la recta real (M6, M7 1D).
  bool get _ineqLineStepActive {
    final res = _activeResolution;
    if ((_calculatorMode != 6 && _calculatorMode != 7) || res == null || _activeIneqVisualData == null) {
      return false;
    }
    if (_activeStepIndex < 0 || _activeStepIndex >= res.steps.length) return false;
    return res.steps[_activeStepIndex].showsNumberLine;
  }

  /// Datos de la recta real para el panel de escritorio (solo M6 y M7).
  Inequality1DVisualData? get _sidePanelIneqVisual =>
      (_calculatorMode == 6 || _calculatorMode == 7) ? _activeIneqVisualData : null;
}
