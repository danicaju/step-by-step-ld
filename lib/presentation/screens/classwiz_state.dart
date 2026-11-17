import 'dart:math';

import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/models/step_resolution.dart';
import '../widgets/lcd/lcd_list_menu.dart';
import '../widgets/modes/proportion_conversion_widget.dart';

export '../../domain/math_engine/arithmetic/classwiz_constants.dart';
export '../../domain/math_engine/arithmetic/classwiz_key_actions.dart';
export '../../domain/math_engine/arithmetic/classwiz_rewrites.dart';
export '../../domain/math_engine/arithmetic/unit_conversions.dart';
export '../../domain/math_engine/arithmetic/casio_iberia_arsenal.dart';
export '../../domain/math_engine/proportion/proportion_conversion_solver.dart';
export '../widgets/lcd/lcd_list_menu.dart';
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

  bool resetOpen = false;
  int resetStage = 0; // 0 = menu, 1 = confirmacion
  int resetChoice = 0; // 0 Setup, 1 Memoria, 2 Todo

  List<String> calcVars = [];
  int calcIdx = 0;
  final Map<String, Rational> calcValues = {};
  StepByStepResolution? calcResult;

  Random random = Random();
}
