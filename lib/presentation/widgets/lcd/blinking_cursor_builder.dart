import 'dart:async';

import 'package:flutter/widgets.dart';

/// Parpadeo del cursor de la LCD (530 ms) y color segun tema.
class LcdBlink {
  const LcdBlink._();

  /// `false` desactiva el temporizador (la suite de tests lo apaga para que
  /// `pumpAndSettle` no espere frames infinitos); el cursor queda siempre visible.
  static bool enabled = true;

  static const Duration period = Duration(milliseconds: 530);

  /// Contador de actividad: cada pulsacion de tecla o D-Pad lo incrementa y todos los
  /// cursores vuelven a estado visible (no desaparecen justo al escribir o moverse).
  static final ValueNotifier<int> activity = ValueNotifier<int>(0);

  /// Marca actividad del usuario (reinicia el ciclo de parpadeo a visible).
  static void markActivity() => activity.value++;

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

/// Reconstruye [builder] cada [LcdBlink.period] con el estado del cursor (visible/oculto).
///
/// Mecanica unica de parpadeo de toda la calculadora (LCD principal, casillas
/// `LcdInputBox`, formularios y editores). El ciclo vuelve a "visible" con cada
/// pulsacion ([LcdBlink.markActivity]) y el `Timer` se cancela en `dispose`.
class BlinkingCursorBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool cursorOn) builder;

  const BlinkingCursorBuilder({super.key, required this.builder});

  @override
  State<BlinkingCursorBuilder> createState() => _BlinkingCursorBuilderState();
}

class _BlinkingCursorBuilderState extends State<BlinkingCursorBuilder> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    LcdBlink.activity.addListener(_onActivity);
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!LcdBlink.enabled) return;
    _timer = Timer.periodic(LcdBlink.period, (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  void _onActivity() {
    if (!mounted) return;
    _restart();
    if (!_on) setState(() => _on = true);
  }

  @override
  void dispose() {
    LcdBlink.activity.removeListener(_onActivity);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _on);
}
