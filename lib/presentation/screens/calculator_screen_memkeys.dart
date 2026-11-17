part of 'calculator_screen.dart';

/// M- del teclado: ALPHA + 0 resta Ans (o el ultimo resultado) de la memoria M.
/// (SHIFT y ALPHA son excluyentes, por eso M+ queda en SHIFT + ANS.)
extension _CalculatorScreenMemKeys on _CalculatorScreenState {
  bool _memMinus() {
    _isShiftActive = false;
    _isAlphaActive = false;
    final value = _evaluator.lastEvaluatedRational ?? _memory.ans;
    final updated = _memory.mMinus(value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('M- : ${value.toLatex()} restado de M. (M = ${updated.toLatex()})'),
        backgroundColor: const Color(0xFF1A2530),
        duration: const Duration(seconds: 2),
      ),
    );
    return true;
  }
}
