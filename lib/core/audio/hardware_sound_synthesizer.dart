import 'package:flutter/foundation.dart';

import 'hardware_sound_stub.dart'
    if (dart.library.js_interop) 'hardware_sound_web.dart' as platform;

/// Perfil acustico de las teclas (uno por tema de hardware).
enum KeySoundProfile { defaultOriginal, softSilicone, retroMechanical, minimalChiclet, studioCrisp }

/// Categoria de la pulsacion: cada perfil responde distinto segun la tecla.
enum SoundCategory { digit, control, dpad, equals, delete }

/// Un impulso del sintetizador Web Audio: oscilador con caida exponencial.
class SoundPulse {
  final String wave;
  final double freq;
  final double gain;
  final double delay;
  final double duration;
  const SoundPulse(this.wave, this.freq, this.gain, this.duration, {this.delay = 0});
}

/// Opciones del ajuste `Sonido Teclas` de SETUP (0 = segun tema).
const List<String> kKeySoundOptionLabels = [
  'Segun tema',
  'Original',
  'Silicona Suave',
  'Retro Mecanico',
  'Chiclet',
  'Estudio',
];

/// Sintetizador ligero de los perfiles de sonido por tema (solo web; en VM/tests registra el evento).
abstract final class HardwareSoundSynthesizer {
  /// Perfil asociado al tema activo.
  static KeySoundProfile themeProfile = KeySoundProfile.defaultOriginal;

  /// Sobrescritura desde SETUP (`null` = segun tema).
  static KeySoundProfile? override;

  static KeySoundProfile get effective => override ?? themeProfile;

  /// Ultimo evento emitido (no silenciado); sirve para verificar en tests.
  static ({KeySoundProfile profile, SoundCategory category})? lastEvent;

  static int get overrideIndex => override == null ? 0 : override!.index + 1;

  static void setOverrideIndex(int i) {
    override = i <= 0 ? null : KeySoundProfile.values[(i - 1).clamp(0, KeySoundProfile.values.length - 1)];
  }

  static SoundCategory categoryForLabel(String label) {
    final l = label.trim().toUpperCase();
    if (l == '=') return SoundCategory.equals;
    if (l == 'DEL' || l == 'AC') return SoundCategory.delete;
    if (const {'▲', '▼', '◀', '▶', 'REPLAY'}.contains(l)) return SoundCategory.dpad;
    if (const {'SHIFT', 'ALPHA', 'MODE', 'MENU', 'SETUP', 'CALC', 'OPTN', 'ON'}.contains(l)) {
      return SoundCategory.control;
    }
    return SoundCategory.digit;
  }

  /// Impulsos de [profile] para [category]. `defaultOriginal` no sintetiza (usa `KeyClickSound`).
  static List<SoundPulse> pulsesFor(KeySoundProfile profile, SoundCategory c) {
    switch (profile) {
      case KeySoundProfile.defaultOriginal:
        return const [];
      case KeySoundProfile.softSilicone:
        return switch (c) {
          SoundCategory.equals => const [
              SoundPulse('sine', 523, 0.10, 0.09),
              SoundPulse('sine', 659, 0.08, 0.11, delay: 0.045),
            ],
          SoundCategory.delete => const [SoundPulse('triangle', 130, 0.13, 0.08)],
          SoundCategory.control || SoundCategory.dpad => const [SoundPulse('sine', 200, 0.10, 0.06)],
          SoundCategory.digit => const [SoundPulse('triangle', 260, 0.09, 0.05)],
        };
      case KeySoundProfile.retroMechanical:
        return switch (c) {
          SoundCategory.equals => const [
              SoundPulse('square', 1900, 0.05, 0.012),
              SoundPulse('square', 3200, 0.045, 0.16, delay: 0.02),
            ],
          _ => [
              const SoundPulse('square', 900, 0.06, 0.006),
              SoundPulse('square', c == SoundCategory.delete ? 150 : 240, 0.09, 0.012, delay: 0.018),
            ],
        };
      case KeySoundProfile.minimalChiclet:
        return switch (c) {
          SoundCategory.equals => const [SoundPulse('sine', 520, 0.07, 0.03)],
          SoundCategory.delete => const [SoundPulse('sine', 280, 0.07, 0.025)],
          _ => const [SoundPulse('sine', 420, 0.05, 0.018)],
        };
      case KeySoundProfile.studioCrisp:
        return switch (c) {
          SoundCategory.equals => const [
              SoundPulse('triangle', 880, 0.09, 0.025),
              SoundPulse('sine', 1320, 0.06, 0.03, delay: 0.012),
            ],
          SoundCategory.dpad || SoundCategory.control => const [SoundPulse('triangle', 560, 0.08, 0.014)],
          SoundCategory.delete => const [SoundPulse('triangle', 340, 0.09, 0.016)],
          SoundCategory.digit => const [SoundPulse('triangle', 740, 0.08, 0.012)],
        };
    }
  }

  /// Reproduce la pulsacion de [label] con el perfil efectivo (si [muted] no emite nada).
  static void playForLabel(String label, {required bool muted}) =>
      playCategory(categoryForLabel(label), muted: muted);

  static void playCategory(SoundCategory c, {required bool muted}) {
    if (muted) return;
    final profile = effective;
    lastEvent = (profile: profile, category: c);
    if (!kIsWeb) return;
    final pulses = pulsesFor(profile, c);
    if (pulses.isNotEmpty) platform.playPulses(pulses);
  }
}
