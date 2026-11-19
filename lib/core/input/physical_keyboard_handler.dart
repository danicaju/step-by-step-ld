import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/utils/key_click_sound.dart';
import 'physical_key_translator.dart';

/// Envuelve la app con un `Focus` que convierte el teclado fisico en pulsaciones de la
/// calculadora (con su sonido y haptica). Escucha `KeyDownEvent` y `KeyRepeatEvent`.
class PhysicalKeyboardHandler extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onKey;
  final ValueChanged<String> onDpad;
  final VoidCallback onUndo;

  const PhysicalKeyboardHandler({
    super.key,
    required this.child,
    required this.onKey,
    required this.onDpad,
    required this.onUndo,
  });

  @override
  State<PhysicalKeyboardHandler> createState() => _PhysicalKeyboardHandlerState();
}

class _PhysicalKeyboardHandlerState extends State<PhysicalKeyboardHandler> {
  final PhysicalKeyTranslator _translator = PhysicalKeyTranslator();
  final FocusNode _node = FocusNode(debugLabel: 'physical_keyboard');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final hk = HardwareKeyboard.instance;
    final actions = _translator.translate(
      logical: event.logicalKey,
      character: event.character,
      shift: hk.isShiftPressed,
      ctrlOrMeta: hk.isControlPressed || hk.isMetaPressed,
      alt: hk.isAltPressed,
    );
    if (actions == null) return KeyEventResult.ignored;
    if (actions.isNotEmpty) HapticFeedback.lightImpact();
    for (final a in actions) {
      switch (a.kind) {
        case PhysicalActionKind.key:
          KeyClickSound.playForLabel(a.value);
          widget.onKey(a.value);
        case PhysicalActionKind.dpad:
          KeyClickSound.playDpad();
          widget.onDpad(a.value);
        case PhysicalActionKind.undo:
          widget.onUndo();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, autofocus: true, onKeyEvent: _onKeyEvent, child: widget.child);
}
