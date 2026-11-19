import 'blinking_cursor_builder.dart';

export 'blinking_cursor_builder.dart';

/// Parpadeo de la LCD principal: envoltorio fino de [BlinkingCursorBuilder].
class LcdBlinkBuilder extends BlinkingCursorBuilder {
  const LcdBlinkBuilder({super.key, required super.builder});
}
