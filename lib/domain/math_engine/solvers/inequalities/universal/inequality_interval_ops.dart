import '../../../models/inequality_models.dart';

/// Operaciones de conjuntos sobre listas de intervalos de la recta real
/// (union, interseccion, complementario y ensamblado desde puntos y tramos).
abstract final class IntervalOps {
  static const double _eps = 1e-9;

  static bool _same(double a, double b) =>
      a == b || (a.isFinite && b.isFinite && (a - b).abs() <= _eps * (1 + a.abs()));

  /// Interseccion de dos listas (respeta extremos abiertos / cerrados y puntos aislados).
  static List<InequalityInterval> intersect(List<InequalityInterval> a, List<InequalityInterval> b) {
    final out = <InequalityInterval>[];
    for (final x in a) {
      for (final y in b) {
        double lo;
        bool loIn;
        String? loLabel;
        if (_same(x.start, y.start)) {
          lo = x.start;
          loIn = x.includeStart && y.includeStart;
          loLabel = x.startLabel ?? y.startLabel;
        } else if (x.start > y.start) {
          lo = x.start;
          loIn = x.includeStart;
          loLabel = x.startLabel;
        } else {
          lo = y.start;
          loIn = y.includeStart;
          loLabel = y.startLabel;
        }
        double hi;
        bool hiIn;
        String? hiLabel;
        if (_same(x.end, y.end)) {
          hi = x.end;
          hiIn = x.includeEnd && y.includeEnd;
          hiLabel = x.endLabel ?? y.endLabel;
        } else if (x.end < y.end) {
          hi = x.end;
          hiIn = x.includeEnd;
          hiLabel = x.endLabel;
        } else {
          hi = y.end;
          hiIn = y.includeEnd;
          hiLabel = y.endLabel;
        }
        final ok = lo < hi && !_same(lo, hi) || (_same(lo, hi) && loIn && hiIn && lo.isFinite);
        if (!ok) continue;
        out.add(InequalityInterval(
          start: lo,
          end: hi,
          includeStart: lo.isFinite && loIn,
          includeEnd: hi.isFinite && hiIn,
          startLabel: loLabel,
          endLabel: hiLabel,
        ));
      }
    }
    return union(out);
  }

  /// Union ordenada, fusionando intervalos que se solapan o se tocan.
  static List<InequalityInterval> union(List<InequalityInterval> list) {
    final items = [...list]..sort((p, q) {
        final c = p.start.compareTo(q.start);
        return c != 0 ? c : (p.includeStart == q.includeStart ? 0 : (p.includeStart ? -1 : 1));
      });
    final out = <InequalityInterval>[];
    for (final cur in items) {
      if (out.isEmpty) {
        out.add(cur);
        continue;
      }
      final last = out.last;
      final touches = cur.start < last.end ||
          (_same(cur.start, last.end) && (cur.includeStart || last.includeEnd));
      if (!touches) {
        out.add(cur);
        continue;
      }
      final newEnd = cur.end > last.end ? cur : last;
      final sameEnd = _same(cur.end, last.end);
      out[out.length - 1] = InequalityInterval(
        start: last.start,
        end: newEnd.end,
        includeStart: last.includeStart,
        includeEnd: sameEnd ? (cur.includeEnd || last.includeEnd) : newEnd.includeEnd,
        startLabel: last.startLabel,
        endLabel: newEnd.endLabel,
      );
    }
    return out;
  }

  /// Complementario respecto a toda la recta real.
  static List<InequalityInterval> complement(List<InequalityInterval> list) {
    final items = union(list);
    if (items.isEmpty) {
      return const [InequalityInterval(start: double.negativeInfinity, end: double.infinity)];
    }
    final out = <InequalityInterval>[];
    var prevEnd = double.negativeInfinity;
    var prevIn = false;
    String? prevLabel;
    for (final it in items) {
      final valid = (it.start > prevEnd && !_same(it.start, prevEnd)) ||
          (_same(it.start, prevEnd) && prevEnd.isFinite && !prevIn && !it.includeStart);
      if (valid) {
        out.add(InequalityInterval(
          start: prevEnd,
          end: it.start,
          includeStart: prevEnd.isFinite && !prevIn,
          includeEnd: it.start.isFinite && !it.includeStart,
          startLabel: prevLabel,
          endLabel: it.startLabel,
        ));
      }
      prevEnd = it.end;
      prevIn = it.includeEnd;
      prevLabel = it.endLabel;
    }
    if (prevEnd != double.infinity) {
      out.add(InequalityInterval(
        start: prevEnd,
        end: double.infinity,
        includeStart: prevEnd.isFinite && !prevIn,
        startLabel: prevLabel,
      ));
    }
    return out;
  }

  /// Ensambla la solucion desde tramos y puntos: `segIn[i]` es el tramo i y `ptIn[i]` el punto i
  /// (hay `n` puntos y `n + 1` tramos).
  static List<InequalityInterval> assemble({
    required List<double> points,
    required List<String> labels,
    required List<bool> segIn,
    required List<bool> ptIn,
  }) {
    final n = points.length;
    final inSet = <bool>[for (var i = 0; i <= n; i++) ...[segIn[i], if (i < n) ptIn[i]]];
    final out = <InequalityInterval>[];
    var k = 0;
    while (k < inSet.length) {
      if (!inSet[k]) {
        k++;
        continue;
      }
      var j = k;
      while (j + 1 < inSet.length && inSet[j + 1]) {
        j++;
      }
      final firstIsPt = k.isOdd, lastIsPt = j.isOdd;
      final startPt = firstIsPt ? (k - 1) ~/ 2 : (k ~/ 2) - 1;
      final endPt = lastIsPt ? (j - 1) ~/ 2 : (j ~/ 2);
      final unboundedLeft = !firstIsPt && k == 0;
      final unboundedRight = !lastIsPt && j == inSet.length - 1;
      out.add(InequalityInterval(
        start: unboundedLeft ? double.negativeInfinity : points[startPt],
        end: unboundedRight ? double.infinity : points[endPt],
        startLabel: unboundedLeft ? null : labels[startPt],
        endLabel: unboundedRight ? null : labels[endPt],
        includeStart: firstIsPt,
        includeEnd: lastIsPt,
      ));
      k = j + 1;
    }
    return out;
  }

  /// LaTeX de la union de intervalos (`\emptyset` si esta vacia, `\mathbb{R}` si es toda la recta).
  static String latexOf(List<InequalityInterval> list) {
    if (list.isEmpty) return r'\emptyset';
    if (list.length == 1 && list.first.isLeftUnbounded && list.first.isRightUnbounded) {
      return r'(-\infty, +\infty)';
    }
    return list.map((i) {
      if (i.isBounded && _same(i.start, i.end)) return '\\left\\{${i.startLabel ?? i.toIntervalLatex()}\\right\\}';
      return i.toIntervalLatex();
    }).join(r' \cup ');
  }
}
