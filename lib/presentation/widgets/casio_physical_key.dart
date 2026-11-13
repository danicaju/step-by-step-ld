import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/key_click_sound.dart';

class CasioPhysicalKey extends StatefulWidget {
  final String label;
  final Widget? customLabelWidget;
  final String? shiftLabel;
  final String? alphaLabel;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback onTap;
  final int flex;
  final double? minHeight;

  const CasioPhysicalKey({
    super.key,
    required this.label,
    this.customLabelWidget,
    this.shiftLabel,
    this.alphaLabel,
    this.backgroundColor,
    this.textColor,
    required this.onTap,
    this.flex = 1,
    this.minHeight,
  });

  @override
  State<CasioPhysicalKey> createState() => _CasioPhysicalKeyState();
}

class _CasioPhysicalKeyState extends State<CasioPhysicalKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFF2B2E36);
    final txtColor = widget.textColor ?? Colors.white;

    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subfunciones superiores: SHIFT (izquierda) y ALPHA (derecha)
            SizedBox(
              height: 11,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.shiftLabel ?? '',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.alphaLabel ?? '',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFFE05252),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            // Tecla física con animación de recorrido vertical y flex vertical
            Expanded(
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() => _isPressed = true);
                  HapticFeedback.lightImpact();
                  KeyClickSound.playForLabel(widget.label);
                },
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                  widget.onTap();
                },
                onTapCancel: () => setState(() => _isPressed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  constraints: widget.minHeight != null
                      ? BoxConstraints(minHeight: widget.minHeight!)
                      : null,
                  transform: Matrix4.translationValues(
                    0.0,
                    _isPressed ? 2.0 : 0.0,
                    0.0,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: _isPressed
                          ? const Color(0xFF141619)
                          : const Color(0xFF494E5B),
                      width: 1.0,
                    ),
                    boxShadow: _isPressed
                        ? const []
                        : const [
                            BoxShadow(
                              color: Color(0xAA000000),
                              offset: Offset(0, 3),
                              blurRadius: 1.0,
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: widget.customLabelWidget ??
                        Text(
                          widget.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: txtColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
