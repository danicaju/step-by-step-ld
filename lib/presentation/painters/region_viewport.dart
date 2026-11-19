import 'dart:ui';

import '../../domain/math_engine/models/inequality_models.dart';
import 'graph_smart_viewport.dart';
import 'graph_viewport_calculator.dart';

/// Encuadre inicial de la region factible 2D: abarca los vertices, los cortes de cada recta
/// frontera con los ejes y el origen (para que los ejes sigan a la vista), con margen del 30 %.
GraphWindow computeRegionViewport(FeasibleRegion2DVisualData data, {double aspect = 0.6}) {
  final pts = <Offset>[const Offset(0, 0)];
  for (final v in data.vertices) {
    pts.add(Offset(v.x, v.y));
  }
  for (final q in data.inequalities) {
    if (q.a.abs() > 1e-9) pts.add(Offset(q.c / q.a, 0));
    if (q.b.abs() > 1e-9) pts.add(Offset(0, q.c / q.b));
  }
  return windowFromPoints(pts, aspect: aspect);
}
