/// Elemento insertable desde OPTN: texto del buffer (`sinh(`, `ℯ`...) y su rotulo.
class OptnToken {
  final String token;
  final String label;
  final String? detail;
  const OptnToken(this.token, this.label, {this.detail});
}

/// Seccion ordenada del menu OPTN (Constantes, Trig. inversas, Hiperbolicas, Funciones).
class OptnTokenSection {
  final String id;
  final String title;
  final List<OptnToken> items;
  const OptnTokenSection(this.id, this.title, this.items);
}

/// Tabla unica de funciones y constantes accesibles en todos los modos con entrada
/// matematica. Cada elemento se envia como tecla `tok:<token>`.
class OptnTokenSections {
  const OptnTokenSections._();

  /// Prefijo de la tecla virtual que inserta un texto tal cual.
  static const String keyPrefix = 'tok:';

  static String keyFor(String token) => '$keyPrefix$token';

  static const OptnTokenSection constants = OptnTokenSection('cte', 'Constantes', [
    OptnToken('ℯ', 'ℯ', detail: 'número e'),
    OptnToken('ℯ^(', 'ℯ^■', detail: 'exponencial'),
    OptnToken('π', 'π', detail: 'pi'),
  ]);

  static const OptnTokenSection inverseTrig = OptnTokenSection('inv', 'Trig. Inversas', [
    OptnToken('arcsin(', 'arcsin', detail: 'sin⁻¹'),
    OptnToken('arccos(', 'arccos', detail: 'cos⁻¹'),
    OptnToken('arctan(', 'arctan', detail: 'tan⁻¹'),
  ]);

  static const OptnTokenSection hyperbolic = OptnTokenSection('hyp', 'Hiperbólicas', [
    OptnToken('sinh(', 'sinh', detail: 'seno hiperbólico'),
    OptnToken('cosh(', 'cosh', detail: 'coseno hiperb.'),
    OptnToken('tanh(', 'tanh', detail: 'tangente hiperb.'),
    OptnToken('asinh(', 'asinh', detail: 'sinh⁻¹'),
    OptnToken('acosh(', 'acosh', detail: 'cosh⁻¹'),
    OptnToken('atanh(', 'atanh', detail: 'tanh⁻¹'),
  ]);

  static const OptnTokenSection functions = OptnTokenSection('fun', 'Funciones', [
    OptnToken('√(', '√■'),
    OptnToken('root(', 'ⁿ√■', detail: 'raíz de índice n'),
    OptnToken('³√(', '³√■'),
    OptnToken('ln(', 'ln'),
    OptnToken('log(', 'log'),
    OptnToken('log_(', 'logₐ■', detail: 'base a'),
    OptnToken('sin(', 'sin'),
    OptnToken('cos(', 'cos'),
    OptnToken('tan(', 'tan'),
  ]);

  /// Orden en el que se muestran las secciones.
  static const List<OptnTokenSection> all = [constants, inverseTrig, hyperbolic, functions];

  static OptnTokenSection? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
