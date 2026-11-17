import 'dart:math' as math;

import '../../core/number_formatter.dart';
import '../../core/rational.dart';
import '../../models/complex_models.dart';
import '../../models/step_resolution.dart';
import '../trig_and_angles_solver.dart';
import 'complex_polar_solver.dart';

/// Resultado de Pol/Rec: resolución paso a paso y valores numéricos para memorias X e Y.
class PolRecResult {
  final StepByStepResolution resolution;
  final double first;
  final double second;
  const PolRecResult(this.resolution, this.first, this.second);
}

/// Conversión de coordenadas cartesianas ↔ polares (teclas SHIFT + `+` y SHIFT + `-`).
class PolRecSolver {
  const PolRecSolver._();

  static String _unitSymbol(AngleUnit u) => switch (u) {
        AngleUnit.deg => '^\\circ',
        AngleUnit.rad => '\\text{ rad}',
        AngleUnit.grad => '\\text{ gra}',
      };

  static double _fromDegrees(double deg, AngleUnit u) => switch (u) {
        AngleUnit.deg => deg,
        AngleUnit.rad => deg * math.pi / 180.0,
        AngleUnit.grad => deg * 200.0 / 180.0,
      };

  static double _toDegrees(double v, AngleUnit u) => switch (u) {
        AngleUnit.deg => v,
        AngleUnit.rad => v * 180.0 / math.pi,
        AngleUnit.grad => v * 180.0 / 200.0,
      };

  static String _num(double v) => NumberFormatter.decimal(v, maxDecimals: 6);

  /// `Pol(x, y)` -> módulo `r` y ángulo `θ`.
  static PolRecResult pol(Rational x, Rational y, AngleUnit unit) {
    final z = RationalComplex(x, y);
    final analysis = ComplexPolarSolver.analyzeToPolar(z);
    final r = math.sqrt(x.toDouble() * x.toDouble() + y.toDouble() * y.toDouble());
    final thetaDeg = analysis.polarAngleDegrees ?? 0.0;
    final theta = _fromDegrees(thetaDeg, unit);
    final rLatex = analysis.polarModulusLatex ?? _num(r);
    final xl = x.toLatex();
    final yl = y.toLatex();
    final u = _unitSymbol(unit);
    final steps = [
      MathStep(
        index: 1,
        shortTitle: 'Coordenadas cartesianas',
        latexExpression: '\\mathrm{Pol}($xl,\\,$yl)',
        pedagogicalNote:
            'Pol convierte el punto (x, y) en coordenadas polares: módulo r y ángulo θ.',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Módulo r',
        latexExpression: 'r = \\sqrt{x^{2}+y^{2}} = \\sqrt{($xl)^{2}+($yl)^{2}} = $rLatex',
        pedagogicalNote: 'El módulo es la distancia del punto al origen (Pitágoras).',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Ángulo θ',
        latexExpression:
            '\\theta = \\arctan\\left(\\frac{y}{x}\\right) \\Rightarrow \\theta = ${_num(theta)}$u',
        pedagogicalNote:
            'El ángulo se mide desde el eje X positivo y se ajusta al cuadrante de (x, y).',
        warningTrick: 'Comprueba el cuadrante: arctan(y/x) solo da ángulos entre -90 y 90 grados.',
      ),
    ];
    return PolRecResult(
      StepByStepResolution(
        originalInputLatex: '\\mathrm{Pol}($xl,\\,$yl)',
        steps: steps,
        exactResultLatex: 'r = $rLatex,\\; \\theta = ${_num(theta)}$u',
        decimalApproxLatex: 'r \\approx ${_num(r)},\\; \\theta \\approx ${_num(theta)}$u',
      ),
      r,
      theta,
    );
  }

  /// `Rec(r, θ)` -> coordenadas `x`, `y` (θ en la unidad angular activa).
  static PolRecResult rec(Rational r, double theta, AngleUnit unit) {
    final rad = _toDegrees(theta, unit) * math.pi / 180.0;
    final rv = r.toDouble();
    var x = rv * math.cos(rad);
    var y = rv * math.sin(rad);
    if (x.abs() < 1e-12) x = 0;
    if (y.abs() < 1e-12) y = 0;
    final u = _unitSymbol(unit);
    final rl = r.toLatex();
    final tl = _num(theta);
    final steps = [
      MathStep(
        index: 1,
        shortTitle: 'Coordenadas polares',
        latexExpression: '\\mathrm{Rec}($rl,\\,$tl$u)',
        pedagogicalNote: 'Rec convierte el módulo r y el ángulo θ en coordenadas (x, y).',
      ),
      MathStep(
        index: 2,
        shortTitle: 'Coordenada x',
        latexExpression: 'x = r\\cdot\\cos\\theta = $rl\\cdot\\cos($tl$u) = ${_num(x)}',
        pedagogicalNote: 'La abscisa es el módulo por el coseno del ángulo.',
      ),
      MathStep(
        index: 3,
        shortTitle: 'Coordenada y',
        latexExpression: 'y = r\\cdot\\sin\\theta = $rl\\cdot\\sin($tl$u) = ${_num(y)}',
        pedagogicalNote: 'La ordenada es el módulo por el seno del ángulo.',
      ),
    ];
    return PolRecResult(
      StepByStepResolution(
        originalInputLatex: '\\mathrm{Rec}($rl,\\,$tl$u)',
        steps: steps,
        exactResultLatex: 'x = ${_num(x)},\\; y = ${_num(y)}',
        decimalApproxLatex: 'x \\approx ${_num(x)},\\; y \\approx ${_num(y)}',
      ),
      x,
      y,
    );
  }
}
