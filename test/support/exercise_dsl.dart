import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/widgets/casio_lcd_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_helpers.dart';
import 'header_select.dart';

/// Tamanos de la bateria: escritorio y movil.
const Size kDesktop = Size(1280, 800);
const Size kPhone = Size(390, 844);

/// Alias de teclas fisicas (etiqueta real del teclado).
const Map<String, String> _alias = {
  'sqrt': '√■',
  'sq': 'x²',
  'log': 'log■□',
  'frac': 'a/b',
  'sd': 'S⬄D',
};

/// Teclas con SHIFT: alias -> etiqueta de la tecla base.
const Map<String, String> _shifted = {
  'pow': 'x²',
  'ln': 'log■□',
  'pi': '0',
};

/// Secuencia de pulsaciones reales en una cadena de tokens separados por espacios.
///
/// - Etiquetas de teclas (`2`, `+`, `a/b`, `=`, `AC`, `DEL`, `MODE`...) y alias (`sqrt`, `log`, `sq`).
/// - `<` `>` `^` `v`: D-Pad (izquierda, derecha, arriba, abajo).
/// - `x` / `y`: ALPHA + `)` / `(`. `A:<tecla>`: ALPHA + tecla. `S:<tecla>`: SHIFT + tecla (o alias `pow`, `ln`, `pi`).
/// - `steps`: en M5 cambia de la grafica a los pasos.
/// - `optn`: SHIFT + CALC (menu OPTN en la LCD).
/// - `pick:<dropdown>:<item>`: elige un item de un desplegable de la cabecera LCD.
/// - `mode:N`: abre MODE y elige el modo N (con cambio de pagina del menu).
Future<void> seq(WidgetTester t, String script) async {
  for (final tok in script.split(RegExp(r'\s+')).where((s) => s.isNotEmpty)) {
    switch (tok) {
      case '<':
        await pad(t, 'left');
      case '>':
        await pad(t, 'right');
      case '^':
        await pad(t, 'up');
      case 'v':
        await pad(t, 'down');
      case 'x':
        await alphaKey(t, ')');
      case 'y':
        await alphaKey(t, '(');
      case 'ln':
        // ln es la funcion ALPHA de la tecla log.
        await alphaKey(t, 'log■□');
      case 'tabB':
        await tapF(t, find.byKey(const Key('matrix_tab_B')));
      case 'tabA':
        await tapF(t, find.byKey(const Key('matrix_tab_A')));
      case 'steps':
        // M5: pasa del visor de grafica a la vista de pasos.
        if (find.byKey(const Key('mode5_view_toggle')).evaluate().isNotEmpty &&
            find.byType(CasioLcdScreen).evaluate().isEmpty) {
          await tapF(t, find.byKey(const Key('mode5_view_toggle')));
        }
        // M7 2D: del plano a los pasos.
        if (find.byKey(const Key('ineq_sys_2d_toggle_btn')).evaluate().isNotEmpty &&
            find.byType(CasioLcdScreen).evaluate().isEmpty) {
          await tapF(t, find.byKey(const Key('ineq_sys_2d_toggle_btn')));
        }
      case 'quickoptn':
        // Menu rapido OPTN de los modos sin lista propia (M6, M7...): se elige luego con `quick:<token>`.
        await tapF(t, find.text('SHIFT'));
        await tapF(t, find.text('CALC'));
      case 'optn':
        await tapF(t, find.text('SHIFT'));
        await tapF(t, find.text('CALC'));
      default:
        if (tok.startsWith('pick:')) {
          final p = tok.split(':');
          await pickHeader(t, p[1], p[2]);
        } else if (tok.startsWith('quick:')) {
          await tapF(t, find.byKey(Key('optn_insert_${tok.substring(6)}')));
        } else if (tok.startsWith('mode:')) {
          await goMode(t, int.parse(tok.substring(5)));
        } else if (tok.startsWith('A:')) {
          await alphaKey(t, tok.substring(2));
        } else if (tok.startsWith('S:')) {
          final k = tok.substring(2);
          await shiftKey(t, _shifted[k] ?? _alias[k] ?? k);
        } else {
          await key(t, _alias[tok] ?? tok);
        }
    }
  }
}

Future<void> goMode(WidgetTester t, int n) async {
  await tapF(t, find.text('MODE'));
  if (n > 4) await tapF(t, find.byKey(const Key('menu_page_next')));
  if (n > 8) await tapF(t, find.byKey(const Key('menu_page_next')));
  await tapF(t, find.byKey(Key('menu_mode_$n')));
}

/// Normaliza LaTeX para comparar: sin espacios, `\left`/`\right`, `\,`/`\;` ni llaves de coma decimal.
String norm(String s) => s
    .replaceAll('\n', '')
    .replaceAll(r'\left', '')
    .replaceAll(r'\right', '')
    .replaceAll(r'\,', '')
    .replaceAll(r'\;', '')
    .replaceAll(r'\!', '')
    .replaceAll(r'\dfrac', r'\frac')
    .replaceAll(' ', '');

/// Resolucion activa en la LCD (o falla si no hay).
StepByStepResolution res(WidgetTester t) {
  final r = lcd(t).currentResolution;
  expect(r, isNotNull, reason: 'no hay resolucion en la LCD (error o entrada incompleta)');
  return r!;
}

/// Pizarra: cada paso con LaTeX valido (llaves balanceadas, sin tildes/enes en `\text{}`/`\mathrm{}`,
/// sin `\r` suelto), titulo y nota no vacios y sin pasos repetidos consecutivos.
void expectLesson(StepByStepResolution r, {int minSteps = 1}) {
  expect(r.steps.length >= minSteps, isTrue, reason: 'solo ${r.steps.length} pasos (minimo $minSteps)');
  final all = [r.originalInputLatex, r.exactResultLatex, ...r.steps.map((s) => s.latexExpression)];
  for (final tex in all) {
    expect(balanced(tex.replaceAll(r'\{', '').replaceAll(r'\}', '')), isTrue, reason: 'llaves sin balancear en: $tex');
    expect(RegExp(r'\\(text|mathrm)\{[^}]*[áéíóúñ¿¡][^}]*\}').hasMatch(tex), isFalse, reason: 'tilde en \\text: $tex');
    expect(RegExp(r'\\r(?![a-zA-Z])').hasMatch(tex), isFalse, reason: '\\r suelto: $tex');
    // Todo lo que vaya a la LCD debe pasar el saneador sin romperse.
    expect(CasioLcdScreen.sanitizeForMathTex(tex).trim().isNotEmpty, isTrue, reason: 'LaTeX vacio');
  }
  for (var i = 0; i < r.steps.length; i++) {
    final s = r.steps[i];
    expect(s.shortTitle.trim().isNotEmpty, isTrue, reason: 'paso ${i + 1} sin titulo');
    expect(s.pedagogicalNote.trim().isNotEmpty || (s.warningTrick ?? '').trim().isNotEmpty, isTrue,
        reason: 'paso ${i + 1} ("${s.shortTitle}") sin nota didactica');
    if (i > 0) {
      expect(r.steps[i].latexExpression != r.steps[i - 1].latexExpression, isTrue,
          reason: 'paso ${i + 1} repite el anterior: ${s.latexExpression}');
    }
  }
}

/// Texto de todos los pasos (para buscar `t = -4 descartada`, etc.).
String lessonText(StepByStepResolution r) => [
      r.originalInputLatex,
      for (final s in r.steps) ...[s.shortTitle, s.latexExpression, s.pedagogicalNote, s.warningTrick ?? ''],
      r.exactResultLatex,
      r.decimalApproxLatex,
    ].join('\n');

/// Ejecuta [body] en escritorio y en movil (un `testWidgets` por tamano).
void bothSizes(String name, Future<void> Function(WidgetTester t) body) {
  for (final (label, size) in [('1280x800', kDesktop), ('390x844', kPhone)]) {
    testWidgets('$name [$label]', (t) async {
      await boot(t, size: size);
      await body(t);
      expect(t.takeException(), isNull, reason: 'excepcion/overflow en $label');
    });
  }
}
