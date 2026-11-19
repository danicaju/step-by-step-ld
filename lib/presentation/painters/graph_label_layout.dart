import 'dart:ui';

/// Coloca etiquetas sin que choquen con ejes, numeros de ejes, marcadores ni otras etiquetas.
///
/// Prueba desplazamientos candidatos alrededor del punto (arriba-dcha, arriba-izq, abajo-dcha,
/// abajo-izq, arriba-centro, abajo-centro) y elige el primero libre dentro del lienzo.
class GraphLabelLayout {
  final Size canvas;
  final List<Rect> _occupied = [];

  GraphLabelLayout(this.canvas, {Iterable<Rect> occupied = const []}) {
    _occupied.addAll(occupied);
  }

  List<Rect> get occupied => List.unmodifiable(_occupied);

  /// Reserva una zona (eje, marcador, numero) sin colocar etiqueta.
  void reserve(Rect r) => _occupied.add(r);

  /// Candidatos de la caja de [label] respecto a [anchor], en orden de preferencia.
  static List<Rect> candidates(Offset anchor, Size label, {double gap = 7}) {
    final w = label.width, h = label.height;
    return [
      Rect.fromLTWH(anchor.dx + gap, anchor.dy - gap - h, w, h), // arriba-derecha
      Rect.fromLTWH(anchor.dx - gap - w, anchor.dy - gap - h, w, h), // arriba-izquierda
      Rect.fromLTWH(anchor.dx + gap, anchor.dy + gap, w, h), // abajo-derecha
      Rect.fromLTWH(anchor.dx - gap - w, anchor.dy + gap, w, h), // abajo-izquierda
      Rect.fromLTWH(anchor.dx - w / 2, anchor.dy - gap - h, w, h), // arriba-centro
      Rect.fromLTWH(anchor.dx - w / 2, anchor.dy + gap, w, h), // abajo-centro
    ];
  }

  double _overlap(Rect r) {
    var total = 0.0;
    for (final o in _occupied) {
      final i = r.intersect(o.inflate(1));
      if (i.width > 0 && i.height > 0) total += i.width * i.height;
    }
    return total;
  }

  bool _inside(Rect r) => r.left >= 1 && r.top >= 1 && r.right <= canvas.width - 1 && r.bottom <= canvas.height - 1;

  /// Elige y reserva la mejor posicion. Si ninguna esta libre, la de menor solapamiento (dentro del lienzo).
  Rect place(Offset anchor, Size label) {
    Rect? best;
    var bestScore = double.infinity;
    for (final c in candidates(anchor, label)) {
      final fitted = _clampInside(c);
      final penalty = _inside(c) ? 0.0 : 1000.0;
      final score = _overlap(fitted) + penalty;
      if (score == 0) {
        best = fitted;
        break;
      }
      if (score < bestScore) {
        bestScore = score;
        best = fitted;
      }
    }
    final chosen = best!;
    _occupied.add(chosen);
    return chosen;
  }

  Rect _clampInside(Rect r) {
    final dx = r.left < 1 ? 1 - r.left : (r.right > canvas.width - 1 ? canvas.width - 1 - r.right : 0.0);
    final dy = r.top < 1 ? 1 - r.top : (r.bottom > canvas.height - 1 ? canvas.height - 1 - r.bottom : 0.0);
    return r.shift(Offset(dx, dy));
  }
}
