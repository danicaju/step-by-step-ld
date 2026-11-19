import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../domain/math_engine/core/rational.dart';
import '../../../domain/math_engine/polynomials/spanish_box_division_solver.dart';
import '../../../domain/math_engine/solvers/equations/eq_poly.dart';

/// Caja espanola: dividendo completo a la izquierda, divisor dentro de la caja a la
/// derecha, cociente debajo y cada resta parcial alineada por grados hasta el resto.
///
/// Con [stage] (indice del paso, base 0) el dibujo se va construyendo como en la pizarra:
/// 0 = caja con dividendo y divisor; `1 + 2i` = termino i del cociente; `2 + 2i` = producto
/// cambiado de signo y resto parcial i; el ultimo = cociente y resto. Sin [stage] se ve completo.
/// El hueco de lo aun no dibujado se reserva (transparente) para que la caja no cambie de tamano.
///
/// El texto mide siempre [fontSize] (13 px): nada se escala. Si la caja no cabe en el espacio de
/// la LCD se desplaza (arrastre o rueda) en los dos ejes y sigue automaticamente el paso en curso.
class SpanishBoxDivisionView extends StatefulWidget {
  final BoxDivisionResult result;
  final bool isOledDark;
  final int? stage;

  const SpanishBoxDivisionView({super.key, required this.result, this.isOledDark = false, this.stage});

  static const Color _ink = Color(0xFF1A2530);
  static const Color _sub = Color(0xFF8A5A12); // ambar oscuro: terminos que se restan
  static const Color _quot = Color(0xFFB4412F);
  static const Color _hi = Color(0x55E5A93C); // resalte del paso en curso
  static const double _cell = 46;
  static const double _rowH = 20;
  static const double _pad = 6;

  /// Tamano de letra minimo y fijo de la caja.
  static const double fontSize = 13;

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

  /// Terminos de un polinomio con signo separado (`x²`, `+ 3x`, `− 1`); el primero sin `+`.
  static List<String> spacedTerms(Poly p) {
    final out = <String>[];
    for (var k = PolyOps.degree(p); k >= 0; k--) {
      final c = PolyOps.coeff(p, k);
      if (c.isZero) continue;
      final t = termText(c, k);
      if (out.isEmpty) {
        out.add(t.startsWith('+') ? t.substring(1) : t);
      } else {
        out.add('${t[0]} ${t.substring(1)}');
      }
    }
    return out.isEmpty ? const ['0'] : out;
  }

  /// Filas de la zona izquierda: (polinomio, resaltado, linea encima).
  List<({Poly poly, bool sub, bool line, bool zeros})> rows() => [
        (poly: result.dividend, sub: false, line: false, zeros: true),
        for (final s in result.steps) ...[
          (poly: PolyOps.neg(s.subtrahend), sub: true, line: false, zeros: false),
          (poly: s.remainder, sub: false, line: true, zeros: false),
        ],
      ];

  @override
  State<SpanishBoxDivisionView> createState() => _SpanishBoxDivisionViewState();

  static String _quotTerm(BoxStep step, bool first) {
    final t = termText(step.coeff, step.degree);
    if (first) return t.startsWith('+') ? t.substring(1) : t;
    return '${t[0]} ${t.substring(1)}';
  }
}

class _SpanishBoxDivisionViewState extends State<SpanishBoxDivisionView> {
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(animate: false));
  }

  @override
  void didUpdateWidget(covariant SpanishBoxDivisionView old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage || old.result != widget.result) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow(animate: true));
    }
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  int get _last => 2 * widget.result.steps.length + 1;
  int get _stage => (widget.stage ?? _last).clamp(0, _last);

  /// Fila (de la zona izquierda) que protagoniza el paso en curso.
  int get _activeRow {
    final s = _stage;
    if (s >= _last) return 2 * widget.result.steps.length;
    if (s == 0) return 0;
    final cur = s.isOdd ? (s - 1) ~/ 2 : (s - 2) ~/ 2;
    if (s.isOdd) return cur == 0 ? 0 : 2 * cur; // resto que se divide
    return 2 + 2 * cur; // nuevo resto parcial
  }

  /// Lleva la fila activa al centro vertical; en horizontal: derecha al dividir y al final.
  void _follow({required bool animate}) {
    if (!mounted) return;
    void go(ScrollController c, double target) {
      if (!c.hasClients) return;
      final t = target.clamp(0.0, c.position.maxScrollExtent);
      if (animate) {
        c.animateTo(t, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      } else {
        c.jumpTo(t);
      }
    }

    if (_vCtrl.hasClients) {
      // Al final se ve arriba a la derecha: divisor, cociente y resto.
      final top = SpanishBoxDivisionView._pad + _activeRow * SpanishBoxDivisionView._rowH;
      go(_vCtrl, _stage >= _last ? 0 : top + SpanishBoxDivisionView._rowH / 2 - _vCtrl.position.viewportDimension / 2);
    }
    final s = _stage;
    final toEnd = s >= _last || (s > 0 && s.isOdd);
    if (_hCtrl.hasClients) go(_hCtrl, toEnd ? _hCtrl.position.maxScrollExtent : 0);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isOledDark = widget.isOledDark;
    final allRows = widget.rows();
    final n = result.steps.length;
    final last = _last;
    final s = _stage;
    final finalStage = s >= last;
    // Lo ya dibujado en este paso.
    final shownQuot = finalStage ? n : (s == 0 ? 0 : (s + 1) ~/ 2);
    final shownSteps = finalStage ? n : s ~/ 2;
    // Paso en curso: dividir (s impar) o multiplicar y restar (s par > 0).
    final dividing = !finalStage && s.isOdd;
    final subtracting = !finalStage && s > 0 && s.isEven;
    final cur = dividing ? (s - 1) ~/ 2 : (subtracting ? (s - 2) ~/ 2 : -1);

    final top = result.topDegree;
    final fg = isOledDark ? const Color(0xFFE8F3EE) : SpanishBoxDivisionView._ink;
    const cell = SpanishBoxDivisionView._cell;
    const rowH = SpanishBoxDivisionView._rowH;
    const hi = SpanishBoxDivisionView._hi;
    TextStyle st(Color c) => TextStyle(
        color: c, fontSize: SpanishBoxDivisionView.fontSize, fontWeight: FontWeight.w800, fontFamily: 'monospace');

    Widget rowOf(int r, Poly p, {required bool sub, required bool zeros, required bool line}) {
      // r = 0 dividendo; r = 1 + 2j resta del paso j; r = 2 + 2j resto parcial j.
      final visible = r == 0 || (r - 1) ~/ 2 < shownSteps;
      final rowStep = r == 0 ? -1 : (r - 1) ~/ 2;
      final lead = dividing && cur >= 0 && ((cur == 0 && r == 0) || (cur > 0 && r == 2 * cur));
      final hiRow = subtracting && r > 0 && rowStep == cur;
      final leadDeg = lead ? PolyOps.degree(p) : -1;
      return Opacity(
        key: Key('box_row_$r'),
        opacity: visible ? 1 : 0,
        child: Container(
          height: rowH,
          decoration: line && visible ? BoxDecoration(border: Border(top: BorderSide(color: fg, width: 1.2))) : null,
          child: Row(children: [
            for (var k = top; k >= 0; k--)
              Container(
                width: cell,
                alignment: Alignment.centerRight,
                color: (hiRow && !PolyOps.coeff(p, k).isZero) || k == leadDeg ? hi : null,
                child: Text(
                  (line && p.isEmpty && k == 0)
                      ? '0'
                      : SpanishBoxDivisionView.termText(PolyOps.coeff(p, k), k, blankZero: !zeros),
                  textAlign: TextAlign.right,
                  style: st(sub ? SpanishBoxDivisionView._sub : fg),
                ),
              ),
          ]),
        ),
      );
    }

    final left = Column(
      key: const Key('box_left'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < allRows.length; r++)
          rowOf(r, allRows[r].poly, sub: allRows[r].sub, zeros: allRows[r].zeros, line: allRows[r].line),
        if (result.steps.isEmpty) SizedBox(height: rowH, child: Text('(grado menor: C = 0)', style: st(fg))),
      ],
    );

    Widget termRow(List<Widget> terms, {Key? key}) =>
        Row(key: key, mainAxisSize: MainAxisSize.min, children: [for (final t in terms) ...[t, const SizedBox(width: 5)]]);

    final divisorTerms = SpanishBoxDivisionView.spacedTerms(result.divisor);
    final divisor = termRow(key: const Key('box_divisor'), [
      for (var i = 0; i < divisorTerms.length; i++)
        Container(color: dividing && i == 0 ? hi : null, child: Text(divisorTerms[i], style: st(fg))),
    ]);

    final quotTerms = [for (var i = 0; i < n; i++) SpanishBoxDivisionView._quotTerm(result.steps[i], i == 0)];
    final quotient = result.steps.isEmpty
        ? Text('0', key: const Key('box_quotient'), style: st(SpanishBoxDivisionView._quot))
        : termRow(key: const Key('box_quotient'), [
            for (var i = 0; i < n; i++)
              Opacity(
                opacity: i < shownQuot ? 1 : 0,
                child: Container(
                  color: (dividing && i == cur) || finalStage ? hi : null,
                  child: Text(quotTerms[i], style: st(SpanishBoxDivisionView._quot)),
                ),
              ),
          ]);

    final remTerms = SpanishBoxDivisionView.spacedTerms(result.remainder);
    final right = Column(
      key: const Key('box_right'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: rowH,
          padding: const EdgeInsets.only(left: 8, right: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: fg, width: 1.6), bottom: BorderSide(color: fg, width: 1.6)),
          ),
          alignment: Alignment.centerLeft,
          child: divisor,
        ),
        Container(height: rowH, padding: const EdgeInsets.only(left: 8), alignment: Alignment.centerLeft, child: quotient),
        const SizedBox(height: 4),
        Opacity(
          opacity: finalStage ? 1 : 0,
          child: Container(
            color: finalStage ? hi : null,
            margin: const EdgeInsets.only(left: 8),
            child: Text(
              'R = ${result.remainder.isEmpty ? '0' : remTerms.join(' ')}',
              key: const Key('box_remainder'),
              style: st(fg),
            ),
          ),
        ),
      ],
    );

    final block = Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [left, right]);

    return ClipRRect(
      key: const Key('box_division_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: const Color(0xFFC8D6CD),
        child: LayoutBuilder(
          builder: (context, box) => ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
              physics: const ClampingScrollPhysics(),
              scrollbars: false,
            ),
            child: Scrollbar(
              controller: _vCtrl,
              thickness: 3,
              notificationPredicate: (n) => n.depth == 1,
              child: Scrollbar(
                controller: _hCtrl,
                thickness: 3,
                child: SingleChildScrollView(
                  key: const Key('box_scroll_h'),
                  controller: _hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    key: const Key('box_scroll_v'),
                    controller: _vCtrl,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: box.maxWidth.isFinite ? box.maxWidth : 0,
                        minHeight: box.maxHeight.isFinite ? box.maxHeight : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(SpanishBoxDivisionView._pad),
                        child: Center(child: block),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
