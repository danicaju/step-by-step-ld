import '../ast/ast_nodes.dart';

class ExpressionTokenizer {
  static const List<String> atomicKeywords = [
    'sin⁻¹(',
    'cos⁻¹(',
    'tan⁻¹(',
    'arcsin(',
    'arccos(',
    'arctan(',
    'root(',
    'asin(',
    'acos(',
    'atan(',
    'log_(',
    'Abs(',
    'nCr',
    'nPr',
    'RanInt#(',
    'Ran#',
    'Pol(',
    'Rec(',
    'mcm(',
    'mcd(',
    'sin(',
    'cos(',
    'tan(',
    'log(',
    'ln(',
    '³√(',
    '*10^(',
    '*10^',
    'ANS',
    'ans',
    '√(',
    '^(',
  ];

  static List<String> tokenize(String src) {
    final regex = RegExp(
      r"\d+\.\d+|\.\d+|\d+|''|[+\-*:/^(),%°'"
      '"]'
      r'|arcsin|arccos|arctan|sin⁻¹|cos⁻¹|tan⁻¹|asin|acos|atan|sin|cos|tan|log_|log|ln|sqrt|cbrt|root|mcm|mcd|ANS|ans|pi|π|[√³ⁿ]|[A-Fa-fXYxy]',
    );
    return regex.allMatches(src).map((m) => m.group(0)!).toList();
  }

  static TrigFunction? matchTrigFunction(String token) {
    return switch (token) {
      'sin' => TrigFunction.sin,
      'cos' => TrigFunction.cos,
      'tan' => TrigFunction.tan,
      'asin' || 'arcsin' || 'sin⁻¹' => TrigFunction.asin,
      'acos' || 'arccos' || 'cos⁻¹' => TrigFunction.acos,
      'atan' || 'arctan' || 'tan⁻¹' => TrigFunction.atan,
      _ => null,
    };
  }

  static bool canStartPrimary(String? token) {
    if (token == null) return false;
    if (int.tryParse(token) != null) return true;
    if (token.startsWith('.') && double.tryParse(token) != null) return true;
    if (token == '(' ||
        token == '√' ||
        token == 'sqrt' ||
        token == '³' ||
        token == 'cbrt' ||
        token == 'root' ||
        token == 'ⁿ' ||
        token == 'mcm' ||
        token == 'mcd' ||
        token == 'sin' ||
        token == 'cos' ||
        token == 'tan' ||
        token == 'asin' ||
        token == 'acos' ||
        token == 'atan' ||
        token == 'sin⁻¹' ||
        token == 'cos⁻¹' ||
        token == 'tan⁻¹' ||
        token == 'arcsin' ||
        token == 'arccos' ||
        token == 'arctan' ||
        token == 'log' ||
        token == 'log_' ||
        token == 'ln' ||
        token == 'pi' ||
        token == 'π') {
      return true;
    }
    if (token.toUpperCase() == 'ANS') return true;
    if (RegExp(r'^[A-Fa-fXYxy]$').hasMatch(token)) return true;
    return false;
  }

  static int? evalSimpleInt(ExprNode node) {
    return switch (node) {
      IntNode(:final value) => value,
      UnaryMinusNode(:final operand) => () {
          final v = evalSimpleInt(operand);
          return v == null ? null : -v;
        }(),
      BinaryOpNode(:final left, :final op, :final right) => () {
          final l = evalSimpleInt(left);
          final r = evalSimpleInt(right);
          if (l == null || r == null) return null;
          return switch (op) {
            BinaryOperator.add => l + r,
            BinaryOperator.subtract => l - r,
            BinaryOperator.multiply => l * r,
            BinaryOperator.divide => (r != 0 && l % r == 0) ? l ~/ r : null,
          };
        }(),
      _ => null,
    };
  }

  static DmsNode parseDms({
    required IntNode node,
    required List<String> tokens,
    required int Function() getPos,
    required String? Function() current,
    required String Function() consume,
  }) {
    int min = 0;
    double sec = 0;
    bool hasMin = false;
    bool hasSec = false;
    final cur = current();
    final pos = getPos();
    if (cur != null &&
        int.tryParse(cur) != null &&
        pos + 1 < tokens.length &&
        tokens[pos + 1] == "'") {
      min = int.parse(consume());
      consume(); // "'"
      hasMin = true;
    }
    final cur2 = current();
    final pos2 = getPos();
    if (cur2 != null &&
        double.tryParse(cur2) != null &&
        pos2 + 1 < tokens.length &&
        (tokens[pos2 + 1] == '"' || tokens[pos2 + 1] == "''")) {
      sec = double.parse(consume());
      consume(); // '"' or "''"
      hasSec = true;
    }
    return DmsNode(
      degrees: node.value,
      minutes: min,
      seconds: sec,
      hasMinutes: hasMin,
      hasSeconds: hasSec,
    );
  }
}
