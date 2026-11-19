import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/hardware_sound_synthesizer.dart';
import 'calculator_themes.dart';
import 'web_theme_sync_stub.dart' if (dart.library.js_interop) 'web_theme_sync_web.dart' as web_sync;

/// Tema de hardware activo, persistido en `SharedPreferences` (`selected_hardware_theme`).
///
/// Cambiar de tema activa su perfil acustico, salvo que SETUP fije otro (`key_sound_override`).
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const String themeKey = 'selected_hardware_theme';
  static const String soundKey = 'key_sound_override';

  CalculatorHardwareTheme _theme = HardwareThemes.defaultTheme;

  /// Tema activo (lectura estatica para los widgets de dibujo).
  static CalculatorHardwareTheme get current => instance._theme;

  /// Carga las preferencias guardadas (tolerante a fallos de almacenamiento).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      HardwareSoundSynthesizer.setOverrideIndex(prefs.getInt(soundKey) ?? 0);
      select(HardwareThemes.byId(prefs.getString(themeKey)), persist: false);
    } catch (_) {
      select(_theme, persist: false);
    }
  }

  void select(CalculatorHardwareTheme theme, {bool persist = true}) {
    _theme = theme;
    HardwareSoundSynthesizer.themeProfile = theme.sound;
    web_sync.syncWebTheme(theme.webColorHex);
    notifyListeners();
    if (persist) _save((p) => p.setString(themeKey, theme.id));
  }

  /// `Sonido Teclas` de SETUP: 0 = segun tema, 1.. = perfil fijo.
  void setSoundOverride(int index) {
    HardwareSoundSynthesizer.setOverrideIndex(index);
    notifyListeners();
    _save((p) => p.setInt(soundKey, index));
  }

  /// Vuelve a `Predeterminado` sin persistir (tests y restauracion).
  void resetForTests() {
    HardwareSoundSynthesizer.override = null;
    HardwareSoundSynthesizer.lastEvent = null;
    select(HardwareThemes.defaultTheme, persist: false);
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }
}
