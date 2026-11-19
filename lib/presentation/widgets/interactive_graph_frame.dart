import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../painters/graph_viewport_calculator.dart';
import '../painters/graph_viewport_controller.dart';

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

typedef GraphFrameBuilder = Widget Function(BuildContext context, GraphWindow window, Size size);

/// Marco interactivo comun de las graficas (M3, M5, M7): arrastre, pellizco, rueda del raton,
/// doble toque para recentrar y botones `+`, `-` y recentrar en la esquina superior derecha.
///
/// El encuadre inicial lo calcula [initialWindow] a partir de la proporcion del lienzo y se
/// recalcula cuando cambia [fitKey] (otra funcion/sistema) o la proporcion.
class InteractiveGraphFrame extends StatefulWidget {
  final GraphViewportController controller;
  final Object? fitKey;
  final GraphWindow Function(double aspect) initialWindow;
  final GraphFrameBuilder builder;
  final Color background;
  final Key? clipKey;
  final Key? gesturesKey;
  final double borderRadius;

  const InteractiveGraphFrame({
    super.key,
    required this.controller,
    required this.fitKey,
    required this.initialWindow,
    required this.builder,
    required this.background,
    this.clipKey,
    this.gesturesKey,
    this.borderRadius = 8.5,
  });

  @override
  State<InteractiveGraphFrame> createState() => _InteractiveGraphFrameState();
}

class _InteractiveGraphFrameState extends State<InteractiveGraphFrame> {
  Offset _startFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;
  bool _moved = false;
  Size _size = const Size(300, 200);

  GraphViewportController get _ctrl => widget.controller;

  void _fitIfNeeded(Size size) {
    final aspect = (size.height / size.width).clamp(0.2, 2.0).toDouble();
    final key = (widget.fitKey, (aspect * 10).round());
    if (_ctrl.fitKey == key) return;
    _ctrl.fitKey = key;
    _ctrl.fit(widget.initialWindow(aspect), notify: false);
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
    final bg = widget.background;
    return ClipRRect(
      key: widget.clipKey,
      borderRadius: BorderRadius.circular(widget.borderRadius),
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
                      key: widget.gesturesKey,
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
                        builder: (context, _) => RepaintBoundary(child: widget.builder(context, _ctrl.window, _size)),
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
