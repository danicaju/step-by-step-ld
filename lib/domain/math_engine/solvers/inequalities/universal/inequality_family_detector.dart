import '../../exact/ext_expr.dart';
import 'numeric_function.dart';

/// Familia de una inecuacion en `x` (determina los pasos didacticos previos al estudio de signos).
enum InequalityFamily { radical, logarithmic, exponential, absolute, trigonometric, inverseTrig, hyperbolic, mixed, general }

/// Utilidades de analisis del AST de una inecuacion.
abstract final class InequalityFamilyDetector {
  /// Recorre todos los nodos del arbol.
  static void walk(XNode n, void Function(XNode) visit) {
    visit(n);
    switch (n) {
      case XNeg(:final a) || XAbs(:final a) || XFact(:final a):
        walk(a, visit);
      case XBin(:final l, :final r):
        walk(l, visit);
        walk(r, visit);
      case XPow(:final base, :final exp):
        walk(base, visit);
        walk(exp, visit);
      case XRoot(:final index, :final rad):
        if (index != null) walk(index, visit);
        walk(rad, visit);
      case XFn(:final arg, :final base):
        walk(arg, visit);
        if (base != null) walk(base, visit);
      case XComb(n: final cn, r: final cr):
        walk(cn, visit);
        walk(cr, visit);
      default:
        break;
    }
  }

  static InequalityFamily detect(XNode lhs, XNode rhs) {
    var hasRad = false, hasLog = false, hasExp = false, hasAbs = false, hasTrig = false;
    var hasInv = false, hasHyp = false;
    void visit(XNode n) {
      switch (n) {
        case XRoot(:final rad) when NumFn.hasX(rad):
          hasRad = true;
        case XFn(:final name, :final arg) when NumFn.hasX(arg):
          if (name == 'ln' || name == 'log') {
            hasLog = true;
          } else if (const {'asin', 'acos', 'atan'}.contains(name)) {
            hasInv = true;
          } else if (const {'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh'}.contains(name)) {
            hasHyp = true;
          } else {
            hasTrig = true;
          }
        case XPow(:final exp) when NumFn.hasX(exp):
          hasExp = true;
        case XPow(:final base, :final exp) when NumFn.hasX(base) && exp is XNum && exp.value.denominator != 1:
          hasRad = true;
        case XAbs(:final a) when NumFn.hasX(a):
          hasAbs = true;
        default:
          break;
      }
    }

    walk(lhs, visit);
    walk(rhs, visit);
    final count = [hasRad, hasLog, hasExp, hasAbs, hasTrig, hasInv, hasHyp].where((b) => b).length;
    if (count == 0) return InequalityFamily.general;
    if (count > 1) return InequalityFamily.mixed;
    if (hasTrig) return InequalityFamily.trigonometric;
    if (hasInv) return InequalityFamily.inverseTrig;
    if (hasHyp) return InequalityFamily.hyperbolic;
    if (hasRad) return InequalityFamily.radical;
    if (hasLog) return InequalityFamily.logarithmic;
    if (hasExp) return InequalityFamily.exponential;
    return InequalityFamily.absolute;
  }

  /// `true` si el arbol contiene alguna variable (x, y o z).
  static bool _hasVar(XNode n) {
    var found = false;
    walk(n, (v) {
      if (v is XVar) found = true;
    });
    return found;
  }

  /// Condiciones de existencia de la funcion (LaTeX), p. ej. `x+3 \ge 0`, `x-2 > 0`, `x+2 \ne 0`.
  static List<String> domainConditions(XNode n) {
    final out = <String>[];
    void add(String c) {
      if (!out.contains(c)) out.add(c);
    }

    walk(n, (node) {
      switch (node) {
        case XRoot(:final index, :final rad) when _hasVar(rad):
          final even = index == null || (index is XNum && index.value.numerator.isEven);
          if (even) add('${rad.latex()} \\ge 0');
        case XFn(:final name, :final arg) when _hasVar(arg):
          if (name == 'ln' || name == 'log') add('${arg.latex()} > 0');
          if (name == 'asin' || name == 'acos') add('-1 \\le ${arg.latex()} \\le 1');
          if (name == 'acosh') add('${arg.latex()} \\ge 1');
          if (name == 'atanh') add('-1 < ${arg.latex()} < 1');
        case XBin(:final op, :final r) when op == '/' && _hasVar(r):
          add('${r.latex()} \\ne 0');
        case XPow(:final base, :final exp) when _hasVar(base) && exp is XNum && exp.value.denominator != 1:
          if (exp.value.denominator.isEven) add('${base.latex()} \\ge 0');
        default:
          break;
      }
    });
    return out;
  }

  /// Bases numericas de logaritmos y potencias (para reconocer `log_a(t)` en las etiquetas).
  static List<double> numericBases(XNode a, XNode b) {
    final bases = <double>[];
    void visit(XNode n) {
      XNode? base;
      if (n is XFn && n.name == 'log') base = n.base;
      if (n is XPow && NumFn.hasX(n.exp)) base = n.base;
      if (base != null) {
        final v = NumFn.eval(base, 0);
        if (v != null && v > 0 && v != 1 && !bases.contains(v)) bases.add(v);
      }
      if (n is XFn && n.name == 'log' && n.base == null && !bases.contains(10.0)) bases.add(10);
    }

    walk(a, visit);
    walk(b, visit);
    return bases;
  }
}
