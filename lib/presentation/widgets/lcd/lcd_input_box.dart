import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'blinking_cursor_builder.dart';
import 'lcd_math_sanitizer.dart';
import 'lcd_palette.dart';

/// Casilla de entrada unica de la LCD (M4, M8, M9, M10, M11, M12).
///
/// - Activa: fondo calido tintado, borde ambar de 2 px y cursor parpadeante real
///   (tambien con la casilla vacia).
/// - Inactiva: fondo LCD (`#BDCEBE` en el tema clasico), borde de 1.5 px y su LaTeX
///   (o un marcador tenue si esta vacia).
///
/// El contenido llega como [latex] (que puede traer el cursor `#1A2530` ya colocado,
/// p. ej. desde `rawToLiveLatex`) o como [text] plano; con [text] el cursor se coloca
/// al final. Los tests detectan el estado del cursor con las claves
/// `lcd_cursor_on` / `lcd_cursor_off`.
class LcdInputBox extends StatelessWidget {
  final bool active;
  final String? latex;
  final String? text;
  final String placeholder;
  final double fontSize;
  final double minWidth;
  final double minHeight;

  /// `true`: la casilla crece con el contenido; `false`: se encoge (`scaleDown`) si no cabe.
  final bool expandable;
  final bool dark;
  final LcdPalette? palette;
  final VoidCallback? onTap;
  final Alignment alignment;
  final EdgeInsets padding;

  const LcdInputBox({
    super.key,
    required this.active,
    this.latex,
    this.text,
    this.placeholder = '',
    this.fontSize = 14,
    this.minWidth = 52,
    this.minHeight = 28,
    this.expandable = false,
    this.dark = false,
    this.palette,
    this.onTap,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  static const Color amber = Color(0xFFE5A93C);
  static const Color activeFill = Color(0xFFD8CFA6);
  static const Color ink = Color(0xFF1A2530);
  static const String cursorBar = '\\textcolor{#1A2530}{\\mid}';

  LcdPalette get _pal => palette ?? (dark ? LcdPalette.night : LcdPalette.classic);
  bool get _night => dark || palette == LcdPalette.night;

  /// Fondo de la casilla activa segun tema (clasico: `#D8CFA6`).
  Color get fillActive =>
      _night || _pal == LcdPalette.paper ? Color.alphaBlend(amber.withValues(alpha: 0.24), _pal.inset) : activeFill;

  Color get fillIdle => _pal.inset;
  Color get borderIdle => _pal.border;
  Color get textColor => _night ? _pal.formula : ink;

  /// LaTeX que se pinta: [latex] tal cual, o [text] (+ cursor al final si esta activa).
  String get _tex {
    final base = latex ?? ((text ?? '').isEmpty ? '' : text!);
    if (latex != null) return base;
    return active ? '$base$cursorBar' : base;
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: active ? fillActive : fillIdle,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: active ? amber : borderIdle, width: active ? 2 : 1.5),
      ),
      child: _content(),
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }

  Widget _content() {
    final tex = _tex;
    if (tex.isEmpty) {
      return placeholder.isEmpty
          ? SizedBox(height: fontSize * 1.3)
          : Text(
              placeholder,
              style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: fontSize, fontFamily: 'monospace'),
            );
    }
    final hasCursor = active && tex.contains('#1A2530');
    if (!hasCursor) return _math(tex);
    return BlinkingCursorBuilder(
      builder: (context, on) => KeyedSubtree(
        key: ValueKey(on ? 'lcd_cursor_on' : 'lcd_cursor_off'),
        child: _math(LcdBlink.apply(tex, on: on, dark: _night)),
      ),
    );
  }

  Widget _math(String tex) {
    final math = Math.tex(
      LcdMathSanitizer.sanitizeForMathTex(tex),
      mathStyle: MathStyle.text,
      textStyle: TextStyle(color: textColor, fontSize: fontSize + 2, fontWeight: FontWeight.w700),
      onErrorFallback: (_) => Text(
        text ?? '',
        style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
      ),
    );
    if (expandable) return math;
    return FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: math);
  }
}
