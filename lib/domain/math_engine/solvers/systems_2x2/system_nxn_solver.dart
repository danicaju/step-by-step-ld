import '../../core/rational.dart';
import '../../models/linear_system_models.dart';
import '../../models/step_resolution.dart';
import 'system_unordered_parser.dart';

class SystemNxnSolver {
  /// Resuelve un sistema de N ecuaciones lineales (N = 2, 3 o 4) con coeficientes exactos [Rational].
  static StepByStepResolution solveNxN({
    required List<List<Rational>> augmentedRows,
    required StepByStepResolution Function({
      required int a1,
      required int b1,
      required int c1,
      required int a2,
      required int b2,
      required int c2,
      SystemResolutionMethod method,
    }) solve2x2,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final n = augmentedRows.length;
    if (n < 2 || n > 4) {
      throw const FormatException('El sistema admite de 2 a 4 ecuaciones.');
    }
    for (final r in augmentedRows) {
      if (r.length != n + 1) {
        throw FormatException('Cada fila debe tener ${n + 1} coeficientes.');
      }
    }

    if (n == 2) {
      final a1 = augmentedRows[0][0].toDouble().round();
      final b1 = augmentedRows[0][1].toDouble().round();
      final c1 = augmentedRows[0][2].toDouble().round();
      final a2 = augmentedRows[1][0].toDouble().round();
      final b2 = augmentedRows[1][1].toDouble().round();
      final c2 = augmentedRows[1][2].toDouble().round();
      return solve2x2(
        a1: a1,
        b1: b1,
        c1: c1,
        a2: a2,
        b2: b2,
        c2: c2,
        method: method,
      );
    }

    final varNames = const ['x', 'y', 'z', 'w'].sublist(0, n);
    final eqLines = [
      for (final r in augmentedRows)
        formatRowLatex(r.sublist(0, n), r[n], varNames),
    ];
    final originalInputLatex = '\\begin{cases} ${eqLines.join(" \\\\ ")} \\end{cases}';

    final m = [
      for (final r in augmentedRows) [for (final v in r) v],
    ];
    final steps = <MathStep>[];

    steps.add(
      MathStep(
        index: 1,
        shortTitle: 'Gauss: sistema de $n ecuaciones con $n incógnitas',
        latexExpression: originalInputLatex,
        pedagogicalNote:
            'Planteamos el sistema con todas las incognitas (${varNames.join(", ")}) ordenadas a la izquierda y los terminos independientes a la derecha.',
      ),
    );

    // Eliminación progresiva
    for (int k = 0; k < n - 1; k++) {
      if (m[k][k].isZero) {
        int swapRow = -1;
        for (int r = k + 1; r < n; r++) {
          if (!m[r][k].isZero) {
            swapRow = r;
            break;
          }
        }
        if (swapRow != -1) {
          final tmp = m[k];
          m[k] = m[swapRow];
          m[swapRow] = tmp;
        }
      }

      final pivot = m[k][k];
      if (pivot.isZero) continue;

      final elimNotes = <String>[];
      for (int r = k + 1; r < n; r++) {
        final target = m[r][k];
        if (!target.isZero) {
          final factor = target / pivot;
          for (int c = k; c <= n; c++) {
            m[r][c] = m[r][c] - (factor * m[k][c]);
          }
          elimNotes.add('E_{${r + 1}} \\leftarrow E_{${r + 1}} - (${factor.toLatex()}) E_{${k + 1}}');
        }
      }

      if (elimNotes.isNotEmpty) {
        final remainingEqs = [
          for (int r = 0; r < n; r++)
            formatRowLatex(m[r].sublist(0, n), m[r][n], varNames),
        ];
        steps.add(
          MathStep(
            index: steps.length + 1,
            shortTitle: 'Gauss: eliminar la incógnita ${varNames[k]} en las ecuaciones inferiores',
            latexExpression:
                '${elimNotes.join(", ")} \\implies \\begin{cases} ${remainingEqs.join(" \\\\ ")} \\end{cases}',
            pedagogicalNote:
                'Combinamos linealmente las ecuaciones para anular la incognita ${varNames[k]} por debajo del pivote.',
          ),
        );
      }
    }

    // Comprobación de compatibilidad
    if (m[n - 1][n - 1].isZero) {
      if (m[n - 1][n].isZero) {
        return StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Infinitas soluciones (S.C.I.)}',
          decimalApproxLatex: r'\text{Infinitas}',
        );
      } else {
        return StepByStepResolution(
          originalInputLatex: originalInputLatex,
          steps: steps,
          exactResultLatex: r'\text{Sin solucion (S.I.)}',
          decimalApproxLatex: r'\text{Sin sol}',
        );
      }
    }

    // Sustitución hacia atrás
    final solution = List<Rational>.filled(n, Rational(0));
    final backSubNotes = <String>[];

    for (int r = n - 1; r >= 0; r--) {
      var sum = m[r][n];
      for (int c = r + 1; c < n; c++) {
        sum = sum - (m[r][c] * solution[c]);
      }
      solution[r] = sum / m[r][r];
      backSubNotes.add('${varNames[r]} = ${solution[r].toLatex()}');
    }

    steps.add(
      MathStep(
        index: steps.length + 1,
        shortTitle: 'Gauss: sustitución hacia atrás',
        latexExpression: backSubNotes.join(', \\quad '),
        pedagogicalNote:
            'Despejamos desde la ultima ecuacion triangularizada y sustituimos progresivamente hacia arriba para hallar cada incognita.',
      ),
    );

    final exactRes = [
      for (int i = 0; i < n; i++) '${varNames[i]} = ${solution[i].toLatex()}',
    ].join(', \\; ');

    return StepByStepResolution(
      originalInputLatex: originalInputLatex,
      steps: steps,
      exactResultLatex: exactRes,
      decimalApproxLatex: [
        for (int i = 0; i < n; i++) '${varNames[i]} \\approx ${solution[i].toDecimalLatex()}',
      ].join(', \\; '),
    );
  }

  static String formatRowLatex(List<Rational> coeffs, Rational constant, List<String> vars) {
    final buffer = StringBuffer();
    bool first = true;
    for (int i = 0; i < coeffs.length; i++) {
      final c = coeffs[i];
      if (c.isZero) continue;
      final v = vars[i];
      if (first) {
        if (c.isNegative) buffer.write('-');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
        first = false;
      } else {
        buffer.write(c.isNegative ? ' - ' : ' + ');
        final absC = c.abs();
        if (absC != Rational(1)) buffer.write(absC.toLatex());
        buffer.write(v);
      }
    }
    if (first) buffer.write('0');
    buffer.write(' = ${constant.toLatex()}');
    return buffer.toString();
  }

  /// Resuelve un conjunto de ecuaciones en texto libre con entrada desordenada.
  static StepByStepResolution solveFromEquations(
    List<String> rawEquations, {
    required StepByStepResolution Function({
      required List<List<Rational>> augmentedRows,
      SystemResolutionMethod method,
    }) solveNxN,
    SystemResolutionMethod method = SystemResolutionMethod.sustitucion,
  }) {
    final dim = rawEquations.length;
    final varNames = const ['x', 'y', 'z', 'w'].sublist(0, dim);
    final parsed = rawEquations.map((e) => SystemUnorderedParser.parse(e, vars: varNames)).toList();

    final augmentedRows = <List<Rational>>[];
    for (final p in parsed) {
      final row = <Rational>[];
      for (final v in varNames) {
        row.add(p.coefficients[v] ?? Rational(0));
      }
      row.add(p.constant);
      augmentedRows.add(row);
    }

    final isAnyDisordered = parsed.any((p) => p.originalRaw.trim() != p.orderedLatex.trim());
    final baseRes = solveNxN(augmentedRows: augmentedRows, method: method);
    if (!isAnyDisordered) return baseRes;

    final reorderStep = MathStep(
      index: 1,
      shortTitle: 'Reordenacion y agrupacion de terminos semejantes',
      latexExpression: '\\begin{cases} ${parsed.map((p) => p.orderedLatex).join(" \\\\ ")} \\end{cases}',
      pedagogicalNote:
          'Agrupamos las incognitas (${varNames.join(", ")}) en el primer miembro y reducimos los terminos independientes en el segundo miembro antes de aplicar el metodo de resolucion.',
    );

    final renumberedSteps = [
      reorderStep,
      for (int i = 0; i < baseRes.steps.length; i++)
        MathStep(
          index: i + 2,
          shortTitle: baseRes.steps[i].shortTitle,
          latexExpression: baseRes.steps[i].latexExpression,
          pedagogicalNote: baseRes.steps[i].pedagogicalNote,
          warningTrick: baseRes.steps[i].warningTrick,
        ),
    ];

    return StepByStepResolution(
      originalInputLatex: '\\begin{cases} ${rawEquations.join(" \\\\ ")} \\end{cases}',
      steps: renumberedSteps,
      exactResultLatex: baseRes.exactResultLatex,
      decimalApproxLatex: baseRes.decimalApproxLatex,
    );
  }
}
