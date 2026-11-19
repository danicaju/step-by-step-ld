import 'dart:ui';

import 'graph_key_points.dart';
import 'graph_smart_viewport.dart';
import 'graph_viewport_calculator.dart';

/// Resultado geometrico de un sistema 2x2.
enum SystemLinesKind { unique, parallel, coincident }

/// Sistema `a1 x + b1 y = c1`, `a2 x + b2 y = c2` para dibujar sus dos rectas.
class SystemLines2x2 {
  final double a1, b1, c1, a2, b2, c2;
  const SystemLines2x2(this.a1, this.b1, this.c1, this.a2, this.b2, this.c2);

  double get det => a1 * b2 - a2 * b1;

  bool get _noDet => det.abs() < 1e-12;

  /// Rectas con la misma direccion: paralelas o coincidentes.
  SystemLinesKind get kind {
    if (!_noDet) return SystemLinesKind.unique;
    final sameC = (a1 * c2 - a2 * c1).abs() < 1e-9 && (b1 * c2 - b2 * c1).abs() < 1e-9;
    return sameC ? SystemLinesKind.coincident : SystemLinesKind.parallel;
  }

  /// Punto de corte (solo con solucion unica).
  Offset? get intersection => _noDet ? null : Offset((c1 * b2 - c2 * b1) / det, (a1 * c2 - a2 * c1) / det);

  /// `2x + y = 5` con punto decimal y sin ceros sobrantes.
  static String equationText(double a, double b, double c) {
    String term(double k, String v, {required bool first}) {
      if (k.abs() < 1e-12) return '';
      final abs = k.abs();
      final body = (abs - 1).abs() < 1e-12 ? v : '${GraphKeyPoints.formatCoord(abs)}$v';
      if (first) return k < 0 ? '-$body' : body;
      return k < 0 ? ' - $body' : ' + $body';
    }

    final tx = term(a, 'x', first: true);
    final ty = term(b, 'y', first: tx.isEmpty);
    final lhs = '$tx$ty';
    return '${lhs.isEmpty ? '0' : lhs} = ${GraphKeyPoints.formatCoord(c)}';
  }

  String get eq1 => equationText(a1, b1, c1);
  String get eq2 => equationText(a2, b2, c2);

  /// Puntos que fijan el encuadre: corte, cortes con ejes de ambas rectas y el origen.
  List<Offset> notablePoints() {
    final pts = <Offset>[const Offset(0, 0)];
    final i = intersection;
    if (i != null) pts.add(i);
    void axes(double a, double b, double c) {
      if (a.abs() > 1e-9) pts.add(Offset(c / a, 0));
      if (b.abs() > 1e-9) pts.add(Offset(0, c / b));
    }

    axes(a1, b1, c1);
    axes(a2, b2, c2);
    return pts;
  }

  @override
  bool operator ==(Object other) =>
      other is SystemLines2x2 && other.a1 == a1 && other.b1 == b1 && other.c1 == c1 && other.a2 == a2 && other.b2 == b2 && other.c2 == c2;

  @override
  int get hashCode => Object.hash(a1, b1, c1, a2, b2, c2);
}

/// Encuadre inicial de las dos rectas: centrado en el punto de corte y los cortes con los ejes.
GraphWindow computeSystemViewport(SystemLines2x2 s, {double aspect = 0.6}) =>
    windowFromPoints(s.notablePoints(), aspect: aspect);
