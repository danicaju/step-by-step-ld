import 'balanced_scan.dart';

/// Navegacion vertical (▲/▼) por profundidad real en fracciones agrupadas
/// `(num)/(den)` anidadas (castillos). Trabaja sobre el raw del editor.
class NestedFractionNavigator {
  const NestedFractionNavigator._();

  /// Bloque `(num)/(den)`. `denClose` == raw.length si el den sigue abierto.
  static List<_Block> _parse(String raw) {
    final blocks = <_Block>[];
    final stack = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (ch == '(') {
        stack.add(i);
      } else if (ch == ')' && stack.isNotEmpty) {
        final open = stack.removeLast();
        if (raw.startsWith('/(', i + 1)) {
          final dOpen = i + 2;
          final dClose = BalancedScan.findClose(raw, dOpen) ?? raw.length;
          blocks.add(_Block(open, i, dOpen, dClose));
        }
      }
    }
    // Padre = bloque mas pequeno que contiene estrictamente al hijo.
    for (final b in blocks) {
      _Block? best;
      for (final p in blocks) {
        if (identical(p, b)) continue;
        final inNum = b.start > p.numOpen && b.end <= p.numClose;
        final inDen = b.start > p.denOpen && b.end <= p.denClose;
        if ((inNum || inDen) && (best == null || p.width < best.width)) {
          best = p;
          b.parentInNum = inNum;
        }
      }
      b.parent = best;
    }
    return blocks;
  }

  /// (bloque, esNumerador) del slot mas interno que contiene [cursor].
  static (_Block, bool)? _innermost(List<_Block> blocks, int cursor) {
    _Block? best;
    var bestNum = true;
    var bestW = 1 << 30;
    for (final b in blocks) {
      if (cursor > b.numOpen && cursor <= b.numClose) {
        final w = b.numClose - b.numOpen;
        if (w < bestW) {
          bestW = w;
          best = b;
          bestNum = true;
        }
      }
      if (cursor > b.denOpen && cursor <= b.denClose) {
        final w = b.denClose - b.denOpen;
        if (w < bestW) {
          bestW = w;
          best = b;
          bestNum = false;
        }
      }
    }
    return best == null ? null : (best, bestNum);
  }

  /// Hijos directos de [slot] (num o den) de [parent], por posicion.
  static List<_Block> _children(List<_Block> blocks, _Block parent, bool num) =>
      blocks.where((c) => identical(c.parent, parent) && c.parentInNum == num).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// ▼. `null` si no hay nivel inferior (el llamador aplica su fallback).
  static int? down(String raw, int cursor) {
    final blocks = _parse(raw);
    final hit = _innermost(blocks, cursor.clamp(0, raw.length));
    if (hit == null) return null;
    var (f, inNum) = hit;
    if (inNum) {
      final kids = _children(blocks, f, false);
      if (kids.isNotEmpty && kids.first.start == f.denOpen + 1) {
        return kids.first.numClose;
      }
      return f.denClose;
    }
    final kids = _children(blocks, f, false);
    if (kids.isNotEmpty) {
      final after = kids.where((k) => k.numOpen >= cursor);
      return (after.isNotEmpty ? after.first : kids.last).numClose;
    }
    // Sin hijas: subir en la cadena de ancestros hasta uno donde estemos en num.
    _Block? p = f;
    while (p!.parent != null) {
      final par = p.parent!;
      if (p.parentInNum) return par.denClose;
      p = par;
    }
    return null;
  }

  /// ▲. `null` si ya estamos en el numerador de la fraccion raiz.
  static int? up(String raw, int cursor) {
    final blocks = _parse(raw);
    final hit = _innermost(blocks, cursor.clamp(0, raw.length));
    if (hit == null) return null;
    final (f, inNum) = hit;
    if (!inNum) return f.numClose;
    _Block? p = f;
    while (p!.parent != null) {
      final par = p.parent!;
      if (!p.parentInNum) return par.numClose;
      p = par;
    }
    return null;
  }
}

class _Block {
  final int numOpen, numClose, denOpen, denClose;
  _Block? parent;
  bool parentInNum = true;
  _Block(this.numOpen, this.numClose, this.denOpen, this.denClose);
  int get start => numOpen;
  int get end => denClose;
  int get width => denClose - numOpen;
}
