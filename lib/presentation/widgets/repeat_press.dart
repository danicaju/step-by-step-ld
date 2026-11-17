import 'dart:async';

import 'package:flutter/foundation.dart';

/// Auto-repeticion al mantener pulsada una tecla fisica (D-Pad y DEL).
///
/// Tras [delay] dispara [onRepeat] y despues cada [period] hasta [cancel].
/// [fired] indica si ya hubo repeticion para no sumar un toque extra al soltar.
class RepeatPress {
  static const Duration delay = Duration(milliseconds: 400);
  static const Duration period = Duration(milliseconds: 70);

  Timer? _delayTimer;
  Timer? _tickTimer;
  bool fired = false;

  void start(VoidCallback onRepeat) {
    cancel();
    fired = false;
    _delayTimer = Timer(delay, () {
      fired = true;
      onRepeat();
      _tickTimer = Timer.periodic(period, (_) => onRepeat());
    });
  }

  void cancel() {
    _delayTimer?.cancel();
    _tickTimer?.cancel();
    _delayTimer = null;
    _tickTimer = null;
  }
}
