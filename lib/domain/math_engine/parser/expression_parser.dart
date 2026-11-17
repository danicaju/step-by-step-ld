import 'expression_tokenizer.dart';
export 'expression_tokenizer.dart';
import '../ast/ast_nodes.dart';
import 'cursor_navigation_helper.dart';
import 'fraction_template.dart';
import 'template_navigation_helper.dart';
import 'live_latex_formatter.dart';

export 'cursor_navigation_helper.dart';
export 'template_navigation_helper.dart';
export 'slash_fraction_converter.dart';
export 'fraction_template.dart';
export 'live_latex_formatter.dart';

class ExpressionParser {
  static const List<String> atomicKeywords = CursorNavigationHelper.atomicKeywords;
  static int snapCursorOutsideKeywords(String raw, int pos, {bool preferLeft = false}) =>
      CursorNavigationHelper.snapCursorOutsideKeywords(raw, pos, preferLeft: preferLeft);
  static int stepCursorLeft(String raw, int currentPos) => CursorNavigationHelper.stepCursorLeft(raw, currentPos);
  static int stepCursorRight(String raw, int currentPos) => CursorNavigationHelper.stepCursorRight(raw, currentPos);
  static (String raw, int cursor) insertAtCursor(String raw, int currentPos, String token, {bool keepLeadingZero = false, bool overwrite = false}) =>
      CursorNavigationHelper.insertAtCursor(raw, currentPos, token, keepLeadingZero: keepLeadingZero, overwrite: overwrite);
  static (String raw, int cursor) deleteAtCursor(String raw, int currentPos, {String emptyResult = '0', int emptyCursor = 1}) =>
      CursorNavigationHelper.deleteAtCursor(raw, currentPos, emptyResult: emptyResult, emptyCursor: emptyCursor);
  static int? jumpFractionUpDown(String raw, int currentPos, {required bool isUp}) =>
      CursorNavigationHelper.jumpFractionUpDown(raw, currentPos, isUp: isUp);
  static (String raw, int cursor)? handleFractionRightArrow(String raw, int cursorPos) =>
      CursorNavigationHelper.handleFractionRightArrow(raw, cursorPos);
  static (String raw, int cursor)? handlePowerRightArrow(String raw, int cursorPos) =>
      TemplateNavigationHelper.handlePowerRightArrow(raw, cursorPos);
  static (String raw, int cursor)? handleMcmMcdCommaOrDot(String raw, int cursorPos) =>
      TemplateNavigationHelper.handleMcmMcdCommaOrDot(raw, cursorPos);
  static (String raw, int cursor)? handleMcmMcdRightArrow(String raw, int cursorPos) =>
      TemplateNavigationHelper.handleMcmMcdRightArrow(raw, cursorPos);
  static (String raw, int cursor)? handleMcmMcdCloseParen(String raw, int cursorPos) =>
      TemplateNavigationHelper.handleMcmMcdCloseParen(raw, cursorPos);
  static String finalizeMcmMcdInput(String raw) => TemplateNavigationHelper.finalizeMcmMcdInput(raw);
  static (String raw, int cursor)? handleTwoSlotRightArrow(String raw, int cursorPos) =>
      TemplateNavigationHelper.handleTwoSlotRightArrow(raw, cursorPos);
  static (String raw, int cursor)? handleTwoSlotLeftArrow(String raw, int cursorPos) =>
      FractionTemplate.handleLeft(raw, cursorPos) ??
      TemplateNavigationHelper.handleTwoSlotLeftArrow(raw, cursorPos);
  static (String raw, int cursor)? handleStructuredBlockRightArrow(String raw, int cursorPos) =>
      TemplateNavigationHelper.handleStructuredBlockRightArrow(raw, cursorPos);
  static String finalizeForEvaluation(String raw) => LiveLatexFormatter.finalizeForEvaluation(raw);
  static String rawToLiveLatex(String raw, {int? cursorPos, bool overwrite = false}) =>
      LiveLatexFormatter.rawToLiveLatex(raw, cursorPos: cursorPos, overwrite: overwrite);

  late List<String> _tokens;
  int _pos = 0;

  /// Normaliza LaTeX básico (`\sqrt{..}`, `\sin(..)`, `{..}`) al texto plano del parser,
  /// de modo que `\sqrt{x+1}` agrupa todo el radicando.
  static String latexToPlain(String s) {
    if (!s.contains(r'\') && !s.contains('{')) return s;
    return s
        .replaceAll(r'\left', '')
        .replaceAll(r'\right', '')
        .replaceAll(r'\sqrt{', '√(')
        .replaceAllMapped(
          RegExp(r'\\(sin|cos|tan|ln|log|arcsin|arccos|arctan)'),
          (m) => m[1]!,
        )
        .replaceAll(r'\pi', 'π')
        .replaceAll('{', '(')
        .replaceAll('}', ')');
  }

  ExprNode parse(String input) {
    final cleaned = latexToPlain(input)
        .replaceAll(r'\cdot', '*')
        .replaceAll('cdot', '*')
        .replaceAll(r'\times', '*')
        .replaceAll('times', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return const IntNode(0);
    }

    _tokens = _tokenize(cleaned);
    _pos = 0;

    final result = _parseAddSub();
    if (_pos < _tokens.length) {
      throw const FormatException('Expresión incompleta o paréntesis sin cerrar');
    }
    return result;
  }

  List<String> _tokenize(String src) => ExpressionTokenizer.tokenize(src);

  String? get _current => _pos < _tokens.length ? _tokens[_pos] : null;

  String _consume() => _tokens[_pos++];

  bool _canStartPrimary(String? token) => ExpressionTokenizer.canStartPrimary(token);

  // Nivel 1: Suma y Resta (izquierda a derecha)
  ExprNode _parseAddSub() {
    ExprNode left = _parseMulDiv();
    while (_current == '+' || _current == '-') {
      final opToken = _consume();
      final right = _parseMulDiv();
      left = BinaryOpNode(
        left,
        opToken == '+' ? BinaryOperator.add : BinaryOperator.subtract,
        right,
      );
    }
    return left;
  }

  // Nivel 2: Multiplicación (*) y División (:, /)
  ExprNode _parseMulDiv() {
    ExprNode left = _parseUnary();
    while (_current == '*' ||
        _current == ':' ||
        _current == '/' ||
        _canStartPrimary(_current)) {
      BinaryOperator op = BinaryOperator.multiply;
      if (_current == '*' || _current == ':' || _current == '/') {
        final opToken = _consume();
        op = opToken == '*' ? BinaryOperator.multiply : BinaryOperator.divide;
      }
      final right = _parseUnary();
      left = BinaryOpNode(
        left,
        op,
        right,
      );
    }
    return left;
  }

  // Nivel 3: Signo menos unario (-3^2 se evalúa como UnaryMinusNode(PowerNode(3, 2)))
  ExprNode _parseUnary() {
    if (_current == '-') {
      _consume();
      final operand = _parseUnary();
      return UnaryMinusNode(operand);
    }
    if (_current == '+') {
      _consume();
      return _parseUnary();
    }
    return _parsePower();
  }

  // Nivel 4: Potencias (x^n, 10^-5, 10^(-2)) - Mayor prioridad que el menos unario
  ExprNode _parsePower() {
    ExprNode base = _parsePostfix();
    while (_current == '^') {
      _consume();
      int exp;
      if (_current == '(') {
        _consume();
        final expNode = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en el exponente');
        }
        _consume();
        final evalExp = _evalSimpleInt(expNode);
        if (evalExp == null) {
          throw const FormatException('El exponente debe ser un número entero');
        }
        exp = evalExp;
      } else {
        int sign = 1;
        if (_current == '-') {
          _consume();
          sign = -1;
        }
        if (_current == null || int.tryParse(_current!) == null) {
          throw const FormatException('Falta el exponente entero');
        }
        exp = sign * int.parse(_consume());
      }
      base = PowerNode(base, exp);
    }
    return base;
  }

  ExprNode _parsePostfix() {
    ExprNode node = _parsePrimary();
    while (_current == '%' || _current == '°') {
      if (_current == '%') {
        _consume();
        node = PercentNode(node);
      } else if (_current == '°') {
        _consume(); // '°'
        if (node is DecimalNode) {
          node = DecimalNode(node.rawText, isDegrees: true);
        } else if (node is IntNode) {
          node = ExpressionTokenizer.parseDms(
            node: node,
            tokens: _tokens,
            getPos: () => _pos,
            current: () => _current,
            consume: _consume,
          );
        }
      }
    }
    return node;
  }

  static int? _evalSimpleInt(ExprNode node) => ExpressionTokenizer.evalSimpleInt(node);

  // Nivel 5: Paréntesis, Raíces (√, ³√, root), Fracciones (a/b), mcm/mcd y Números enteros
  ExprNode _parsePrimary() {
    final token = _current;
    if (token == null) {
      throw const FormatException('Expresión incompleta');
    }

    if (token == 'mcm' || token == 'mcd') {
      final isMcm = token == 'mcm';
      _consume();
      if (_current != '(') {
        throw const FormatException('Se esperaba "(" después de mcm/mcd');
      }
      _consume(); // '('
      if (_current == ')') {
        throw const FormatException('Introduce al menos 2 números en mcm/mcd');
      }
      final args = <ExprNode>[_parseAddSub()];
      while (_current == ',') {
        _consume(); // ','
        if (_current == ')') {
          throw const FormatException('Falta introducir el siguiente número tras la coma');
        }
        args.add(_parseAddSub());
      }
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis ")" en mcm/mcd');
      }
      _consume(); // ')'
      if (args.length < 2) {
        throw FormatException(
          '${isMcm ? "m.c.m." : "M.C.D."} requiere al menos 2 números (pulsa ▶ o . para añadir más)',
        );
      }
      return isMcm ? McmNode(args) : McdNode(args);
    }

    if (token == '³' || token == 'cbrt') {
      _consume();
      if (_current == '√') _consume();
      if (_current == '(') {
        _consume();
        final inside = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en la raíz cúbica');
        }
        _consume();
        return CbrtNode(inside);
      }
      final inside = _parsePrimary();
      return CbrtNode(inside);
    }

    if (token == 'root' || token == 'ⁿ') {
      _consume();
      if (_current == '√') _consume();
      if (_current == '(') {
        _consume();
        final firstArg = _parseAddSub();
        if (_current == ',') {
          _consume(); // ','
          final secondArg = _parseAddSub();
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis en la raíz');
          }
          _consume(); // ')'
          int n = 2;
          if (firstArg is IntNode) {
            n = firstArg.value;
          }
          return NthRootNode(n, secondArg);
        } else {
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis en la raíz');
          }
          _consume();
          return SqrtNode(firstArg);
        }
      }
      final inside = _parsePrimary();
      return SqrtNode(inside);
    }

    if (token == '√' || token == 'sqrt') {
      _consume();
      if (_current == '(') {
        _consume();
        final inside = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis en la raíz');
        }
        _consume();
        return SqrtNode(inside);
      }
      final inside = _parsePrimary();
      return SqrtNode(inside);
    }

    if (token == '(') {
      _consume(); // '('
      // Caso especial: número negativo entre paréntesis como (-3) para (-3)^2
      if (_current == '-' &&
          _pos + 2 < _tokens.length &&
          int.tryParse(_tokens[_pos + 1]) != null &&
          _tokens[_pos + 2] == ')') {
        _consume(); // '-'
        final val = int.parse(_consume());
        _consume(); // ')'
        return UnaryMinusNode(IntNode(val), hasExplicitParentheses: true);
      }

      final inside = _parseAddSub();
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis )');
      }
      _consume(); // ')'
      if (inside is BinaryOpNode) {
        return BinaryOpNode(inside.left, inside.op, inside.right, parenthesized: true);
      }
      return inside;
    }

    if (token.toUpperCase() == 'ANS') {
      _consume();
      return const VariableNode('ANS');
    }

    if (token == 'pi' || token == 'π') {
      _consume();
      return const PiNode();
    }

    final trigFn = _matchTrigFunction(token);
    if (trigFn != null) {
      _consume();
      if (_current == '^') {
        _consume(); // '^'
        int expVal = 2;
        if (_current == '(') {
          _consume();
          final expNode = _parseAddSub();
          expVal = _evalSimpleInt(expNode) ?? 2;
          if (_current == ')') _consume();
        } else if (_current != null && int.tryParse(_current!) != null) {
          expVal = int.parse(_consume());
        }
        final arg = _parsePrimary();
        return PowerNode(TrigNode(trigFn, arg), expVal);
      }
      if (_current == '(') {
        _consume();
        final arg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en función trigonométrica');
        }
        _consume();
        return TrigNode(trigFn, arg);
      }
      final arg = _parsePrimary();
      return TrigNode(trigFn, arg);
    }

    if (token == 'ln') {
      _consume();
      if (_current == '(') {
        _consume();
        final arg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en ln');
        }
        _consume();
        return LogNode(arg: arg, isNaturalLn: true);
      }
      return LogNode(arg: _parsePrimary(), isNaturalLn: true);
    }

    if (token == 'log') {
      _consume();
      if (_current == '(') {
        _consume();
        final firstArg = _parseAddSub();
        if (_current == ',') {
          _consume();
          final secondArg = _parseAddSub();
          if (_current != ')') {
            throw const FormatException('Falta cerrar paréntesis ")" en log');
          }
          _consume();
          return LogNode(base: firstArg, arg: secondArg);
        }
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en log');
        }
        _consume();
        return LogNode(arg: firstArg);
      }
      return LogNode(arg: _parsePrimary());
    }

    if (token == 'log_') {
      _consume();
      if (_current == '(') {
        _consume();
        final baseArg = _parseAddSub();
        if (_current != ',') {
          throw const FormatException('Pulsa ▶ tras la base para introducir el argumento del logaritmo');
        }
        _consume();
        final valArg = _parseAddSub();
        if (_current != ')') {
          throw const FormatException('Falta cerrar paréntesis ")" en logaritmo');
        }
        _consume();
        return LogNode(base: baseArg, arg: valArg);
      }
      final baseArg = _parsePrimary();
      if (_current != '(') {
        throw const FormatException('Se esperaba "(" tras la base del logaritmo');
      }
      _consume();
      final valArg = _parseAddSub();
      if (_current != ')') {
        throw const FormatException('Falta cerrar paréntesis ")" en logaritmo');
      }
      _consume();
      return LogNode(base: baseArg, arg: valArg);
    }

    final isVar = RegExp(r'^[A-Fa-fXYxy]$').hasMatch(token);
    if (isVar) {
      _consume();
      return VariableNode(token.toUpperCase());
    }

    final intVal = int.tryParse(token);
    if (intVal != null) {
      _consume();
      // Si justo después del número hay una barra '/' seguida de otro entero, creamos FractionNode
      if (_current == '/' && _pos + 1 < _tokens.length && int.tryParse(_tokens[_pos + 1]) != null) {
        _consume(); // '/'
        final denVal = int.parse(_consume());
        return FractionNode(intVal, denVal);
      }
      return IntNode(intVal);
    }

    if (token.contains('.') && double.tryParse(token) != null) {
      _consume();
      return DecimalNode(token);
    }

    throw FormatException('Símbolo inesperado: $token');
  }

  static TrigFunction? _matchTrigFunction(String token) => ExpressionTokenizer.matchTrigFunction(token);
}