import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/calculator_themes.dart';
import '../theme/theme_controller.dart';
import '../utils/key_click_sound.dart';

class CompactControlKey extends StatefulWidget {
  final String label;
  final String? caption;
  final Color backgroundColor;
  final Color textColor;
  final bool isActive;
  final String? alphaCaption;
  final bool isAlphaActive;
  final VoidCallback onTap;

  const CompactControlKey({
    super.key,
    required this.label,
    this.caption,
    this.alphaCaption,
    this.isAlphaActive = false,
    required this.backgroundColor,
    required this.textColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<CompactControlKey> createState() => _CompactControlKeyState();
}

class _CompactControlKeyState extends State<CompactControlKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final showAlpha = widget.isAlphaActive && widget.alphaCaption != null;
    final hw = ThemeController.current;
    final style = hw.keyStyle(widget.label, widget.backgroundColor, widget.textColor);
    final activeBorder = hw.isDefault || hw.chassisMid.computeLuminance() < 0.4 ? Colors.white : const Color(0xFF1A1A1A);
    final effectiveBorder = widget.isActive ? activeBorder : style.border;
    final radius = style.stadium ? 999.0 : (hw.isDefault ? 7.0 : style.radius);

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
          KeyClickSound.playControl();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          transform: Matrix4.translationValues(0.0, _isPressed ? 1.5 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: effectiveBorder,
              width: widget.isActive ? 1.6 : 1.0,
            ),
            boxShadow: _isPressed
                ? const []
                : [
                    BoxShadow(
                      color: hw.keyShape == KeyCapShape.retroWedge
                          ? Color.lerp(style.background, Colors.black, 0.5)!
                          : const Color(0x99000000),
                      offset: Offset(0, hw.keyShape == KeyCapShape.retroWedge ? 4.5 : 2.5),
                      blurRadius: hw.keyShape == KeyCapShape.retroWedge ? 0 : 1.5,
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.caption != null || widget.alphaCaption != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.caption != null)
                        Text(
                          widget.caption!,
                          style: TextStyle(
                            color: hw.legendShift,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      if (widget.caption != null && widget.alphaCaption != null)
                        const SizedBox(width: 6),
                      if (widget.alphaCaption != null)
                        Text(
                          widget.alphaCaption!,
                          style: TextStyle(
                            color: hw.legendAlpha,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                Text(
                  showAlpha ? widget.alphaCaption! : widget.label,
                  style: TextStyle(
                    color: showAlpha ? hw.legendAlpha : style.text,
                    fontFamily: style.mono ? 'monospace' : null,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderBezelButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final Color accentColor;
  final VoidCallback onPressed;

  const HeaderBezelButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hw = ThemeController.current;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: hw.barButtonBg,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: hw.barButtonBorder,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: hw.isDefault ? accentColor : (accentColor == const Color(0xFFE5A93C) ? hw.appBarAccent : hw.barButtonText),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CarbonTexturePainter extends CustomPainter {
  final ChassisFinish finish;
  final Color color;

  /// Los datos llegan por constructor: al cambiar de tema se repinta; sin cambios, no.
  const CarbonTexturePainter({required this.finish, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (finish == ChassisFinish.plain) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    if (finish == ChassisFinish.grain) {
      // Grano de plastico retro: trazos horizontales finos.
      for (double y = 0; y < size.height; y += 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint..strokeWidth = 0.5);
      }
      return;
    }

    const step = 10.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = (y ~/ step).isEven ? 0.0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CarbonTexturePainter old) => old.finish != finish || old.color != color;
}
