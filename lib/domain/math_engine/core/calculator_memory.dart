import 'rational.dart';

/// Gestor de Memoria Científica para Calculadora Casio ClassWiz
/// Soporta memoria de respuesta (ANS), memoria acumulativa independiente (M+, M-, MR, MC)
/// y memorias de variables alfabéticas (A, B, C, D, E, F, X, Y).
class CalculatorMemoryManager {
  Rational _ans = Rational(0);
  Rational _independentMemoryM = Rational(0);

  final Map<String, Rational> _variables = {
    'A': Rational(0),
    'B': Rational(0),
    'C': Rational(0),
    'D': Rational(0),
    'E': Rational(0),
    'F': Rational(0),
    'X': Rational(0),
    'Y': Rational(0),
  };

  /// Memoria ANS: última respuesta evaluada
  Rational get ans => _ans;

  /// Memoria independiente M
  Rational get independentMemoryM => _independentMemoryM;

  /// Indica si el indicador [M] debe estar activo en la barra superior de la LCD
  bool get hasActiveM => _independentMemoryM.numerator != 0;

  /// Mapa inmutable con todas las memorias de variables
  Map<String, Rational> get variables => Map.unmodifiable(_variables);

  /// Actualiza la memoria ANS tras pulsar =
  void setAns(Rational result) {
    _ans = result.simplify();
  }

  /// Operación M+: Suma el valor a la memoria independiente M
  Rational mPlus(Rational value) {
    _independentMemoryM = (_independentMemoryM + value).simplify();
    return _independentMemoryM;
  }

  /// Operación M-: Resta el valor a la memoria independiente M
  Rational mMinus(Rational value) {
    _independentMemoryM = (_independentMemoryM - value).simplify();
    return _independentMemoryM;
  }

  /// Recupera el valor actual de la memoria M (MR)
  Rational mRecall() => _independentMemoryM;

  /// Borra la memoria M a 0 (MC)
  void mClear() {
    _independentMemoryM = Rational(0);
  }

  /// Almacena un valor en una variable específica (A..F, X, Y)
  void storeVariable(String name, Rational value) {
    final key = name.toUpperCase();
    _variables[key] = value.simplify();
  }

  /// Obtiene el valor de una variable (A..F, X, Y) o 0 si no existe
  Rational getVariable(String name) {
    final key = name.toUpperCase();
    if (key == 'ANS') return _ans;
    if (key == 'M') return _independentMemoryM;
    return _variables[key] ?? Rational(0);
  }

  /// Devuelve el mapa completo con ANS, M y todas las variables registradas
  Map<String, Rational> getAllVariablesWithAns() {
    return {
      'ANS': _ans,
      'M': _independentMemoryM,
      ..._variables,
    };
  }

  /// Borra todas las variables a 0
  void clearAllVariables() {
    for (final key in _variables.keys.toList()) {
      _variables[key] = Rational(0);
    }
  }

  /// Reinicia toda la memoria de la calculadora a su estado de fábrica
  void resetAll() {
    _ans = Rational(0);
    _independentMemoryM = Rational(0);
    clearAllVariables();
  }
}
