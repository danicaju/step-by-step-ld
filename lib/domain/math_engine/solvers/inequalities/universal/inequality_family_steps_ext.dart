import '../../../models/step_resolution.dart';
import '../../exact/ext_expr.dart';
import '../inequality_sign.dart';
import 'inequality_family_detector.dart';
import 'numeric_function.dart';

/// Pasos didacticos de las familias nuevas: raices de indice n (impar y par >= 4),
/// trigonometricas inversas e hiperbolicas.
abstract final class InequalityFamilyStepsExt {
  static MathStep _st(String title, String latex, String note, [String? warn]) => MathStep(
        index: 0,
        shortTitle: title,
        latexExpression: latex,
        pedagogicalNote: note,
        warningTrick: warn,
      );

  static String _k(double v) => (v - v.roundToDouble()).abs() < 1e-12 ? '${v.round()}' : '$v';

  /// Primera raiz con x cuyo indice no es 2.
  static XRoot? _nth(XNode l, XNode r) {
    XRoot? found;
    void visit(XNode n) {
      if (found == null && n is XRoot && n.index != null && NumFn.hasX(n.rad)) {
        final i = n.index!;
        if (!(i is XNum && i.value.numerator == 2 && i.value.denominator == 1)) found = n;
      }
    }

    InequalityFamilyDetector.walk(l, visit);
    InequalityFamilyDetector.walk(r, visit);
    return found;
  }

  static XFn? _fn(XNode l, XNode r, Set<String> names) {
    XFn? found;
    void visit(XNode n) {
      if (found == null && n is XFn && names.contains(n.name) && NumFn.hasX(n.arg)) found = n;
    }

    InequalityFamilyDetector.walk(l, visit);
    InequalityFamilyDetector.walk(r, visit);
    return found;
  }

  static List<MathStep>? build(InequalityFamily fam, XNode l, XNode r, InequalitySign s) {
    switch (fam) {
      case InequalityFamily.radical:
        final root = _nth(l, r);
        return root == null ? null : _root(root, l, r, s);
      case InequalityFamily.inverseTrig:
        final f = _fn(l, r, const {'asin', 'acos', 'atan'});
        return f == null ? null : _inverse(f);
      case InequalityFamily.hyperbolic:
        final f = _fn(l, r, const {'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh'});
        return f == null ? null : _hyperbolic(f);
      default:
        return null;
    }
  }

  // ------------------------------------------------------------- raiz de indice n

  static List<MathStep> _root(XRoot root, XNode l, XNode r, InequalitySign s) {
    final n = (root.index as XNum).value.numerator;
    final even = n.isEven;
    final f = root.rad.latex();
    final rootLeft = identical(l, root), rootRight = identical(r, root);
    final other = rootLeft ? r : (rootRight ? l : null);
    final sg = rootLeft ? s : s.flipped();
    final k = other != null && !NumFn.hasX(other) ? NumFn.eval(other, 0) : null;
    final head = '\\sqrt[$n]{$f}';
    final steps = <MathStep>[];
    if (even) {
      steps.add(_st(
        'Dominio de la raiz de indice par',
        '$f \\ge 0',
        'Una raíz de índice par solo existe si el radicando es mayor o igual que 0, y su valor nunca es negativo.',
      ));
    } else {
      steps.add(_st(
        'Raiz de indice impar: sin restriccion de dominio',
        '$head \\in \\mathbb{R} \\quad \\text{para todo } x',
        'Una raíz de índice impar existe para cualquier radicando, también negativo, y conserva su signo: la raíz cúbica de un número negativo es negativa.',
        'No restrinjas el dominio exigiendo radicando ≥ 0: eso solo se hace con índice par.',
      ));
    }
    if (k != null) {
      final up = sg == InequalitySign.greater || sg == InequalitySign.greaterOrEqual;
      if (even && k < 0) {
        steps.add(_st(
          'Una raiz de indice par nunca es negativa',
          '$head ${sg.latex} ${_k(k)} \\iff ${up ? '\\text{se cumple en todo el dominio}' : '\\text{ningun valor lo cumple}'}',
          up
              ? 'La raíz es siempre mayor o igual que 0 y el segundo miembro es negativo: la desigualdad se cumple en todo el dominio.'
              : 'La raíz no puede ser menor que un número negativo: no hay solución.',
        ));
      } else {
        final power = _pow(k, n);
        steps.add(_st(
          even ? 'Elevar a la potencia $n (ambos miembros no negativos)' : 'Elevar a la potencia $n',
          '$head ${sg.latex} ${_k(k)} \\iff $f ${sg.latex} ${_k(power)}',
          even
              ? 'Como la raíz y ${_k(k)} no son negativos, elevar a $n conserva el sentido. Después se intersecta con el dominio.'
              : 'La función x elevado a $n es creciente en todo ℝ cuando $n es impar, así que elevar a $n NO cambia el sentido de la desigualdad.',
        ));
      }
    } else {
      steps.add(_st(
        'Estudiar el signo de f(x)',
        'f(x) ${s.latex} 0',
        'Pasamos todo al primer miembro y estudiamos el signo de f(x) con sus ceros y los extremos del dominio.',
      ));
    }
    return steps;
  }

  static double _pow(double b, int n) {
    var acc = 1.0;
    for (var i = 0; i < n; i++) {
      acc *= b;
    }
    return acc;
  }

  // ------------------------------------------------------------ inversas e hiperbolicas

  static List<MathStep> _inverse(XFn f) {
    final arg = f.arg.latex();
    switch (f.name) {
      case 'atan':
        return [
          _st(
            'arctan: dominio y rango',
            '\\arctan\\left($arg\\right) \\in \\left(-\\frac{\\pi}{2},\\, \\frac{\\pi}{2}\\right) \\quad \\text{definida para todo } x',
            'El arco tangente está definido para todo número real, es creciente y su valor queda siempre entre -π/2 y π/2 (entre -90 y 90 en grados).',
          ),
        ];
      case 'acos':
        return [
          _st(
            'arccos: dominio y rango',
            '-1 \\le $arg \\le 1 \\quad \\arccos\\left($arg\\right) \\in [0,\\, \\pi]',
            'El arco coseno solo existe si el argumento está entre -1 y 1. Es decreciente y su valor queda entre 0 y π (0 y 180 en grados).',
            'Fuera de [-1, 1] la función no existe, aunque la desigualdad parezca cumplirse.',
          ),
        ];
      default:
        return [
          _st(
            'arcsin: dominio y rango',
            '-1 \\le $arg \\le 1 \\quad \\arcsin\\left($arg\\right) \\in \\left[-\\frac{\\pi}{2},\\, \\frac{\\pi}{2}\\right]',
            'El arco seno solo existe si el argumento está entre -1 y 1. Es creciente y su valor queda entre -π/2 y π/2 (entre -90 y 90 en grados).',
            'Fuera de [-1, 1] la función no existe: la solución debe estar dentro de ese dominio.',
          ),
        ];
    }
  }

  static List<MathStep> _hyperbolic(XFn f) {
    final arg = f.arg.latex();
    switch (f.name) {
      case 'cosh':
        return [
          _st(
            'cosh: valor minimo 1',
            '\\cosh\\left($arg\\right) \\ge 1 \\quad \\text{con igualdad solo si } $arg = 0',
            'El coseno hiperbólico es siempre mayor o igual que 1 y vale 1 únicamente cuando su argumento es 0. Es una función par.',
            'Con cosh x > 1 el único valor excluido es el que hace el argumento 0.',
          ),
        ];
      case 'tanh':
        return [
          _st(
            'tanh: queda entre -1 y 1',
            '-1 < \\tanh\\left($arg\\right) < 1',
            'La tangente hiperbólica es creciente y sus valores quedan estrictamente entre -1 y 1, sin llegar a tocarlos. Es una función impar.',
          ),
        ];
      case 'sinh':
        return [
          _st(
            'sinh: creciente y con imagen R',
            '\\sinh\\left($arg\\right) \\in \\mathbb{R} \\quad \\sinh(0) = 0',
            'El seno hiperbólico es creciente, impar y toma todos los valores reales; solo vale 0 cuando su argumento es 0.',
          ),
        ];
      default:
        return [
          _st(
            'Funcion hiperbolica inversa',
            'f(x)',
            'Las inversas hiperbólicas se definen con logaritmos; se estudia su dominio y el signo de f(x).',
          ),
        ];
    }
  }
}
