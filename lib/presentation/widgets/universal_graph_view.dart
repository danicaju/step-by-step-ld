import 'package:flutter/material.dart';

import '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
import '../../domain/math_engine/functions/function_family.dart';
import '../painters/graph_key_points.dart';
import '../painters/graph_viewport_calculator.dart';
import '../painters/graph_viewport_controller.dart';
import '../painters/universal_function_painter.dart';
import '../theme/theme_controller.dart';
import 'interactive_graph_frame.dart';

/// Visor de f(x) de M5 con `ClipRRect` estricto sobre el marco interactivo comun
/// ([InteractiveGraphFrame]): arrastre, pellizco, rueda, doble toque y botones de zoom.
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
  late final GraphViewportController _own = GraphViewportController();

  GraphViewportController get _ctrl => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeController.current.lcdBackground;
    return InteractiveGraphFrame(
      controller: _ctrl,
      fitKey: (widget.model.raw, widget.degrees),
      initialWindow: (aspect) => GraphViewportCalculator.window(widget.model, widget.asymptotes,
          info: widget.info, deg: widget.degrees, aspect: aspect),
      background: bg,
      clipKey: const Key('universal_graph_clip'),
      gesturesKey: const Key('universal_graph_gestures'),
      builder: (context, w, size) => CustomPaint(
        key: const Key('universal_graph_paint'),
        size: size,
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
  }
}
