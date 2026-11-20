import '../models/step_resolution.dart';
import 'triangle_exact.dart';

/// Una solucion completa: lados a, b, c y angulos A, B, C (grados), opuestos dos a dos.
class TriangleSolution {
  final List<double> sides; // a, b, c
  final List<double> angles; // A, B, C
  /// Lados con su forma exacta (radicales) cuando existe.
  final List<Val>? vals;
  const TriangleSolution(this.sides, this.angles, {this.vals});
}

class TriangleResult {
  final List<TriangleSolution> solutions;
  final String kind; // pitagoras | coseno | seno | ambiguo
  final StepByStepResolution resolution;
  const TriangleResult(this.solutions, this.kind, this.resolution);
  bool get isAmbiguous => solutions.length > 1;
}
