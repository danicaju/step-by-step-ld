import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
import '../../domain/math_engine/functions/function_family.dart';
import '../painters/graph_key_points.dart';
import '../painters/graph_viewport_calculator.dart';
import '../painters/graph_viewport_controller.dart';
import '../painters/universal_function_painter.dart';
import '../theme/theme_controller.dart';

/// Escala que gana la disputa de gestos desde el primer contacto (el visor no compite con
/// el scroll de un padre) y unifica arrastre (1 dedo / raton) y pellizco (2 dedos).
class _EagerScaleRecognizer extends ScaleGestureRecognizer {
  _EagerScaleRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Visor interactivo con `ClipRRect` estricto: arrastre, pellizco, rueda del raton, doble toque
/// para recentrar y botones `+`, `-` y recentrar en la esquina superior derecha.
class UniversalGraphView extends StatefulWidget {
  final FunctionModel model;
  final AsymptoteSet asymptotes;
  final FamilyInfo? info;
  final bool degrees;
  final GraphViewportController? controller;

  const UniversalGraphView({
    super.key,
    required this.model,
    required this.asymptotes,
    this.info,
    this.degrees = false,
    this.controller,
  });

  @override
  State<UniversalGraphView> createState() => _UniversalGraphViewState();
}

class _UniversalGraphViewState extends State<UniversalGraphView> {
  late GraphViewportController _ctrl = widget.controller ?? GraphViewportController();
  Offset _startFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;
  bool _moved = false;
  Size _size = const Size(300, 200);

  @override
  void didUpdateWidget(UniversalGraphView old) {
    super.didUpdateWidget(old);
    if (widget.controller != null && widget.controller != _ctrl) _ctrl = widget.controller!;
  }

  void _fitIfNeeded(Size size) {
    final aspect = (size.height / size.width).clamp(0.2, 2.0).toDouble();
    final key = (widget.model.raw, widget.degrees, (aspect * 10).round());
    if (_ctrl.fitKey == key) return;
    _ctrl.fitKey = key;
    _ctrl.fit(
      GraphViewportCalculator.window(widget.model, widget.asymptotes,
          info: widget.info, deg: widget.degrees, aspect: aspect),
      notify: false,
    );
  }

  void _onStart(ScaleStartDetails d) {
    _startFocal = _lastFocal = d.localFocalPoint;
    _lastScale = 1;
    _moved = false;
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    if ((d.localFocalPoint - _startFocal).distance > 8 || (d.scale - 1).abs() > 0.02) _moved = true;
    if (delta != Offset.zero) _ctrl.panByPixels(delta.dx, delta.dy, _size);
    if (d.pointerCount >= 2 && d.scale > 0 && d.scale != _lastScale) {
      _ctrl.zoomAt(d.localFocalPoint, d.scale / _lastScale, _size);
      _lastScale = d.scale;
    }
  }

  void _onEnd(ScaleEndDetails d) {
    if (!_moved) _ctrl.registerTap(DateTime.now(), _startFocal);
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      _ctrl.zoomByWheel(s.scrollDelta.dy, s.localPosition, _size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeController.current.lcdBackground;
    return ClipRRect(
      key: const Key('universal_graph_clip'),
      borderRadius: BorderRadius.circular(8.5),
      child: Container(
        color: bg,
        child: LayoutBuilder(
          builder: (context, c) {
            _size = Size(c.maxWidth.isFinite ? c.maxWidth : 300, c.maxHeight.isFinite ? c.maxHeight : 200);
            _fitIfNeeded(_size);
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: _onSignal,
                    child: RawGestureDetector(
                      key: const Key('universal_graph_gestures'),
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        _EagerScaleRecognizer: GestureRecognizerFactoryWithHandlers<_EagerScaleRecognizer>(
                          () => _EagerScaleRecognizer(debugOwner: this),
                          (r) => r
                            ..onStart = _onStart
                            ..onUpdate = _onUpdate
                            ..onEnd = _onEnd,
                        ),
                      },
                      child: ListenableBuilder(
                        listenable: _ctrl,
                        builder: (context, _) {
                          final w = _ctrl.window;
                          return RepaintBoundary(
                            child: CustomPaint(
                              key: const Key('universal_graph_paint'),
                              size: _size,
                              painter: UniversalFunctionPainter(
                                model: widget.model,
                                asymptotes: widget.asymptotes,
                                window: w,
                                keyPoints: GraphKeyPoints.of(widget.model, w, info: widget.info, deg: widget.degrees),
                                degrees: widget.degrees,
                                trig: widget.info?.family.isTrig ?? false,
                                background: bg,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GraphButton(key: const Key('graph_zoom_in'), icon: Icons.add, tooltip: 'Acercar', background: bg, onTap: _ctrl.zoomIn),
                      const SizedBox(width: 3),
                      _GraphButton(key: const Key('graph_zoom_out'), icon: Icons.remove, tooltip: 'Alejar', background: bg, onTap: _ctrl.zoomOut),
                      const SizedBox(width: 3),
                      _GraphButton(
                        key: const Key('graph_zoom_reset'),
                        icon: Icons.center_focus_strong_rounded,
                        tooltip: 'Recentrar',
                        background: bg,
                        onTap: _ctrl.reset,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Boton compacto estilo hardware / LCD con los colores del tema activo.
class _GraphButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color background;
  final VoidCallback onTap;

  const _GraphButton({super.key, required this.icon, required this.tooltip, required this.background, required this.onTap});

  static const Color ink = Color(0xFF1A2530);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 24,
          height: 22,
          decoration: BoxDecoration(
            color: background.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ink.withValues(alpha: 0.6), width: 1.2),
          ),
          child: Icon(icon, size: 15, color: ink),
        ),
      ),
    );
  }
}
