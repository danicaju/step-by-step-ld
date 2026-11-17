import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final effectiveBorder =
        widget.isActive ? Colors.white : const Color(0xFF494E5B);

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
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: effectiveBorder,
              width: widget.isActive ? 1.6 : 1.0,
            ),
            boxShadow: _isPressed
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 2.5),
                      blurRadius: 1.5,
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
                          style: const TextStyle(
                            color: Color(0xFFE5A93C),
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
                          style: const TextStyle(
                            color: Color(0xFFE05D5D),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                Text(
                  showAlpha ? widget.alphaCaption! : widget.label,
                  style: TextStyle(
                    color: showAlpha ? const Color(0xFFE05D5D) : widget.textColor,
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF1F232B),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: const Color(0xFF353C49),
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accentColor,
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1.0;

    const step = 10.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = (y ~/ step).isEven ? 0.0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
