import 'dart:io';

import 'package:casio_tutor_calc/domain/math_engine/models/step_resolution.dart';
import 'package:casio_tutor_calc/presentation/widgets/goodnotes_sticker_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el sticker PNG rotula STEP-BY-STEP LD y nada de CASIO CLASSWIZ', (t) async {
    const res = StepByStepResolution(
      originalInputLatex: '2+3',
      steps: [MathStep(index: 1, shortTitle: 'Sumar', latexExpression: '2+3=5', pedagogicalNote: 'Suma.')],
      exactResultLatex: '5',
      decimalApproxLatex: '5',
    );
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GoodnotesStickerCanvas(resolution: res)))));
    expect(find.text('STEP-BY-STEP LD'), findsOneWidget);
    expect(find.textContaining(RegExp('classwiz|casio', caseSensitive: false)), findsNothing);
    expect(t.takeException(), isNull);
  });

  test('ningun texto visible ni nombre de fichero menciona casioWiz/classWiz', () {
    final offenders = <String>[];
    // Literales de cadena en lib/: se ignoran import/part y comentarios; los identificadores no cuentan.
    final literal = RegExp(r'''(['"])(?:(?!\1).)*(classwiz|casiowiz|casio tutor|casio classwiz)(?:(?!\1).)*\1''', caseSensitive: false);
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final line in f.readAsLinesSync()) {
        final t = line.trimLeft();
        if (t.startsWith('//') || t.startsWith('import ') || t.startsWith('part ') || t.startsWith('export ')) continue;
        if (literal.hasMatch(line)) offenders.add('${f.path}: $t');
      }
    }
    for (final p in ['web/index.html', 'web/manifest.json']) {
      if (RegExp('classwiz|casiowiz', caseSensitive: false).hasMatch(File(p).readAsStringSync())) offenders.add(p);
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('los PNG exportados se llaman step_by_step_ld_*', () {
    final exporter = File('lib/presentation/utils/goodnotes_exporter.dart').readAsStringSync();
    final summary = File('lib/presentation/widgets/side_panel/side_panel_summary_dialog.dart').readAsStringSync();
    expect(exporter, contains('step_by_step_ld_resolucion.png'));
    expect(summary, contains('step_by_step_ld_resumen_clase.png'));
    expect(exporter, isNot(contains('resolucion_paso_a_paso.png')));
    expect(summary, isNot(contains('resumen_clase_ld.png')));
  });
}
