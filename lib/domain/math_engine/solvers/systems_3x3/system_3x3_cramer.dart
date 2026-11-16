import '../../core/rational.dart';
import '../../models/step_resolution.dart';
import '../../models/system_3x3_models.dart';
import '../matrix_solver.dart';
import 'system_3x3_formatter.dart';
import 'system_3x3_gauss.dart';

class System3x3CramerSolver {
  static System3x3Result solveByCramer(
    List<List<Rational>> rows,
    String originalInputLatex,
  ) {
    final matA = RationalMatrix.fromRationals([
      [rows[0][0], rows[0][1], rows[0][2]],
      [rows[1][0], rows[1][1], rows[1][2]],
      [rows[2][0], rows[2][1], rows[2][2]],
    ]);
    final det = matA.determinantValue();

    final List<MathStep> steps = [];
    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Determinante del sistema (Δ = |A|)',
        latexExpression: '\\Delta = ${matA.toDeterminantLatex()} = ${det.toLatex()}',
        pedagogicalNote:
            'Calculamos el determinante de la matriz de coeficientes A por la Regla de Sarrus. Si Δ ≠ 0, podemos aplicar Cramer para hallar solución única.',
      ),
    );

    if (det.isZero) {
      // Clasificamos internamente mediante rangos de Gauss para no confundir SCI y SI
      final echelonCopy = [for (final r in rows) [for (final v in r) v]];
      System3x3GaussSolver.reduceToEchelonSilent(echelonCopy);
      final (:rankA, :rankAb) = System3x3GaussSolver.computeRanksFromEchelon(echelonCopy);
      final isSi = rankA < rankAb;

      final matX = replaceCol(matA, 0, [rows[0][3], rows[1][3], rows[2][3]]);
      final matY = replaceCol(matA, 1, [rows[0][3], rows[1][3], rows[2][3]]);
      final matZ = replaceCol(matA, 2, [rows[0][3], rows[1][3], rows[2][3]]);
      final dx = matX.determinantValue();
      final dy = matY.determinantValue();
      final dz = matZ.determinantValue();

      steps.add(
        MathStep(
          index: 2,
          shortTitle: isSi
              ? 'Δ = 0 → Cramer no aplicable (Sistema Incompatible)'
              : 'Δ = 0 → Cramer no aplicable (Sistema Compatible Indeterminado)',
          latexExpression:
              '\\Delta = 0, \\; \\Delta_x = ${dx.toLatex()}, \\; \\Delta_y = ${dy.toLatex()}, \\; \\Delta_z = ${dz.toLatex()} \\implies '
              '\\text{rg}(A) = $rankA${isSi ? ' < ' : ' = '}\\text{rg}(A^*) = $rankAb \\implies ${isSi ? r'\text{S.I.}' : r'\text{S.C.I.}'}',
          pedagogicalNote: isSi
              ? 'Al ser Δ = 0 la Regla de Cramer no se puede aplicar (no se puede dividir por cero). Al comprobar rangos por Rouché-Frobenius resulta rg(A) < rg(A*): Sistema Incompatible (sin solución).'
              : 'Al ser Δ = 0 no existe solución única. Mediante rangos por Rouché-Frobenius se comprueba rg(A) = rg(A*) = $rankA < 3: Sistema Compatible Indeterminado (infinitas soluciones).',
          warningTrick:
              'Que Δ = Δx = Δy = Δz = 0 no garantiza por sí solo que el sistema sea S.C.I. (podrían ser planos paralelos o secantes 2 a 2). Comprueba siempre rg(A) y rg(A*) mediante Gauss.',
        ),
      );

      return System3x3Result(
        classification: isSi ? System3x3Classification.si : System3x3Classification.sci,
        rankA: rankA,
        rankAugmented: rankAb,
        x: null,
        y: null,
        z: null,
        resolution: StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: isSi
              ? r'\text{Sin solucion (S.I.)}'
              : r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: isSi ? r'\text{Sin sol}' : r'\text{Infinitas}',
        ),
      );
    }

    final rhs = [rows[0][3], rows[1][3], rows[2][3]];
    final matX = replaceCol(matA, 0, rhs);
    final matY = replaceCol(matA, 1, rhs);
    final matZ = replaceCol(matA, 2, rhs);

    final dx = matX.determinantValue();
    final dy = matY.determinantValue();
    final dz = matZ.determinantValue();

    final x = dx / det;
    final y = dy / det;
    final z = dz / det;

    steps.add(
      MathStep(
        index: 2,
        shortTitle: 'Cálculo de Δx y valor de x',
        latexExpression:
            '\\Delta_x = ${matX.toDeterminantLatex()} = ${dx.toLatex()} \\implies '
            'x = \\frac{\\Delta_x}{\\Delta} = ${System3x3Formatter.fractionLatex(dx, det, x)}',
        pedagogicalNote:
            'Sustituimos la 1.ª columna de A (coeficientes de x) por la columna de términos independientes B y dividimos Δx entre Δ = ${det.toLatex()}.',
      ),
    );

    steps.add(
      MathStep(
        index: 3,
        shortTitle: 'Cálculo de Δy y valor de y',
        latexExpression:
            '\\Delta_y = ${matY.toDeterminantLatex()} = ${dy.toLatex()} \\implies '
            'y = \\frac{\\Delta_y}{\\Delta} = ${System3x3Formatter.fractionLatex(dy, det, y)}',
        pedagogicalNote:
            'Sustituimos la 2.ª columna de A (coeficientes de y) por la columna B y dividimos Δy entre Δ = ${det.toLatex()}.',
      ),
    );

    steps.add(
      MathStep(
        index: 4,
        shortTitle: 'Cálculo de Δz y solución final (x, y, z)',
        latexExpression:
            '\\Delta_z = ${matZ.toDeterminantLatex()} = ${dz.toLatex()} \\implies '
            'z = \\frac{\\Delta_z}{\\Delta} = ${System3x3Formatter.fractionLatex(dz, det, z)}',
        pedagogicalNote:
            'Sustituimos la 3.ª columna de A (coeficientes de z) por la columna B y dividimos Δz entre Δ = ${det.toLatex()}.',
      ),
    );

    final exactLatex = 'x = ${x.toLatex()}, \\; y = ${y.toLatex()}, \\; z = ${z.toLatex()}';
    final decimalLatex = (x.isInteger && y.isInteger && z.isInteger)
        ? ''
        : 'x \\approx ${x.toDecimalLatex()}, \\; y \\approx ${y.toDecimalLatex()}, \\; z \\approx ${z.toDecimalLatex()}';

    return System3x3Result(
      classification: System3x3Classification.scd,
      rankA: 3,
      rankAugmented: 3,
      x: x,
      y: y,
      z: z,
      resolution: StepByStepResolution(
        originalInputLatex: originalInputLatex,
        steps: steps,
        exactResultLatex: exactLatex,
        decimalApproxLatex: decimalLatex,
      ),
    );
  }

  static RationalMatrix replaceCol(
    RationalMatrix mat,
    int colIndex,
    List<Rational> colValues,
  ) {
    return RationalMatrix.fromRationals([
      for (int r = 0; r < 3; r++)
        [
          for (int c = 0; c < 3; c++) c == colIndex ? colValues[r] : mat.at(r, c),
        ],
    ]);
  }
}
