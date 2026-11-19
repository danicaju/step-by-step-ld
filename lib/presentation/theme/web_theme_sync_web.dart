import 'dart:js_interop';

@JS('document')
external _Doc get _doc;

extension type _Doc._(JSObject _) implements JSObject {
  external JSObject? querySelector(String selector);
  external _El? get body;
  external _El? get documentElement;
}

extension type _El._(JSObject _) implements JSObject {
  external _Style get style;
  external void setAttribute(String name, String value);
}

extension type _Style._(JSObject _) implements JSObject {
  external set backgroundColor(String value);
}

/// Sincroniza el fondo de `html`/`body` y `<meta name="theme-color">` con el tema activo.
void syncWebTheme(String hex) {
  try {
    _doc.documentElement?.style.backgroundColor = hex;
    _doc.body?.style.backgroundColor = hex;
    (_doc.querySelector('meta[name="theme-color"]') as _El?)?.setAttribute('content', hex);
  } catch (_) {}
}
