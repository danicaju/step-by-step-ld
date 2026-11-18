import 'package:flutter/material.dart';

import '../../../domain/math_engine/core/rational.dart';
import '../../../domain/math_engine/polynomials/spanish_box_division_solver.dart';
import '../../../domain/math_engine/solvers/equations/eq_poly.dart';

/// Caja espanola: dividendo completo a la izquierda, divisor dentro de la caja a la
/// derecha, cociente debajo y cada resta parcial alineada por grados hasta el resto.
class SpanishBoxDivisionView extends StatelessWidget {
  final BoxDivisionResult result;
  final bool isOledDark;

  const SpanishBoxDivisionView({super.key, required this.result, this.isOledDark = false});

  static const Color _ink = Color(0xFF1A2530);
  static const Color _sub = Color(0xFF8A5A12); // ambar oscuro: terminos que se restan
  static const double _cell = 46;
  static const double _rowH = 22;

  static const _sup = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};

  /// `+3x²`, `−x`, `+5`; cadena vacia si [blankZero] y el coeficiente es 0.
  static String termText(Rational c, int k, {bool blankZero = true}) {
    if (c.isZero && blankZero) return '';
    final abs = c.abs();
    final num = abs.isInteger ? '${abs.numerator}' : '${abs.numerator}/${abs.denominator}';
    final coef = (abs == Rational(1) && k > 0) ? '' : num;
    final x = k == 0 ? '' : (k == 1 ? 'x' : 'x${'$k'.split('').map((d) => _sup[d]).join()}');
    return '${c.isNegative ? '−' : '+'}$coef$x';
  }

  /// Filas de la zona izquierda: (poliniomio, resaltado, linea encima).
  List<({Poly poly, bool sub, bool line, bool zeros})> rows() => [
        (poly: result.dividend, sub: false, line: false, zeros: true),
        for (final s in result.steps) ...[
          (poly: PolyOps.neg(s.subtrahend), sub: true, line: false, zeros: false),
          (poly: s.remainder, sub: false, line: true, zeros: false),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final top = result.topDegree;
    final fg = isOledDark ? const Color(0xFFE8F3EE) : _ink;
    TextStyle st(bool sub) => TextStyle(
          color: sub ? _sub : fg,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        );

    Widget rowOf(Poly p, {required bool sub, required bool zeros, required bool line}) => Container(
          height: _rowH,
          decoration: line ? BoxDecoration(border: Border(top: BorderSide(color: fg, width: 1.2))) : null,
          child: Row(children: [
            for (var k = top; k >= 0; k--)
              SizedBox(
                width: _cell,
                child: Text(
                  termText(PolyOps.coeff(p, k), k, blankZero: !zeros),
                  textAlign: TextAlign.right,
                  style: st(sub),
                ),
              ),
          ]),
        );

    final left = Column(
      key: const Key('box_left'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows()) rowOf(r.poly, sub: r.sub, zeros: r.zeros, line: r.line),
        if (result.steps.isEmpty) SizedBox(height: _rowH, child: Text('(grado menor: C = 0)', style: st(false))),
      ],
    );

    String polyText(Poly p, int deg) {
      final b = StringBuffer();
      for (var k = deg; k >= 0; k--) {
        final c = PolyOps.coeff(p, k);
        if (c.isZero) continue;
        b.write(termText(c, k));
      }
      var s = b.toString();
      if (s.startsWith('+')) s = s.substring(1);
      return s.isEmpty ? '0' : s;
    }

    final dq = PolyOps.degree(result.divisor);
    final divisorText = polyText(result.divisor, dq);
    final quotientText = result.quotient.isEmpty ? '0' : polyText(result.quotient, PolyOps.degree(result.quotient));

    final right = Column(
      key: const Key('box_right'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _rowH,
          padding: const EdgeInsets.only(left: 8, right: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: fg, width: 1.6), bottom: BorderSide(color: fg, width: 1.6)),
          ),
          alignment: Alignment.centerLeft,
          child: Text(divisorText, key: const Key('box_divisor'), style: st(false)),
        ),
        Container(
          height: _rowH,
          padding: const EdgeInsets.only(left: 8),
          alignment: Alignment.centerLeft,
          child: Text(quotientText, key: const Key('box_quotient'), style: st(false).copyWith(color: const Color(0xFFB4412F))),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'R = ${result.remainder.isEmpty ? '0' : polyText(result.remainder, PolyOps.degree(result.remainder))}',
            key: const Key('box_remainder'),
            style: st(false),
          ),
        ),
      ],
    );

    return ClipRRect(
      key: const Key('box_division_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: const Color(0xFFC8D6CD),
        padding: const EdgeInsets.all(6),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [left, right]),
        ),
      ),
    );
  }
}
