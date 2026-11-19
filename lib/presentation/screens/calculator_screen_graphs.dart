part of 'calculator_screen.dart';

/// Graficas interactivas de M3 (sistema 2x2) y M7 (region 2D): estado y construccion del visor.
extension _CalculatorScreenGraphs on _CalculatorScreenState {
  /// Rectas del sistema 2x2 resuelto (coeficientes racionales a decimales para dibujar).
  void _storeSystemLines(List<Rational> r1, List<Rational> r2, StepByStepResolution res) {
    _systemLines = SystemLines2x2(
      r1[0].toDouble(),
      r1[1].toDouble(),
      r1[2].toDouble(),
      r2[0].toDouble(),
      r2[1].toDouble(),
      r2[2].toDouble(),
    );
    _systemLinesRes = res;
    _showSystemGraph = false;
  }

  /// ¿Hay grafica del sistema 2x2 para la resolucion activa?
  bool get _hasSystemGraph =>
      _calculatorMode == 3 &&
      _systemDim == 2 &&
      _systemLines != null &&
      _activeResolution != null &&
      identical(_activeResolution, _systemLinesRes);

  Widget? _buildSystemGraph() {
    if (!_hasSystemGraph || !_showSystemGraph) return null;
    if (_lcdErrorKind != null || _isMenuOpen || _isSetupOpen) return null;
    return SystemLinesGraph(system: _systemLines!, controller: _systemViewport);
  }
}
