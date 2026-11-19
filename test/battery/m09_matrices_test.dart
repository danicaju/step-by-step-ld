import 'package:flutter_test/flutter_test.dart';

import '../support/exercise_dsl.dart';

/// Determinante exacto por Laplace (referencia independiente del motor).
int _det(List<List<int>> m) {
  if (m.length == 1) return m[0][0];
  var d = 0;
  for (var c = 0; c < m.length; c++) {
    final minor = [
      for (var r = 1; r < m.length; r++) [for (var k = 0; k < m.length; k++) if (k != c) m[r][k]],
    ];
    d += (c.isEven ? 1 : -1) * m[0][c] * _det(minor);
  }
  return d;
}

void main() {
  group('M9 Matrices', () {
    bothSizes('1. producto rectangular A(2x3)·B(3x2) = [[2,-1],[2,-2]]', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_multiply pick:hdr_matrix_rows:matrix_r_2 pick:hdr_matrix_cols:matrix_c_3 '
        '1 > 2 > 0 > - 1 > 3 > 1 tabB pick:hdr_matrix_rows:matrix_r_3 pick:hdr_matrix_cols:matrix_c_2 2 > 1 > 0 > - 1 > 4 > 2 =',
      );
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'2&-1\\2&-2'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2a. det 3x3 por Sarrus = 32 (el banco decia 30)', (t) async {
      await seq(t, 'mode:9 pick:hdr_matrix_op:matrix_op_determinant 2 > - 1 > 3 > 0 > 4 > 1 > - 2 > 5 > 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), r'|A|=32');
      expect(_det([[2, -1, 3], [0, 4, 1], [-2, 5, 2]]), 32);
      expect(lessonText(r), contains('Sarrus'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('2b. det 4x4 por adjuntos coincide con Laplace', (t) async {
      const m = [
        [1, 2, 0, 1],
        [0, 1, 3, 2],
        [2, 0, 1, 1],
        [1, 1, 0, 2],
      ];
      final script = StringBuffer('mode:9 pick:hdr_matrix_op:matrix_op_determinant pick:hdr_matrix_rows:matrix_r_4 pick:hdr_matrix_cols:matrix_c_4 ');
      for (final row in m) {
        for (final v in row) {
          script.write('${v.toString().split('').map((c) => c == '-' ? '-' : c).join(' ')} > ');
        }
      }
      await seq(t, '$script ='.replaceFirst(RegExp(r'> =$'), '='));
      final r = res(t);
      expect(norm(r.exactResultLatex), '|A|=${_det(m)}');
      expect(lessonText(r).toLowerCase(), contains('laplace'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3a. inversa de [[3,5],[1,2]] = [[2,-5],[-1,3]]', (t) async {
      await seq(t, 'mode:9 pick:hdr_matrix_op:matrix_op_inverse pick:hdr_matrix_rows:matrix_r_2 pick:hdr_matrix_cols:matrix_c_2 3 > 5 > 1 > 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'2&-5\\-1&3'));
      expectLesson(r, minSteps: 3);
    });

    bothSizes('3b. [[2,4],[1,2]] es singular: det = 0, sin inversa', (t) async {
      await seq(t, 'mode:9 pick:hdr_matrix_op:matrix_op_inverse pick:hdr_matrix_rows:matrix_r_2 pick:hdr_matrix_cols:matrix_c_2 2 > 4 > 1 > 2 =');
      final r = res(t);
      expect(norm(r.exactResultLatex), contains(r'\nexistsA^{-1}'));
      expectLesson(r, minSteps: 1);
    });

    bothSizes('4. A·X = B (3x3 por 3x1): X = (1, 2, 3)', (t) async {
      await seq(
        t,
        'mode:9 pick:hdr_matrix_op:matrix_op_cramer 1 > 1 > 1 > 2 > - 1 > 1 > 1 > 2 > - 1 '
        'tabB pick:hdr_matrix_cols:matrix_c_1 6 > 3 > 2 =',
      );
      final r = res(t);
      final text = norm(r.exactResultLatex);
      expect(text, contains('x=1'));
      expect(text, contains('y=2'));
      expect(text, contains('z=3'));
      expectLesson(r, minSteps: 3);
    });
  });
}
