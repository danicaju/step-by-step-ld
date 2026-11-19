import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resultado final tocable: copia [copyText] al portapapeles y muestra la insignia
/// `Copiado` (estilo LCD) durante 1,8 s en la esquina de la tarjeta.
class LcdCopyableResult extends StatefulWidget {
  final Widget child;
  final String copyText;
  final bool enabled;
  final Color ink;
  final Color background;

  const LcdCopyableResult({
    super.key,
    required this.child,
    required this.copyText,
    this.enabled = true,
    this.ink = const Color(0xFF1A2530),
    this.background = const Color(0xFFC8D6CD),
  });

  @override
  State<LcdCopyableResult> createState() => _LcdCopyableResultState();
}

class _LcdCopyableResultState extends State<LcdCopyableResult> {
  static const Duration badgeDuration = Duration(milliseconds: 1800);
  Timer? _timer;
  bool _copied = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyText));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(badgeDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.copyText.trim().isEmpty) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('lcd_result_copy'),
        behavior: HitTestBehavior.opaque,
        onTap: _copy,
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: 0,
              right: 0,
              child: _copied
                  ? Container(
                      key: const Key('lcd_copied_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.ink,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Copiado',
                        style: TextStyle(
                          color: widget.background,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : Icon(
                      Icons.copy_rounded,
                      key: const Key('lcd_copy_icon'),
                      size: 11,
                      color: widget.ink.withValues(alpha: 0.45),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
