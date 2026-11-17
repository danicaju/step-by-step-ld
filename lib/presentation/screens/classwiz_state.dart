import 'dart:math';

import '../../domain/math_engine/core/rational.dart';
import '../../domain/math_engine/models/step_resolution.dart';

export '../../domain/math_engine/arithmetic/classwiz_key_actions.dart';
export '../widgets/lcd/lcd_reset_view.dart';

/// Vista alternativa de la linea de resultado (FACT, ° ' ", a b/c, ENG).
enum CwView { normal, factor, dms, fraction, eng }

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

  bool resetOpen = false;
  int resetStage = 0; // 0 = menu, 1 = confirmacion
  int resetChoice = 0; // 0 Setup, 1 Memoria, 2 Todo

  List<String> calcVars = [];
  int calcIdx = 0;
  final Map<String, Rational> calcValues = {};
  StepByStepResolution? calcResult;

  Random random = Random();
}
