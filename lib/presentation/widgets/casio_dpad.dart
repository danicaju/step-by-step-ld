import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/key_click_sound.dart';

/// D-Pad circular/ovalado ergonómico de estilo Casio ClassWiz (108x84 px).
class CasioReplayPad extends StatelessWidget {
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final double width;
  final double height;

  const CasioReplayPad({
    super.key,
    required this.onLeft,
    required this.onRight,
    this.onUp,
    this.onDown,
    this.width = 108.0,
    this.height = 84.0,
  });

  @override
  Widget build(BuildContext context) {
    final double vBtnH = (height * 0.38).clamp(16.0, 32.0);
    final double vBtnW = (width * 0.38).clamp(24.0, 44.0);
    final double vBtnLR = ((width - vBtnW) / 2).clamp(0.0, 40.0);
    final double hBtnW = (width * 0.34).clamp(24.0, 38.0);
    final double hBtnTB = (height * 0.18).clamp(6.0, 18.0);
    final double iconVSize = (height * 0.34).clamp(18.0, 28.0);
    final double iconHSize = (height * 0.38).clamp(20.0, 32.0);
    final double medallionSize = (height * 0.28).clamp(14.0, 24.0);
    final double ringW = width * 0.88;
    final double ringH = height * 0.85;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E37),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: const Color(0xFF474E5D),
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            offset: Offset(0, 4),
            blurRadius: 6.0,
          ),
          BoxShadow(
            color: Color(0x26FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 1.0,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF333844),
            Color(0xFF2A2E37),
            Color(0xFF1B1E24),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Anillo interior grabado sutil (estética metálica ClassWiz)
          IgnorePointer(
            child: Center(
              child: Container(
                width: ringW,
                height: ringH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ringH / 2),
                  border: Border.all(
                    color: const Color(0xFF3E4554).withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // Flecha Arriba (▲)
          Positioned(
            top: 0,
            left: vBtnLR,
            right: vBtnLR,
            height: vBtnH,
            child: _DPadDirectionButton(
              key: const Key('replay_up'),
              icon: Icons.arrow_drop_up_rounded,
              size: iconVSize,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 1),
              tooltip: 'Arriba / Numerador / Replay',
              onTap: onUp,
            ),
          ),

          // Flecha Abajo (▼)
          Positioned(
            bottom: 0,
            left: vBtnLR,
            right: vBtnLR,
            height: vBtnH,
            child: _DPadDirectionButton(
              key: const Key('replay_down'),
              icon: Icons.arrow_drop_down_rounded,
              size: iconVSize,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 1),
              tooltip: 'Abajo / Denominador / Replay',
              onTap: onDown,
            ),
          ),

          // Flecha Izquierda (◀)
          Positioned(
            left: 0,
            top: hBtnTB,
            bottom: hBtnTB,
            width: hBtnW,
            child: _DPadDirectionButton(
              key: const Key('replay_left'),
              icon: Icons.arrow_left_rounded,
              size: iconHSize,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 2),
              tooltip: 'Izquierda / Paso anterior',
              onTap: onLeft,
            ),
          ),

          // Flecha Derecha (▶)
          Positioned(
            right: 0,
            top: hBtnTB,
            bottom: hBtnTB,
            width: hBtnW,
            child: _DPadDirectionButton(
              key: const Key('replay_right'),
              icon: Icons.arrow_right_rounded,
              size: iconHSize,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 2),
              tooltip: 'Derecha / Paso siguiente',
              onTap: onRight,
            ),
          ),

          // Medallón central metálico decorativo
          IgnorePointer(
            child: Center(
              child: Container(
                width: medallionSize,
                height: medallionSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF20242C),
                      Color(0xFF13151A),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF475569),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.circle,
                    size: 5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alias retrocompatible hacia [CasioReplayPad].
class CasioDPad extends CasioReplayPad {
  const CasioDPad({
    super.key,
    required super.onLeft,
    required super.onRight,
    super.onUp,
    super.onDown,
  });
}

class _DPadDirectionButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final String tooltip;
  final VoidCallback? onTap;

  const _DPadDirectionButton({
    super.key,
    required this.icon,
    required this.size,
    required this.alignment,
    required this.padding,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_DPadDirectionButton> createState() => _DPadDirectionButtonState();
}

class _DPadDirectionButtonState extends State<_DPadDirectionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (widget.onTap != null) {
            setState(() => _isPressed = true);
            HapticFeedback.lightImpact();
            KeyClickSound.playControl();
          }
        },
        onTapUp: (_) {
          if (widget.onTap != null) {
            setState(() => _isPressed = false);
            widget.onTap!();
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          alignment: widget.alignment,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _isPressed
                ? const Color(0xFFE5A93C).withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.onTap == null
                ? const Color(0xFF475569)
                : (_isPressed
                    ? const Color(0xFFE5A93C)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}
