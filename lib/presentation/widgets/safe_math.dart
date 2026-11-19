import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/editor/latex_render_sanitizer.dart';
import '../../core/editor/lcd_cursor.dart';
import '../../core/editor/lcd_cursor_tokens.dart';
import '../utils/latex_plain_text.dart';

/// Unico punto de entrada para pintar LaTeX en la app (sustituye a `Math.tex`).
///
/// * Pasa la formula por [LatexRenderSanitizer] (llaves, `\left`/`\right`, escapes).
/// * Registra el cursor de ancho cero `\lcdcursor`.
/// * Si aun asi el parser falla, muestra TEXTO PLANO legible: jamas comandos TeX
///   (`\textcolor`, `\left`, `\right`, `\mid`, `extcolor`...).
abstract final class SafeMath {
  static final RegExp _command = RegExp(r'\\[a-zA-Z]+');
  static final RegExp _junk = RegExp('[\\\\{}\x00-\x1F\x7F]');

  /// Texto plano a prueba de comandos para el `onErrorFallback`.
  static String plain(String latex) {
    var s = LcdCursor.strip(latex).replaceAll(r'\lcdcursor', '');
    s = LatexPlainText.toPlain(s)
        .replaceAll(_command, '')
        .replaceAll('extcolor', '')
        .replaceAll(_junk, '');
    return s.trim();
  }

  static Widget tex(
    String latex, {
    TextStyle? textStyle,
    MathStyle mathStyle = MathStyle.display,
  }) {
    LcdCursorTex.ensureRegistered();
    return Math.tex(
      LatexRenderSanitizer.sanitize(latex),
      mathStyle: mathStyle,
      textStyle: textStyle,
      onErrorFallback: (_) => Text(plain(latex), style: textStyle),
    );
  }
}
