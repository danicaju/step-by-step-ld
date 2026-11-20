import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fila de LaTeX con scroll horizontal (red de seguridad de [ResponsiveMathLine]).
///
/// Arrastre con raton, tactil y trackpad. Los indicadores de contenido deslizable
/// (degradado sobre [backgroundColor] y flecha en [inkColor] con baja opacidad) solo
/// aparecen si `maxScrollExtent > 0`, y solo en el lado donde queda contenido.
class ResponsiveMathScrollLine extends StatefulWidget {
  final Widget child;
  final Color inkColor;
  final Color? backgroundColor;
  final bool showHints;

  const ResponsiveMathScrollLine({
    super.key,
    required this.child,
    required this.inkColor,
    this.backgroundColor,
    this.showHints = true,
  });

  @override
  State<ResponsiveMathScrollLine> createState() => _ResponsiveMathScrollLineState();
}

class _ResponsiveMathScrollLineState extends State<ResponsiveMathScrollLine> {
  final ScrollController _controller = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics m) {
    final left = m.pixels > 0.5;
    final right = m.maxScrollExtent - m.pixels > 0.5;
    if (left != _canLeft || right != _canRight) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _canLeft = left;
          _canRight = right;
        });
      });
    }
    return false;
  }

  Widget _hint(bool left) {
    final bg = widget.backgroundColor;
    final ink = widget.inkColor.withValues(alpha: 0.6);
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: IgnorePointer(
        child: Container(
          key: Key(left ? 'math_scroll_hint_left' : 'math_scroll_hint_right'),
          width: 20,
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          decoration: bg == null
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: left ? Alignment.centerLeft : Alignment.centerRight,
                    end: left ? Alignment.centerRight : Alignment.centerLeft,
                    colors: [bg.withValues(alpha: 0.95), bg.withValues(alpha: 0)],
                  ),
                ),
          child: Text(left ? '◀' : '▶', style: TextStyle(color: ink, fontSize: 9)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context).copyWith(
      scrollbars: false,
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: behavior,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: SingleChildScrollView(
                key: const Key('math_scroll_line'),
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: widget.child,
              ),
            ),
          ),
        ),
        if (widget.showHints && _canLeft) _hint(true),
        if (widget.showHints && _canRight) _hint(false),
      ],
    );
  }
}
