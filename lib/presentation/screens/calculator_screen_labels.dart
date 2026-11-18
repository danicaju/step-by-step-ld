part of 'calculator_screen.dart';

extension _CalculatorScreenLabels on _CalculatorScreenState {
  /// Insignia de modo de la LCD con los nombres oficiales (M1: CALCULAR ... M12: DERIV. E INT.).
  String _modeLabelText() {
    final modeLabels = {
      1: 'M1: CALCULAR',
      2: 'M2: ECUACIONES',
      3: _systemDim == 3 ? 'M3: SIST 3×3' : 'M3: SIST 2×2',
      4: _cw.x.m4View >= 2
          ? 'M4: POLINOMIOS'
          : _polyIsNotableMode
          ? 'M4: NOTABLES'
          : (_isChoosingRuffiniDegree
              ? 'M4: RUFFINI'
              : 'M4: RUFFINI ($_ruffiniDegree.º)'),
      5: switch (_graphKind) {
        1 => 'M5: RACIONAL',
        2 => 'M5: f(x) LIBRE',
        _ => 'M5: PARÁBOLAS',
      },
      6: switch (_ineqDegree) {
        1 => 'M6: INEC. 1°',
        2 => 'M6: INEC. 2°',
        _ => 'M6: |x| / RAC.',
      },
      7: _ineqSysUnknowns == 1 ? 'M7: SIST. INEC 1D' : 'M7: REGIÓN 2D',
      8: 'M8: ESTADÍST.',
      9: 'M9: MATRICES ($_matrixRowsA×$_matrixColsA)',
      10: 'M10: VECTORES ${_vectorDim}D',
      11: 'M11: COMPLEJOS',
      12: 'M12: DERIV. E INT.',
    };
    return modeLabels[_calculatorMode] ?? 'M1: CALCULAR';
  }
}
