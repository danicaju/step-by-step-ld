import 'dart:async';

import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_blink.dart';

/// Desactiva el parpadeo del cursor en toda la suite (pumpAndSettle no se cuelga).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LcdBlink.enabled = false;
  await testMain();
}
