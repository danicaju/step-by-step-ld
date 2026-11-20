import '../../domain/math_engine/models/inequality_models.dart';

/// Reparto vertical de la recta real: banda superior (SI / NO), central (recta) e inferior
/// (etiquetas LaTeX de los puntos criticos). Alturas generosas para no recortar nunca.
abstract final class NumberLineBands {
  static const double top = 34;
  static const double mid = 30;
  static const double bottom = 56;
  static const double body = top + mid + bottom;

  /// Ordenada de la recta dentro del cuerpo.
  static const double lineY = top + mid / 2;
}

/// Colocacion horizontal esquematica de la recta de signos: los puntos criticos se reparten
/// a distancias iguales (como en los apuntes), de modo que nunca se solapan las etiquetas.
class NumberLineLayout {
  final List<double> anchors;
  final double gap;
  final double paddingX;
  final double contentWidth;

  const NumberLineLayout._(this.anchors, this.gap, this.paddingX, this.contentWidth);

  static const double minGap = 78;

  /// Distancia real entre dos puntos criticos consecutivos.
  double get step => (contentWidth - 2 * paddingX) / (anchors.length + 1);

  /// `true` cuando hay 4 o mas puntos y el contenido no cabe: se desplaza horizontalmente.
  bool scrolls(double availWidth) => contentWidth > availWidth + 0.5;

  factory NumberLineLayout.of(Inequality1DVisualData data, double availWidth, {double paddingX = 40}) {
    final set = <double>[];
    void add(double v) {
      if (v.isFinite && !set.any((a) => (a - v).abs() <= 1e-9 * (1 + a.abs()))) set.add(v);
    }

    for (final p in data.criticalPoints) {
      add(p.value);
    }
    for (final list in [data.primaryIntervals, data.secondaryIntervals, data.intersectionIntervals, data.signTestIntervals]) {
      for (final i in list ?? const <InequalityInterval>[]) {
        add(i.start);
        add(i.end);
      }
    }
    set.sort();
    final m = set.length;
    final fit = (availWidth - 2 * paddingX) / (m + 1);
    final double gap = m >= 4 ? (fit < minGap ? minGap : fit) : (fit < 56.0 ? 56.0 : fit);
    final width = 2 * paddingX + (m + 1) * gap;
    return NumberLineLayout._(set, gap, paddingX, width < availWidth ? availWidth : width);
  }

  /// Abscisa en pantalla del valor [v] (los extremos infinitos van a los bordes de la recta).
  double x(double v) {
    if (v == double.negativeInfinity) return paddingX;
    if (v == double.infinity) return contentWidth - paddingX;
    final base = step;
    if (anchors.isEmpty) return paddingX + base;
    var idx = -1;
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - v).abs() <= 1e-9 * (1 + v.abs())) idx = i;
    }
    if (idx >= 0) return paddingX + (idx + 1) * base;
    if (v < anchors.first) return paddingX + base * 0.5;
    if (v > anchors.last) return paddingX + base * (anchors.length + 0.5);
    for (var i = 0; i < anchors.length - 1; i++) {
      if (v > anchors[i] && v < anchors[i + 1]) {
        final t = (v - anchors[i]) / (anchors[i + 1] - anchors[i]);
        return paddingX + base * (i + 1 + t);
      }
    }
    return paddingX + base;
  }
}
