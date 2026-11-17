import 'package:flutter/material.dart';

/// Tipo de error mostrado dentro de la LCD (estilo Casio ClassWiz).
enum LcdErrorKind { syntax, math }

/// Pantalla de error nativa de la LCD: `Syntax ERROR` / `Math ERROR`,
/// explicación en español y pie con las teclas para continuar.
class LcdErrorScreen extends StatelessWidget {
  final LcdErrorKind kind;
  final String message;
  final bool isOledDark;

  const LcdErrorScreen({
    super.key,
    required this.kind,
    required this.message,
    this.isOledDark = false,
  });

  static const Color _ink = Color(0xFF1A2530);

  @override
  Widget build(BuildContext context) {
    final Color bg = isOledDark ? const Color(0xFF111615) : const Color(0xFFC8D6CD);
    final Color fg = isOledDark ? const Color(0xFFE8F3EE) : _ink;
    final String title = kind == LcdErrorKind.syntax ? 'Syntax ERROR' : 'Math ERROR';
    return Container(
      key: const Key('lcd_error_screen'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.5),
        border: Border.all(color: const Color(0xFF7A8A7E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('lcd_error_title'),
            style: TextStyle(
              color: fg,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                message,
                key: const Key('lcd_error_message'),
                style: TextStyle(color: fg, fontSize: 13, height: 1.25),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: fg.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text(
            '[ ◀ ] [ ▶ ] : Volver a editar',
            key: const Key('lcd_error_footer_edit'),
            style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          Text(
            '[ AC ] : Borrar todo',
            key: const Key('lcd_error_footer_clear'),
            style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
