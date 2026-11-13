import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'key_click_sound_stub.dart'
    if (dart.library.io) 'key_click_sound_io.dart'
    if (dart.library.js_interop) 'key_click_sound_web.dart' as platform;

/// Perfil acústico del clic mecánico sintetizado en RAM para teclas Casio.
enum KeyClickTone {
  /// Teclas de control y navegación (`=`, `AC`, `DEL`, `SHIFT`, `ALPHA`, `MODE`, `CALC`, D-Pad).
  control(frequencyHz: 180.0, decaySeconds: 0.0032, amplitude: 0.48),

  /// Teclas numéricas, operadores aritméticos y funciones científicas.
  standard(frequencyHz: 320.0, decaySeconds: 0.0024, amplitude: 0.36);

  final double frequencyHz;
  final double decaySeconds;
  final double amplitude;

  const KeyClickTone({
    required this.frequencyHz,
    required this.decaySeconds,
    required this.amplitude,
  });
}

/// Sintetizador de clic mecánico en memoria (~12 ms PCM/WAV 16-bit mono, cero assets).
///
/// Genera dos pulsos amortiguados distintos (~180 Hz para control y ~320 Hz para
/// dígitos/operadores), respeta el botón de silencio de la LCD y se mantiene
/// inactivo durante tests unitarios/widget para evitar plugins o audio externo.
abstract final class KeyClickSound {
  static const int sampleRateHz = 44100;
  static const int durationMs = 12;
  static const int sampleCount = 529; // (44100 * 12) ~/ 1000

  static final ValueNotifier<bool> _mutedNotifier = ValueNotifier<bool>(false);

  static final Uint8List _controlWav = buildWavBytes(KeyClickTone.control);
  static final Uint8List _standardWav = buildWavBytes(KeyClickTone.standard);
  static bool _nativeReady = false;

  static const Set<String> _controlLabels = {
    '=',
    'AC',
    'DEL',
    'SHIFT',
    'ALPHA',
    'MODE',
    'MENU',
    'SETUP',
    'CALC',
    'OPTN',
    'ON',
    '▲',
    '▼',
    '◀',
    '▶',
    'REPLAY',
  };

  /// Estado reactivo de silencio para sincronizar iconos en la LCD.
  static ValueListenable<bool> get mutedListenable => _mutedNotifier;

  /// Indica si el clic acústico del teclado está silenciado.
  static bool get isMuted => _mutedNotifier.value;

  /// Actualiza el estado de silencio del sintetizador.
  static void setMuted(bool muted) {
    if (_mutedNotifier.value != muted) {
      _mutedNotifier.value = muted;
    }
  }

  /// Alterna entre sonido activo y silencio devolviendo el nuevo estado.
  static bool toggleMute() {
    final next = !_mutedNotifier.value;
    _mutedNotifier.value = next;
    return next;
  }

  /// Determina el tono mecánico apropiado según la etiqueta de la tecla pulsada.
  static KeyClickTone resolveToneForLabel(String label) {
    final normalized = label.trim().toUpperCase();
    return _controlLabels.contains(normalized)
        ? KeyClickTone.control
        : KeyClickTone.standard;
  }

  /// Reproduce el clic mecánico correspondiente a [label] si no está silenciado.
  static void playForLabel(String label) {
    play(resolveToneForLabel(label));
  }

  /// Reproduce un clic mecánico de tecla de control (~180 Hz).
  static void playControl() => play(KeyClickTone.control);

  /// Reproduce un clic mecánico de tecla numérica o científica (~320 Hz).
  static void playStandard() => play(KeyClickTone.standard);

  /// Emite de forma asíncrona y sin bloqueo el pulso WAV sintetizado en memoria.
  static void play(KeyClickTone tone) {
    if (_mutedNotifier.value || _isRunningUnderFlutterTest) {
      return;
    }
    _ensureInitialized();
    final wav = tone == KeyClickTone.control ? _controlWav : _standardWav;
    platform.playMemClick(tone == KeyClickTone.control, wav);
  }

  static bool get _isRunningUnderFlutterTest => platform.isRunningInTest();

  static void _ensureInitialized() {
    if (_nativeReady) return;
    _nativeReady = true;
    platform.initClickBuffers(_controlWav, _standardWav);
  }

  /// Sintetiza un buffer RIFF/WAV PCM 16-bit mono (~12 ms) para [tone].
  ///
  /// Incluye ataque ultrarrápido de 0.3 ms para nitidez de micro-interruptor
  /// y caída exponencial rápida hasta silencio total antes del final del bloque.
  static Uint8List buildWavBytes(KeyClickTone tone) {
    const int headerBytes = 44;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);
    const int byteRate = sampleRateHz * blockAlign;
    const int dataBytes = sampleCount * blockAlign;
    const int totalBytes = headerBytes + dataBytes;

    final byteData = ByteData(totalBytes);
    final bytes = byteData.buffer.asUint8List();

    // Cabecera RIFF
    _writeAscii(bytes, 0, 'RIFF');
    byteData.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');

    // Bloque fmt
    _writeAscii(bytes, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // PCM chunk size
    byteData.setUint16(20, 1, Endian.little); // Linear PCM
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRateHz, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // Bloque data
    _writeAscii(bytes, 36, 'data');
    byteData.setUint32(40, dataBytes, Endian.little);

    const double attackSeconds = 0.00035;
    final double totalSeconds = sampleCount / sampleRateHz;

    for (int i = 0; i < sampleCount; i++) {
      final double t = i / sampleRateHz;
      final double attackEnv =
          t < attackSeconds ? (t / attackSeconds) : 1.0;
      final double decayEnv = math.exp(-t / tone.decaySeconds);
      // Apagado suave en el último milisegundo para evitar chasquido residual.
      final double tailProgress =
          ((t - (totalSeconds - 0.0012)) / 0.0012).clamp(0.0, 1.0);
      final double tailFade = 1.0 - tailProgress;

      // Fundamental mecánico + armónico amortiguado de contacto táctil.
      final double fundamental =
          math.sin(2.0 * math.pi * tone.frequencyHz * t);
      final double harmonic = 0.25 *
          math.sin(2.0 * math.pi * (tone.frequencyHz * 2.4) * t) *
          math.exp(-t / 0.0009);

      final double sample =
          (fundamental + harmonic) * tone.amplitude * attackEnv * decayEnv * tailFade;
      final int pcm16 = (sample * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(headerBytes + i * 2, pcm16, Endian.little);
    }

    return bytes;
  }

  static void _writeAscii(Uint8List target, int offset, String ascii) {
    for (int i = 0; i < ascii.length; i++) {
      target[offset + i] = ascii.codeUnitAt(i);
    }
  }
}
