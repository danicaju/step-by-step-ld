// flutter_math_fork no expone la tabla de funciones TeX; registramos ahi un comando propio.
// ignore_for_file: implementation_imports
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/src/ast/options.dart';
import 'package:flutter_math_fork/src/ast/syntax_tree.dart';
import 'package:flutter_math_fork/src/ast/types.dart';
import 'package:flutter_math_fork/src/parser/tex/functions.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/render/layout/reset_baseline.dart';

/// Registro del comando `\lcdcursor` (nodo de ancho 0) en el parser de `flutter_math_fork`.
abstract final class LcdCursorTex {
  static bool _registered = false;

  /// Registra `\lcdcursor` (idempotente). Llamar antes de parsear LaTeX con cursor.
  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    functions[r'\lcdcursor'] = const FunctionSpec(numArgs: 0, handler: _handler);
  }

  static GreenNode _handler(TexParser parser, FunctionContext context) => _LcdCursorNode();
}

/// Nodo hoja de ancho 0: la barra (0.09em x 0.9em) se pinta desbordando el hueco.
class _LcdCursorNode extends LeafNode {
  @override
  Mode get mode => Mode.math;

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier ||
      oldOptions.color != newOptions.color;

  @override
  BuildResult buildWidget(MathOptions options, List<BuildResult?> childBuildResults) {
    final em = options.fontSize * options.sizeMultiplier;
    // Caja de layout: 0 px de ancho y la altura de un digito (0.64em, sin profundidad).
    // Asi ni empuja a los vecinos ni agranda raices, fracciones o parentesis.
    // La barra visible (0.9em) se pinta por desbordamiento (-0.1em .. 0.8em).
    final box = 0.64 * em;
    return BuildResult(
      options: options,
      widget: ResetBaseline(
        height: box,
        child: SizedBox(
          width: 0,
          height: box,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                bottom: -0.1 * em,
                width: 0.09 * em,
                height: 0.9 * em,
                child: ColoredBox(color: options.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
