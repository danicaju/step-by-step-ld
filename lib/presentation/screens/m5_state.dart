import '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
import '../widgets/modes/function_table_widget.dart';
import '../widgets/modes/limit_form_widget.dart';

/// Estado de M5 (Funciones): vista activa, formularios de limites y TABLE
/// y el ultimo estudio de una f(x) libre (para el visor universal).
class M5State {
  /// 0 = Estudio + Grafica, 1 = Limites lim, 2 = Tabla f(x), g(x).
  int view = 0;

  final LimitFormState limit = LimitFormState();
  final FunctionTableFormState table = FunctionTableFormState();

  StudyResult? study;

  bool get isForm => view != 0;

  /// ¿El cursor esta en la primera fila, de modo que ▲ sube a la cabecera?
  bool get atTop => view == 1 ? limit.focus == 0 : table.atTop;

  void reset() {
    view = 0;
    limit.clear();
    table.clear();
    study = null;
  }
}
