import 'dart:js_interop';

import 'hardware_sound_synthesizer.dart';

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external String get state;
  external double get currentTime;
  external JSObject get destination;
  external void resume();
  external _Osc createOscillator();
  external _Gain createGain();
}

extension type _Param._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

extension type _Osc._(JSObject _) implements JSObject {
  external set type(String value);
  external _Param get frequency;
  external void connect(JSObject destination);
  external void start([double when]);
  external void stop([double when]);
}

extension type _Gain._(JSObject _) implements JSObject {
  external _Param get gain;
  external void connect(JSObject destination);
}

_Ctx? _ctx;

/// Emite los impulsos con osciladores Web Audio (cero assets).
void playPulses(List<SoundPulse> pulses) {
  try {
    final ctx = _ctx ??= _Ctx();
    if (ctx.state == 'suspended') ctx.resume();
    final now = ctx.currentTime;
    for (final p in pulses) {
      final t0 = now + p.delay;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.type = p.wave;
      osc.frequency.setValueAtTime(p.freq, t0);
      gain.gain.setValueAtTime(p.gain, t0);
      gain.gain.exponentialRampToValueAtTime(0.001, t0 + p.duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + p.duration + 0.002);
    }
  } catch (_) {}
}
