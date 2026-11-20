import '../../core/rational.dart';
import '../exact/ext_expr.dart';
import 'sym_build.dart';

/// Derivadas "exteriores" f'(u) de las familias radical n-esima e hiperbolica.
///
/// La regla de la cadena (multiplicar por u') la aplica `SymDiff`.
class SymDiffRules {
  const SymDiffRules._();

  /// `d/du ⁿ√u = 1 / (n · ⁿ√(u^(n-1)))` (para n = 2: `1 / (2√u)`; n = 3: `1 / (3 ∛(u²))`).
  static XNode rootOuter(Rational n, XNode u) {
    final nInt = n.isInteger ? n.numerator : null;
    if (nInt == null || nInt < 2) {
      return Sx.mul(Sx.rat(n.pow(-1)), Sx.powR(u, n.pow(-1) - Rational(1)));
    }
    final XNode root = nInt == 2 ? XRoot(null, u) : XRoot(Sx.num(nInt), Sx.pow(u, Sx.num(nInt - 1)));
    return Sx.div(Sx.one, Sx.mul(Sx.num(nInt), root));
  }

  /// Derivada exterior de sinh, cosh, tanh y sus inversas; `null` si [name] no es hiperbolica.
  static XNode? hyperbolicOuter(String name, XNode u) {
    switch (name) {
      case 'sinh':
        return XFn('cosh', u);
      case 'cosh':
        return XFn('sinh', u);
      case 'tanh':
        return Sx.div(Sx.one, Sx.pow(XFn('cosh', u), Sx.num(2)));
      case 'asinh':
        return Sx.div(Sx.one, XRoot(null, Sx.add(Sx.pow(u, Sx.num(2)), Sx.one)));
      case 'acosh':
        return Sx.div(Sx.one, XRoot(null, Sx.sub(Sx.pow(u, Sx.num(2)), Sx.one)));
      case 'atanh':
        return Sx.div(Sx.one, Sx.sub(Sx.one, Sx.pow(u, Sx.num(2))));
      default:
        return null;
    }
  }
}
