import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/calculator_themes.dart';
import '../theme/theme_controller.dart';
import '../utils/key_click_sound.dart';
import 'repeat_press.dart';

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
  final bool isShiftActive;
  final bool isAlphaActive;

  /// Altura de la sombra: teclas numericas (alto) vs cientificas (bajo).
  final double? relief;

  /// Mantener pulsada repite la accion (DEL).
  final bool repeatable;

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
    this.isShiftActive = false,
    this.isAlphaActive = false,
    this.relief,
    this.repeatable = false,
  });

  @override
  State<CasioPhysicalKey> createState() => _CasioPhysicalKeyState();
}

class _CasioPhysicalKeyState extends State<CasioPhysicalKey> {
  bool _isPressed = false;
  final RepeatPress _repeat = RepeatPress();

  @override
  void dispose() {
    _repeat.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hw = ThemeController.current;
    final style = hw.keyStyle(widget.label, widget.backgroundColor, widget.textColor);
    final bgColor = style.background;

    final bool showShiftFace = widget.isShiftActive &&
        widget.shiftLabel != null &&
        widget.shiftLabel!.trim().isNotEmpty;
    final bool showAlphaFace = widget.isAlphaActive &&
        widget.alphaLabel != null &&
        widget.alphaLabel!.trim().isNotEmpty;

    final String activeFaceLabel = showShiftFace
        ? widget.shiftLabel!
        : (showAlphaFace ? widget.alphaLabel! : widget.label);

    final Color effectiveTextColor = showShiftFace
        ? hw.legendShift
        : (showAlphaFace ? hw.legendAlpha : style.text);

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
                        style: TextStyle(
                          color: hw.legendShift,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: style.mono ? 'monospace' : null,
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
                        style: TextStyle(
                          color: hw.legendAlpha,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: style.mono ? 'monospace' : null,
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
                  if (widget.repeatable) _repeat.start(widget.onTap);
                },
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                  final repeated = _repeat.fired;
                  _repeat.cancel();
                  if (!repeated) widget.onTap();
                },
                onTapCancel: () {
                  _repeat.cancel();
                  setState(() => _isPressed = false);
                },
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
                    borderRadius: BorderRadius.circular(style.stadium ? 999.0 : style.radius),
                    border: Border.all(
                      color: _isPressed ? const Color(0xFF141619) : style.border,
                      width: hw.keyShape == KeyCapShape.flatChiclet ? 0.8 : 1.0,
                    ),
                    boxShadow: _isPressed
                        ? const []
                        : [
                            BoxShadow(
                              color: hw.isDefault
                                  ? const Color(0xAA000000)
                                  : (hw.keyShape == KeyCapShape.retroWedge
                                      ? Color.lerp(bgColor, Colors.black, 0.5)!
                                      : const Color(0x55000000)),
                              offset: Offset(0, hw.isDefault ? (widget.relief ?? style.relief) : style.relief),
                              blurRadius: hw.keyShape == KeyCapShape.retroWedge ? 0.0 : 1.0,
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: (!showShiftFace && !showAlphaFace && widget.customLabelWidget != null)
                        ? widget.customLabelWidget!
                        : Text(
                            activeFaceLabel,
                            maxLines: 1,
                            style: TextStyle(
                              color: effectiveTextColor,
                              fontSize: (showShiftFace || showAlphaFace) ? 12.0 : 13.0,
                              fontWeight: FontWeight.bold,
                              fontFamily: style.mono ? 'monospace' : null,
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
