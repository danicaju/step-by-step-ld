import 'dart:math';

import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../widgets/lcd/lcd_list_menu.dart';
import '../widgets/modes/proportion_conversion_widget.dart';
import 'forms_state.dart';
import 'm5_state.dart';

export '../../domain/math_engine/arithmetic/classwiz_constants.dart';
export '../../domain/math_engine/arithmetic/classwiz_key_actions.dart';
export '../../domain/math_engine/arithmetic/classwiz_rewrites.dart';
export '../../domain/math_engine/arithmetic/unit_conversions.dart';
export '../../domain/math_engine/arithmetic/casio_iberia_arsenal.dart';
export '../../domain/math_engine/proportion/proportion_conversion_solver.dart';
export '../../domain/math_engine/calculus/function_table.dart';
export '../../domain/math_engine/calculus/limits_asymptotes_solver.dart';
export '../../domain/math_engine/solvers/rational_hyperbola_study.dart';
export '../painters/universal_function_painter.dart';
export '../widgets/lcd/lcd_list_menu.dart';
export '../widgets/modes/function_table_widget.dart';
export '../widgets/modes/limit_form_widget.dart';
export '../../domain/math_engine/geometry/geometry_triangle_solver.dart';
export '../../domain/math_engine/geometry/line_equations_solver.dart';
export '../../domain/math_engine/geometry/triangle_value_parser.dart';
export '../../domain/math_engine/polynomials/algebraic_fraction_solver.dart';
export '../../domain/math_engine/polynomials/spanish_box_division_solver.dart';
export '../../domain/math_engine/statistics/probability_distribution_solver.dart';
export '../painters/gaussian_bell_painter.dart';
export '../widgets/modes/geometry_mode_widget.dart';
export '../widgets/modes/mode_form.dart';
export '../widgets/modes/spanish_box_division_widget.dart';
export '../widgets/modes/box_division_input_widget.dart';
export '../widgets/modes/fraction_input_widget.dart';
export 'forms_state.dart';
export 'm5_state.dart';
export '../widgets/modes/proportion_conversion_widget.dart';
export '../widgets/lcd/lcd_reset_view.dart';

/// Vista alternativa de la linea de resultado (FACT, ° ' ", a b/c, ENG).
enum CwView { normal, factor, dms, fraction, eng }

/// Nivel de un menu de lista (OPTN/CONST/CONV) con su padre para volver con AC.
class LcdListState {
  final String kind;
  final String title;
  final List<LcdListItem> items;
  final LcdListState? parent;
  int cursor = 0;

  LcdListState(this.kind, this.title, this.items, {this.parent});
}

/// Estado de las teclas ClassWiz de la fase CW-2 (un unico campo en la pantalla).
///
/// Las vistas y notas pertenecen a una resolucion concreta ([owner]): al
/// recalcular o editar se crea/borra la resolucion y dejan de aplicarse solas.
class ClassWizState {
  StepByStepResolution? owner;
  CwView view = CwView.normal;
  int engExp = 0;
  String? note;

  bool stoPending = false;

  LcdListState? list;

  /// Formulario de Regla de 3 / Factores de conversion (OPTN de M1), `null` si cerrado.
  ProportionFormState? prop;

  /// Estado de M5 (vistas Limites / TABLE y estudio de f(x) libre).
  final M5State m5 = M5State();

  /// Vistas con formulario de M4, M8 y M10.
  final ExtraViewsState x = ExtraViewsState();

  bool resetOpen = false;
  int resetStage = 0; // 0 = menu, 1 = confirmacion
  int resetChoice = 0; // 0 Setup, 1 Memoria, 2 Todo

  List<String> calcVars = [];
  int calcIdx = 0;
  final Map<String, Rational> calcValues = {};
  StepByStepResolution? calcResult;

  Random random = Random();
}
