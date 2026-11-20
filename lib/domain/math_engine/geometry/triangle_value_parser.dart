import 'dart:math' as math;

import '../arithmetic/casio_iberia_arsenal.dart';

/// Valor numerico de una casilla del editor de triangulos: enteros, decimales, fracciones
/// `(a)/(b)`, raices `√(...)`, potencias `^( )`, `π` y las cuatro operaciones.
abstract final class TriangleValueParser {
  /// `null` si la casilla esta vacia (= incognita).
  static double? parseOrNull(String text) {
    final s = text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    final p = _P(s);
    final v = p.expr();
    if (p.i != s.length || v.isNaN || v.isInfinite) throw _bad();
    return v;
  }

  static ArsenalException _bad() => const ArsenalException('Sintaxis incompleta: Revisa los datos del triángulo.');
}

class _P {
  final String s;
  int i = 0;
  _P(this.s);

  bool _at(String c) => i < s.length && s[i] == c;

  double expr() {
    var v = term();
    while (i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final r = term();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double term() {
    var v = unary();
    while (i < s.length) {
      final c = s[i];
      if (c == '*' || c == '×' || c == '·') {
        i++;
        v *= unary();
      } else if (c == '/' || c == '÷' || c == ':') {
        i++;
        final d = unary();
        if (d == 0) throw const ArsenalException('Math ERROR: División entre 0 en una casilla.');
        v /= d;
      } else if (c == '(' || c == '√' || c == 'π') {
        v *= power(); // producto implicito: 2√(3), 3(1+1)
      } else {
        break;
      }
    }
    return v;
  }

  double unary() {
    if (_at('-')) {
      i++;
      return -unary();
    }
    if (_at('+')) {
      i++;
      return unary();
    }
    return power();
  }

  double power() {
    final b = atom();
    if (_at('^')) {
      i++;
      final e = _at('(') ? atom() : unary();
      return math.pow(b, e).toDouble();
    }
    return b;
  }

  double atom() {
    if (i >= s.length) throw const ArsenalException('Sintaxis incompleta: Revisa los datos del triángulo.');
    final c = s[i];
    if (c == '(') {
      i++;
      final v = expr();
      if (_at(')')) i++;
      return v;
    }
    if (c == '√') {
      i++;
      final v = _at('(') ? atom() : power();
      if (v < 0) throw const ArsenalException('Math ERROR: Raíz de un número negativo en una casilla.');
      return math.sqrt(v);
    }
    if (c == 'π') {
      i++;
      return math.pi;
    }
    final start = i;
    while (i < s.length && (RegExp(r'[0-9.]').hasMatch(s[i]))) {
      i++;
    }
    final v = double.tryParse(s.substring(start, i));
    if (v == null) throw const ArsenalException('Sintaxis incompleta: Revisa los datos del triángulo.');
    return v;
  }
}
