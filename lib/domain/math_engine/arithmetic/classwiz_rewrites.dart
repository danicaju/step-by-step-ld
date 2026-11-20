import '../parser/balanced_scan.dart';
import '../solvers/trig_and_angles_solver.dart';

/// Reescrituras previas a evaluar (menu OPTN): sufijos de ingenieria y
/// sufijos angulares `r` / `g`.
///
/// - `5#k` -> `5*(1000)`; `#M #G #m #u #n` analogos (exactos).
/// - `N#r` / `N#g` -> N convertido a la unidad angular activa.
class ClassWizRewrites {
  const ClassWizRewrites._();

  static const Map<String, String> _suffix = {
    'k': '1000',
    'M': '1000000',
    'G': '1000000000',
    'm': '1/1000',
    'u': '1/1000000',
    'n': '1/1000000000',
  };

  static final RegExp _suffixRe = RegExp(r'#([kMGmun])');
  static final RegExp _angleRe = RegExp(r'#([rg])');

  /// Aplica todas las reescrituras en orden. Las hiperbolicas ya no se
  /// reescriben: las evalua de forma nativa el motor extendido (`ExtHyperbolic`).
  static String prepare(String input, AngleUnit unit) {
    var out = rewriteAngleSuffix(input, unit);
    out = out.replaceAllMapped(_suffixRe, (m) => '*(${_suffix[m.group(1)]})');
    return out;
  }

  static bool needsRewrite(String s) => s.contains('#');

  static final RegExp _hypRe = RegExp(r'(sinh|cosh|tanh)\(');

  /// Forma exponencial de `sinh/cosh/tanh` (ya no se usa en `prepare`; se
  /// conserva como utilidad de referencia).
  static String rewriteHyperbolics(String s) {
    var out = s;
    while (true) {
      final m = _hypRe.firstMatch(out);
      if (m == null) return out;
      final open = m.end - 1;
      final close = BalancedScan.findClose(out, open);
      final inner = rewriteHyperbolics(
        close == null ? out.substring(open + 1) : out.substring(open + 1, close),
      );
      final pos = 'ℯ^($inner)';
      final neg = 'ℯ^(-($inner))';
      final repl = switch (m.group(1)) {
        'sinh' => '(($pos-$neg)/2)',
        'cosh' => '(($pos+$neg)/2)',
        _ => '(($pos-$neg)/($pos+$neg))',
      };
      out = out.substring(0, m.start) + repl + (close == null ? '' : out.substring(close + 1));
    }
  }

  /// Convierte el operando anterior a `#r` / `#g` a la unidad angular activa.
  static String rewriteAngleSuffix(String s, AngleUnit unit) {
    var out = s;
    while (true) {
      final m = _angleRe.firstMatch(out);
      if (m == null) return out;
      var start = m.start;
      if (start > 0 && out[start - 1] == ')') {
        var depth = 0;
        for (var i = start - 1; i >= 0; i--) {
          if (out[i] == ')') depth++;
          if (out[i] == '(') {
            depth--;
            if (depth == 0) {
              start = i;
              break;
            }
          }
        }
      } else {
        while (start > 0 && RegExp(r'[0-9.]').hasMatch(out[start - 1])) {
          start--;
        }
      }
      final operand = out.substring(start, m.start);
      final fromRad = m.group(1) == 'r';
      final factor = switch ((fromRad, unit)) {
        (true, AngleUnit.deg) => '180/π',
        (true, AngleUnit.grad) => '200/π',
        (false, AngleUnit.deg) => '9/10',
        (false, AngleUnit.rad) => 'π/200',
        _ => '1',
      };
      out = '${out.substring(0, start)}($operand*$factor)${out.substring(m.end)}';
    }
  }
}
