import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graph_viewport_calculator.dart';

/// Camara del visor de M5: ventana matematica visible con arrastre, zoom con foco anclado,
/// recentrado y doble toque. Logica pura (sin widgets) para poder probarla.
///
/// El ancho y el alto visibles se mantienen siempre entre [minSpan] y [maxSpan] unidades.
class GraphViewportController extends ChangeNotifier {
  static const double minSpan = 0.2;
  static const double maxSpan = 1000;
  static const double zoomStep = 1.25;
  static const Duration doubleTapWindow = Duration(milliseconds: 300);
  static const double doubleTapSlop = 40;

  GraphWindow _initial = const GraphWindow(-6, 6, -6, 6);
  GraphWindow _window = const GraphWindow(-6, 6, -6, 6);

  /// Clave del ultimo ajuste automatico (funcion + proporcion del lienzo).
  Object? fitKey;

  DateTime? _lastTapTime;
  Offset? _lastTapPos;

  GraphWindow get window => _window;
  GraphWindow get initial => _initial;

  /// Fija el encuadre inicial (y lo aplica). Con [notify] = false se puede llamar durante `build`.
  void fit(GraphWindow w, {bool notify = true}) {
    _initial = _sane(w);
    _window = _initial;
    if (notify) notifyListeners();
  }

  /// Obliga a recalcular el encuadre inicial la proxima vez que el visor se construya.
  void invalidate() => fitKey = null;

  void reset() {
    _window = _initial;
    notifyListeners();
  }

  /// Arrastre: el contenido sigue al dedo / raton ([dx], [dy] en pixeles).
  void panByPixels(double dx, double dy, Size size) {
    if (size.width <= 0 || size.height <= 0 || (dx == 0 && dy == 0)) return;
    final w = _window;
    _set(GraphWindow(
      w.xMin - dx / size.width * w.width,
      w.xMax - dx / size.width * w.width,
      w.yMin + dy / size.height * w.height,
      w.yMax + dy / size.height * w.height,
    ));
  }

  /// Desplazamiento en fracciones de ventana (D-Pad).
  void panByFraction(double fx, double fy) => _set(_window.panned(fx, fy));

  /// Zoom por [factor] (> 1 acerca) manteniendo bajo [focal] el mismo punto matematico.
  void zoomAt(Offset focal, double factor, Size size) {
    if (size.width <= 0 || size.height <= 0 || !factor.isFinite || factor <= 0) return;
    final w = _window;
    final f = factor.clamp(
      math.max(w.width, w.height) / maxSpan,
      math.min(w.width, w.height) / minSpan,
    ).toDouble();
    final fx = (focal.dx / size.width).clamp(0.0, 1.0);
    final fy = (focal.dy / size.height).clamp(0.0, 1.0);
    final mx = w.xMin + fx * w.width;
    final my = w.yMax - fy * w.height;
    final nw = w.width / f, nh = w.height / f;
    _set(GraphWindow(mx - fx * nw, mx + (1 - fx) * nw, my - (1 - fy) * nh, my + fy * nh));
  }

  /// Rueda del raton / trackpad: [scrollDy] > 0 aleja.
  void zoomByWheel(double scrollDy, Offset focal, Size size) =>
      zoomAt(focal, math.exp(-scrollDy * 0.0015), size);

  void zoomIn() => zoomAt(const Offset(0.5, 0.5), zoomStep, const Size(1, 1));

  void zoomOut() => zoomAt(const Offset(0.5, 0.5), 1 / zoomStep, const Size(1, 1));

  /// Registra un toque; si es el segundo cercano en tiempo y espacio, recentra y devuelve `true`.
  bool registerTap(DateTime time, Offset pos) {
    final lt = _lastTapTime, lp = _lastTapPos;
    if (lt != null && lp != null && time.difference(lt) <= doubleTapWindow && (pos - lp).distance <= doubleTapSlop) {
      _lastTapTime = null;
      _lastTapPos = null;
      reset();
      return true;
    }
    _lastTapTime = time;
    _lastTapPos = pos;
    return false;
  }

  void _set(GraphWindow w) {
    _window = _sane(w, previous: _window);
    notifyListeners();
  }

  /// Rechaza ventanas no finitas y recorta los rangos a [minSpan, maxSpan] sin mover el centro.
  static GraphWindow _sane(GraphWindow w, {GraphWindow? previous}) {
    final ok = [w.xMin, w.xMax, w.yMin, w.yMax].every((v) => v.isFinite);
    if (!ok) return previous ?? const GraphWindow(-6, 6, -6, 6);
    double clampSpan(double lo, double hi) {
      final c = (lo + hi) / 2;
      final s = (hi - lo).abs().clamp(minSpan, maxSpan).toDouble();
      return c - s / 2;
    }

    final xl = clampSpan(w.xMin, w.xMax), yl = clampSpan(w.yMin, w.yMax);
    final sx = (w.xMax - w.xMin).abs().clamp(minSpan, maxSpan).toDouble();
    final sy = (w.yMax - w.yMin).abs().clamp(minSpan, maxSpan).toDouble();
    return GraphWindow(xl, xl + sx, yl, yl + sy);
  }
}
