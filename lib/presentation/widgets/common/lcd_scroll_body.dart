import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Cuerpo de la LCD con scroll vertical suave.
///
/// En vez de pedir altura intrinseca (que revienta con `LayoutBuilder`/`Expanded` de los
/// editores), da al contenido una altura ACOTADA `max(viewport, minContentHeight)`: todos los
/// `Expanded`/`Spacer`/`FittedBox` del hijo siguen siendo validos y, si no cabe, se desplaza
/// en vez de desbordar. Con [lockScroll] el cuerpo mide exactamente el viewport y no scrollea
/// (lienzos con pan/zoom que necesitan el gesto vertical).
///
/// La pista visual (barra fina + degradados de borde) usa solo [ink] y [background]
/// del tema activo y aparece unicamente cuando hay contenido desbordado.
class LcdScrollBody extends StatefulWidget {
  final Color ink;
  final Color background;
  final double minContentHeight;
  final bool lockScroll;

  /// Cuando cambia (modo, paso, pantalla) el scroll vuelve arriba.
  final Object? resetKey;
  final Widget Function(BuildContext context, double bodyHeight) builder;

  const LcdScrollBody({
    super.key,
    required this.ink,
    required this.background,
    required this.builder,
    this.minContentHeight = 0,
    this.lockScroll = false,
    this.resetKey,
  });

  @override
  State<LcdScrollBody> createState() => _LcdScrollBodyState();
}

class _ScrollHint {
  final double pixels;
  final double max;
  const _ScrollHint(this.pixels, this.max);
  bool get scrollable => max > 1;
  bool get canUp => scrollable && pixels > 1;
  bool get canDown => scrollable && max - pixels > 1;
}

class _LcdScrollBodyState extends State<LcdScrollBody> {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<_ScrollHint> _hint = ValueNotifier(const _ScrollHint(0, 0));

  @override
  void dispose() {
    _controller.dispose();
    _hint.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LcdScrollBody old) {
    super.didUpdateWidget(old);
    if (widget.resetKey != old.resetKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients && _controller.offset != 0) {
          _controller.jumpTo(0);
        }
      });
    }
  }

  bool _onMetrics(ScrollMetrics m) {
    final next = _ScrollHint(m.pixels, m.maxScrollExtent);
    final cur = _hint.value;
    if ((next.pixels - cur.pixels).abs() > 0.5 || (next.max - cur.max).abs() > 0.5) {
      // Puede llegar durante el layout: se aplaza al final del frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hint.value = next;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final viewport = c.maxHeight.isFinite ? c.maxHeight : widget.minContentHeight;
        final bodyHeight =
            widget.lockScroll ? viewport : math.max(viewport, widget.minContentHeight);
        final scroll = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => n.depth == 0 ? _onMetrics(n.metrics) : false,
              child: SingleChildScrollView(
                key: const Key('lcd_scroll_body'),
                controller: _controller,
                physics: widget.lockScroll
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: SizedBox(
                  height: bodyHeight,
                  width: c.maxWidth,
                  child: widget.builder(context, bodyHeight),
                ),
              ),
            ),
          ),
        );
        if (widget.lockScroll) return scroll;
        return Stack(
          children: [
            Positioned.fill(child: scroll),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<_ScrollHint>(
                  valueListenable: _hint,
                  builder: (context, h, _) => h.scrollable
                      ? _hintLayer(h, viewport)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hintLayer(_ScrollHint h, double viewport) {
    final total = viewport + h.max;
    final thumb = (viewport * viewport / total).clamp(14.0, viewport);
    final top = h.max <= 0 ? 0.0 : (h.pixels / h.max).clamp(0.0, 1.0) * (viewport - thumb);
    Widget fade(bool visible, bool atTop) => AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: visible ? 1 : 0,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
                end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  widget.background.withValues(alpha: 0.92),
                  widget.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
    return Stack(
      key: const Key('lcd_scroll_hint'),
      children: [
        Positioned(left: 0, right: 0, top: 0, child: fade(h.canUp, true)),
        Positioned(left: 0, right: 0, bottom: 0, child: fade(h.canDown, false)),
        Positioned(
          right: 0,
          top: top,
          width: 2,
          height: thumb,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.ink.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Al activarse (foco del D-Pad), desplaza los `Scrollable` ancestros lo justo para que
/// el hijo quede visible; si ya se ve no se mueve.
class LcdEnsureVisible extends StatefulWidget {
  final bool active;
  final Widget child;
  const LcdEnsureVisible({super.key, required this.active, required this.child});

  @override
  State<LcdEnsureVisible> createState() => _LcdEnsureVisibleState();
}

class _LcdEnsureVisibleState extends State<LcdEnsureVisible> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _reveal();
  }

  @override
  void didUpdateWidget(LcdEnsureVisible old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
