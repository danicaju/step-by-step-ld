import '../arithmetic/casio_iberia_arsenal.dart';

/// Validacion previa de los datos del triangulo, con mensajes claros en MAYUSCULAS.
abstract final class TriangleInputValidator {
  static const double _eps = 1e-9;

  static ArsenalException _err(String m) => ArsenalException('Math ERROR: $m');

  static void check(List<double?> s, List<double?> a) {
    if (s.any((v) => v != null && v <= 0) || a.any((v) => v != null && v <= 0)) {
      throw _err('DATOS NO VÁLIDOS: LADOS Y ÁNGULOS DEBEN SER POSITIVOS.');
    }
    if (a.any((v) => v != null && v >= 180 - _eps)) {
      throw _err('ÁNGULO NO VÁLIDO: DEBE SER MENOR QUE 180°.');
    }
    final ns = s.whereType<double>().length, na = a.whereType<double>().length;
    if (ns == 0) throw _err('FALTAN DATOS: SE NECESITA AL MENOS UN LADO.');
    if (ns + na < 3) throw _err('FALTAN DATOS: SON NECESARIOS 3 DATOS EN TOTAL (EL ÁNGULO RECTO CUENTA).');
    if (ns + na > 3) throw _err('SOBRAN DATOS: DEJA EN BLANCO LOS HUECOS QUE QUIERES CALCULAR.');
    if (na >= 2 && a.whereType<double>().fold<double>(0, (p, v) => p + v) >= 180 - _eps) {
      throw _err('ÁNGULOS NO VÁLIDOS: SUMAN 180° O MÁS.');
    }
    if (ns == 3) {
      final x = s.cast<double>();
      if (x[0] + x[1] <= x[2] || x[0] + x[2] <= x[1] || x[1] + x[2] <= x[0]) {
        throw _err('NO ES UN TRIÁNGULO: LA SUMA DE DOS LADOS DEBE SER MAYOR QUE EL TERCERO (DESIGUALDAD TRIANGULAR).');
      }
    }
    final r = a.indexWhere((v) => v != null && (v - 90).abs() < _eps);
    if (r >= 0 && s[r] != null) {
      for (var i = 0; i < 3; i++) {
        if (i != r && s[i] != null && s[i]! >= s[r]!) {
          throw _err('NO ES UN TRIÁNGULO RECTÁNGULO: LA HIPOTENUSA DEBE SER MAYOR QUE CADA CATETO.');
        }
      }
    }
  }
}
