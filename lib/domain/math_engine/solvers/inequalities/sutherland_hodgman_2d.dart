import '../../models/inequality_models.dart';

/// Utilidades geométricas y algoritmo de Sutherland-Hodgman para regiones 2D.
class SutherlandHodgman2D {
  /// Recorta un polígono convexo contra una lista de inecuaciones normalizadas.
  static List<Point2D> clipPolygonWithInequalities(
    List<Point2D> subjectPolygon,
    List<LinearInequality2D> inequalities,
  ) {
    var output = List<Point2D>.from(subjectPolygon);
    for (final ineq in inequalities) {
      if (output.isEmpty) break;
      output = clipPolygonWithHalfPlane(output, ineq);
    }
    return output;
  }

  /// Recorta un polígono contra el semiplano cerrado normA*x + normB*y <= normC.
  static List<Point2D> clipPolygonWithHalfPlane(
    List<Point2D> poly,
    LinearInequality2D ineq,
  ) {
    final output = <Point2D>[];
    if (poly.isEmpty) return output;

    for (int i = 0; i < poly.length; i++) {
      final current = poly[i];
      final next = poly[(i + 1) % poly.length];
      final currentInside = isInside(current, ineq);
      final nextInside = isInside(next, ineq);

      if (currentInside && nextInside) {
        output.add(next);
      } else if (currentInside && !nextInside) {
        final intersection = intersectSegmentWithLine(current, next, ineq);
        if (intersection != null) output.add(intersection);
      } else if (!currentInside && nextInside) {
        final intersection = intersectSegmentWithLine(current, next, ineq);
        if (intersection != null) output.add(intersection);
        output.add(next);
      }
    }

    return _deduplicatePoints(output);
  }

  /// Comprueba si el punto P está dentro del semiplano (normA*x + normB*y <= normC + eps).
  static bool isInside(Point2D p, LinearInequality2D ineq) {
    final val = ineq.normA * p.x + ineq.normB * p.y;
    return val <= ineq.normC + 1e-9;
  }

  /// Calcula la intersección entre el segmento p1-p2 y la recta frontera normA*x + normB*y = normC.
  static Point2D? intersectSegmentWithLine(
    Point2D p1,
    Point2D p2,
    LinearInequality2D ineq,
  ) {
    final d1 = ineq.normA * p1.x + ineq.normB * p1.y - ineq.normC;
    final d2 = ineq.normA * p2.x + ineq.normB * p2.y - ineq.normC;

    final denom = d1 - d2;
    if (denom.abs() < 1e-12) return null;

    final t = (d1 / denom).clamp(0.0, 1.0);
    final ix = p1.x + t * (p2.x - p1.x);
    final iy = p1.y + t * (p2.y - p1.y);
    return Point2D(ix, iy);
  }

  /// Calcula el área de un polígono 2D mediante la fórmula de Gauss / Shoelace.
  static double computePolygonArea(List<Point2D> p) {
    if (p.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < p.length; i++) {
      final j = (i + 1) % p.length;
      area += p[i].x * p[j].y - p[j].x * p[i].y;
    }
    return (area / 2.0).abs();
  }

  /// Determina si una región es vacía, acotada o no acotada sobre una caja de gran alcance.
  static ({bool isEmpty, bool isBounded, List<Point2D> clippedPolygon}) analyzeFeasibleRegion(
    List<LinearInequality2D> ineqs, {
    double boxLimit = 1000.0,
  }) {
    final box = [
      Point2D(-boxLimit, -boxLimit),
      Point2D(boxLimit, -boxLimit),
      Point2D(boxLimit, boxLimit),
      Point2D(-boxLimit, boxLimit),
    ];

    final clipped = clipPolygonWithInequalities(box, ineqs);
    final area = computePolygonArea(clipped);

    if (clipped.length < 3 || area < 1e-4) {
      return (isEmpty: true, isBounded: false, clippedPolygon: <Point2D>[]);
    }

    final threshold = boxLimit - 10.0;
    final touchesBorder = clipped.any(
      (p) => p.x.abs() >= threshold || p.y.abs() >= threshold,
    );

    return (
      isEmpty: false,
      isBounded: !touchesBorder,
      clippedPolygon: clipped,
    );
  }

  static List<Point2D> _deduplicatePoints(List<Point2D> points) {
    final result = <Point2D>[];
    for (final p in points) {
      final exists = result.any(
        (existing) =>
            (existing.x - p.x).abs() < 1e-6 && (existing.y - p.y).abs() < 1e-6,
      );
      if (!exists) result.add(p);
    }
    return result;
  }
}
