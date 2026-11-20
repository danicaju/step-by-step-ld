import 'dart:math' as math;

import '../trig_and_angles_solver.dart' show AngleUnit;

/// Funciones de una variable que el cambio de variable N x N sabe invertir ademas de las
/// clasicas: hiperbolicas (senh, cosh, tgh) y trigonometricas inversas (arcsen, arccos, arctg).
abstract final class NdAtomInverses {
  static const Set<String> kinds = {'sinh', 'cosh', 'tanh', 'asin', 'acos', 'atan'};

  /// Mitad de vuelta en la unidad activa (`180`, `pi`, `200`).
  static double _half(AngleUnit u) => switch (u) {
        AngleUnit.deg => 180,
        AngleUnit.grad => 200,
        AngleUnit.rad => math.pi,
      };

  static double _toRad(double v, AngleUnit u) => v * math.pi / _half(u);

  /// Valores de `g` con `kind(g) = u`; lista vacia si [u] esta fuera del recorrido de la funcion.
  static List<double> invert(String kind, double u, AngleUnit unit) {
    const eps = 1e-9;
    switch (kind) {
      case 'sinh':
        return [u < 0 ? -math.log(-u + math.sqrt(u * u + 1)) : math.log(u + math.sqrt(u * u + 1))];
      case 'cosh':
        if (u < 1 - eps) return const [];
        final a = math.log(u + math.sqrt(math.max(u * u - 1, 0)));
        return a.abs() < 1e-12 ? [0.0] : [a, -a];
      case 'tanh':
        return u.abs() < 1 - eps ? [0.5 * math.log((1 + u) / (1 - u))] : const [];
      case 'asin':
        return u.abs() <= _half(unit) / 2 + eps ? [math.sin(_toRad(u, unit))] : const [];
      case 'acos':
        return u >= -eps && u <= _half(unit) + eps ? [math.cos(_toRad(u, unit))] : const [];
      default: // atan
        return u.abs() < _half(unit) / 2 - eps ? [math.tan(_toRad(u, unit))] : const [];
    }
  }

  /// Condicion de existencia de `u = kind(g)` en texto plano.
  static String note(String kind) => switch (kind) {
        'cosh' => 'u mayor o igual que 1 (el coseno hiperbólico nunca baja de 1)',
        'tanh' => 'u entre -1 y 1 sin tocarlos (la tangente hiperbólica queda dentro de ese intervalo)',
        'asin' => 'u dentro del recorrido del arco seno, entre -90 y 90 grados (entre -π/2 y π/2 en radianes)',
        'acos' => 'u dentro del recorrido del arco coseno, entre 0 y 180 grados (entre 0 y π en radianes)',
        'atan' => 'u dentro del recorrido del arco tangente, entre -90 y 90 grados sin tocarlos',
        _ => 'sin restricción para u',
      };
}
