import 'package:flutter/material.dart';

/// Que flechas de desplazamiento deben verse en los bordes de la LCD.
class LcdEdgeFlags {
  final bool up;
  final bool down;
  final bool left;
  final bool right;

  const LcdEdgeFlags({
    this.up = false,
    this.down = false,
    this.left = false,
    this.right = false,
  });

  bool get any => up || down || left || right;
}

/// Flechas sutiles `▲ ▼ ◀ ▶` sobre los bordes de la LCD cuando hay historial,
/// pasos o contenido que desplazar. Solo pintan; no capturan toques.
class LcdEdgeArrows extends StatelessWidget {
  final LcdEdgeFlags flags;
  final Color color;

  const LcdEdgeArrows({super.key, required this.flags, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget arrow(String glyph, bool on, Key key) => !on
        ? const SizedBox.shrink()
        : Opacity(
          opacity: 0.55,
          child: Text(
            glyph,
            key: key,
            style: TextStyle(color: color, fontSize: 8, height: 1, fontWeight: FontWeight.w900),
          ),
        );
    return IgnorePointer(
      key: const Key('lcd_edge_arrows'),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, child: Center(child: arrow('▲', flags.up, const Key('edge_up')))),
          Positioned(bottom: 0, left: 0, right: 0, child: Center(child: arrow('▼', flags.down, const Key('edge_down')))),
          Positioned(left: 1, top: 0, bottom: 0, child: Center(child: arrow('◀', flags.left, const Key('edge_left')))),
          Positioned(right: 1, top: 0, bottom: 0, child: Center(child: arrow('▶', flags.right, const Key('edge_right')))),
        ],
      ),
    );
  }
}
