import 'dart:async';

import 'package:flutter/material.dart';

/// Parpadeo del cursor de la LCD (500 ms) y color segun tema.
class LcdBlink {
  const LcdBlink._();

  /// `false` desactiva el temporizador (la suite de tests lo apaga para que
  /// `pumpAndSettle` no espere frames infinitos).
  static bool enabled = true;

  static const Duration period = Duration(milliseconds: 500);
  static const String _cursorColor = '#1A2530';
  static const String _cursorColorOnDark = '#C8D6CD';

  /// Aplica el estado del parpadeo al LaTeX: apagado -> cursor invisible
  /// (`\phantom`); tema oscuro -> cursor claro.
  static String apply(String latex, {required bool on, required bool dark}) {
    if (!latex.contains(_cursorColor)) return latex;
    var out = latex;
    if (!on) {
      out = out
          .replaceAll('\\textcolor{$_cursorColor}{\\mid}', '\\phantom{\\mid}')
          .replaceAll('\\textcolor{$_cursorColor}{\\blacksquare}', '\\phantom{\\blacksquare}');
    }
    if (dark) out = out.replaceAll(_cursorColor, _cursorColorOnDark);
    return out;
  }
}

/// Reconstruye [builder] cada 500 ms con el estado del cursor (visible/oculto).
class LcdBlinkBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool cursorOn) builder;

  const LcdBlinkBuilder({super.key, required this.builder});

  @override
  State<LcdBlinkBuilder> createState() => _LcdBlinkBuilderState();
}

class _LcdBlinkBuilderState extends State<LcdBlinkBuilder> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    if (LcdBlink.enabled) {
      _timer = Timer.periodic(LcdBlink.period, (_) {
        if (mounted) setState(() => _on = !_on);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _on);
}
