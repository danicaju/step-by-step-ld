import 'dart:js_interop';
import 'dart:typed_data';

@JS('AudioContext')
extension type _JsAudioContext._(JSObject _) implements JSObject {
  external factory _JsAudioContext();
  external String get state;
  external double get currentTime;
  external _JsAudioDestinationNode get destination;
  external void resume();
  external _JsOscillatorNode createOscillator();
  external _JsGainNode createGain();
}

extension type _JsAudioDestinationNode._(JSObject _) implements JSObject {}

extension type _JsAudioParam._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double startTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
}

extension type _JsOscillatorNode._(JSObject _) implements JSObject {
  external set type(String value);
  external _JsAudioParam get frequency;
  external void connect(JSObject destination);
  external void start([double when]);
  external void stop([double when]);
}

extension type _JsGainNode._(JSObject _) implements JSObject {
  external _JsAudioParam get gain;
  external void connect(JSObject destination);
}

_JsAudioContext? _audioCtx;

bool isRunningInTest() => false;

void initClickBuffers(Uint8List controlWav, Uint8List standardWav) {}

void playMemClick(bool isControl, Uint8List wavBytes) {
  try {
    final ctx = _audioCtx ??= _JsAudioContext();
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
    final now = ctx.currentTime;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(isControl ? 180.0 : 320.0, now);
    gain.gain.setValueAtTime(isControl ? 0.14 : 0.10, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.012);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.013);
  } catch (_) {}
}
