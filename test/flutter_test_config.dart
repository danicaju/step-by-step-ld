import 'dart:async';

import 'package:casio_tutor_calc/core/editor/lcd_cursor.dart';
import 'package:casio_tutor_calc/presentation/widgets/lcd/lcd_blink.dart';

/// Desactiva el parpadeo del cursor en toda la suite (pumpAndSettle no se cuelga)
/// y registra el comando TeX del cursor de ancho cero para los tests que parsean LaTeX.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LcdBlink.enabled = false;
  LcdCursorTex.ensureRegistered();
  await testMain();
}
