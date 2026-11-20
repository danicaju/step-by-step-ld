import 'package:flutter/material.dart';

import '../../theme/theme_controller.dart';
import 'lcd_error_palette.dart';
import 'lcd_error_text.dart';

export 'lcd_error_text.dart';

/// Tipo de error mostrado dentro de la LCD (estilo Casio ClassWiz).
enum LcdErrorKind { syntax, math, dimension }

/// Pantalla de error nativa de la LCD: cabecera oscura con el tipo de error, tarjeta con
/// que ha pasado + como solucionarlo y barra de teclas fisicas (keycaps) para recuperarse.
class LcdErrorScreen extends StatelessWidget {
  final LcdErrorKind kind;
  final String message;

  /// Pista de solucion; si es `null` se deduce del mensaje.
  final String? hint;
  final bool isOledDark;

  const LcdErrorScreen({
    super.key,
    required this.kind,
    required this.message,
    this.hint,
    this.isOledDark = false,
  });

  static const Color _ink = Color(0xFF1A2530);
  static const Color _border = Color(0xFF7A8A7E);
  static const Color _alpha = Color(0xFFE05D5D);

  String get _title => switch (kind) {
        LcdErrorKind.syntax => 'Syntax ERROR',
        LcdErrorKind.math => 'Math ERROR',
        LcdErrorKind.dimension => 'Dimension ERROR',
      };

  @override
  Widget build(BuildContext context) {
    final p = LcdErrorPalette.of(ThemeController.current, dark: isOledDark);
    final info = LcdErrorText.info(message, syntax: kind == LcdErrorKind.syntax);
    final tip = LcdErrorText.capitalize(hint ?? info.hint);
    return Container(
      key: const Key('lcd_error_screen'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(8.5),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxHeight.isFinite && c.maxHeight < 120;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(compact, p),
              SizedBox(height: compact ? 3 : 6),
              Expanded(child: _card(LcdErrorText.capitalize(info.message), tip, p, compact)),
              SizedBox(height: compact ? 3 : 6),
              _keyBar(p.body, compact),
            ],
          );
        },
      ),
    );
  }

  Widget _header(bool compact, LcdErrorPalette p) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 1 : 5),
        decoration: BoxDecoration(
          color: p.header,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: p.icon, size: compact ? 16 : 26),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _title,
                  key: const Key('lcd_error_title'),
                  style: TextStyle(
                    color: p.title,
                    fontSize: compact ? 16 : 23,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(String msg, String tip, LcdErrorPalette p, bool compact) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 6),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border, width: 1),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg,
                key: const Key('lcd_error_message'),
                style: TextStyle(
                  color: p.body,
                  fontSize: compact ? 12 : 15.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: p.hintIcon, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Cómo solucionarlo: $tip',
                        key: const Key('lcd_error_hint'),
                        style: TextStyle(color: p.hint, fontSize: 13.5, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _keyBar(Color fg, bool compact) => Row(
        key: const Key('lcd_error_keybar'),
        children: [
          _keycap('[ ◀ ]', _ink, key: const Key('lcd_error_key_left'), compact: compact),
          const SizedBox(width: 4),
          _keycap('[ ▶ ]', _ink, key: const Key('lcd_error_key_right'), compact: compact),
          const SizedBox(width: 6),
          Expanded(child: _label('Volver a editar', fg, const Key('lcd_error_footer_edit'), compact)),
          const SizedBox(width: 6),
          _keycap('[ AC ]', _alpha, key: const Key('lcd_error_key_ac'), compact: compact),
          const SizedBox(width: 6),
          Expanded(child: _label('Borrar todo', fg, const Key('lcd_error_footer_clear'), compact)),
        ],
      );

  Widget _label(String text, Color fg, Key key, bool compact) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          key: key,
          style: TextStyle(color: fg, fontSize: compact ? 9.5 : 12, fontWeight: FontWeight.w700),
        ),
      );

  Widget _keycap(String text, Color edge, {required Key key, required bool compact}) => Container(
        key: key,
        padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 6, vertical: compact ? 1 : 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2F2D),
          borderRadius: BorderRadius.circular(5),
          border: Border(
            top: BorderSide(color: edge, width: 1),
            left: BorderSide(color: edge, width: 1),
            right: BorderSide(color: edge, width: 1),
            bottom: BorderSide(color: edge, width: 3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: const Color(0xFFE8EDE9),
            fontSize: compact ? 9.5 : 12.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      );
}
