import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_helpers.dart';
import 'support/header_select.dart';

void main() {
  testWidgets('M1: el enunciado conserva la fraccion vertical que escribio el alumno', (t) async {
    await boot(t);
    await keys(t, ['a/b', '2', '+', '4']);
    await pad(t, 'down');
    await keys(t, ['3', '+', '1']);
    await pad(t, 'right');
    await keys(t, ['+', '5', '=']);
    final res = lcd(t).currentResolution!;
    expect(res.originalInputLatex, contains(r'\frac{2 + 4}{3 + 1}'));
    expect(res.originalInputLatex, isNot(contains(':')));
    expect(res.exactResultLatex, allOf(contains('13'), contains('2')));
    expect(t.takeException(), isNull);
  });

  testWidgets('M1 sin fracciones: el enunciado no cambia', (t) async {
    await boot(t);
    await keys(t, ['2', '+', '3', '=']);
    final res = lcd(t).currentResolution!;
    expect(res.originalInputLatex, isNot(contains(r'\frac')));
  });

  testWidgets('M2: la ecuacion con fraccion se muestra con fraccion vertical', (t) async {
    await boot(t);
    await tapF(t, find.text('MODE'));
    await tapF(t, find.byKey(const Key('menu_mode_2')));
    await key(t, 'a/b');
    await alphaKey(t, ')');
    await pad(t, 'down');
    await key(t, '2');
    await pad(t, 'right');
    await pad(t, 'right');
    await keys(t, ['3', '=']);
    final res = lcd(t).currentResolution!;
    expect(res.originalInputLatex, contains(r'\frac'));
    expect(res.exactResultLatex, contains('6'));
    expect(t.takeException(), isNull);
  });
}
