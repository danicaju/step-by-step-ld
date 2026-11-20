import '../../core/rational.dart';
import '../../parser/expression_parser.dart';
import 'ext_expr.dart';

/// Parser descendente recursivo del motor extendido de M1.
/// Soporta |x|, n!, nCr, nPr, potencias racionales, raices n, e, pi, logs y trig.
class ExtParser {
  static final RegExp _tokenRe = RegExp(
    r'\d+\.\d+|\.\d+|\d+|nCr|nPr|ncr|npr|arcsin|arccos|arctan|sin⁻¹|cos⁻¹|tan⁻¹'
    r'|asin|acos|atan|sin|cos|tan|log_|log|ln|sqrt|cbrt|root|abs|Abs|ANS|ans'
    r'|pi|π|ℯ|[√∛³ⁿ]|[+\-*/:^(),!|]|[A-Fa-fWwXYxyZz]',
  );

  late List<String> _t;
  int _p = 0;
  int _absDepth = 0;

  static List<String> tokenize(String src) {
    final out = <String>[];
    var last = 0;
    for (final m in _tokenRe.allMatches(src)) {
      if (m.start != last) {
        throw ExtUnsupported('Simbolo no soportado: ${src.substring(last, m.start)}');
      }
      out.add(m.group(0)!);
      last = m.end;
    }
    if (last != src.length) {
      throw ExtUnsupported('Simbolo no soportado: ${src.substring(last)}');
    }
    return out;
  }

  /// `\frac{a}{b}` -> `((a)/(b))` respetando llaves anidadas.
  static String fracToSlash(String s) {
    var out = s;
    while (true) {
      final i = out.indexOf(r'\frac');
      if (i < 0) return out;
      final a = _group(out, i + 5);
      if (a == null) return out.replaceFirst(r'\frac', '');
      final b = _group(out, a.$2);
      if (b == null) return out.replaceFirst(r'\frac', '');
      out = '${out.substring(0, i)}(((${a.$1}))/((${b.$1})))${out.substring(b.$2)}';
    }
  }

  static (String, int)? _group(String s, int from) {
    if (from >= s.length || s[from] != '{') return null;
    var depth = 0;
    for (var i = from; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return (s.substring(from + 1, i), i + 1);
      }
    }
    return null;
  }

  XNode parse(String input) {
    final cleaned = ExpressionParser.latexToPlain(fracToSlash(input))
        .replaceAll(r'\cdot', '*')
        .replaceAll('·', '*')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(' ', '');
    if (cleaned.isEmpty) return XNum(Rational(0));
    _t = tokenize(cleaned);
    _p = 0;
    _absDepth = 0;
    final n = _addSub();
    if (_p < _t.length) {
      throw const FormatException('Expresion incompleta o parentesis sin cerrar');
    }
    return n;
  }

  String? get _cur => _p < _t.length ? _t[_p] : null;
  String _next() => _t[_p++];

  void _expect(String tok, String msg) {
    if (_cur != tok) throw FormatException(msg);
    _p++;
  }

  bool _startsPrimary(String? s) {
    if (s == null) return false;
    if (s == '|') return _absDepth == 0;
    if (s == ')' || s == ',' || s == '!' || s == '^') return false;
    if ('+-*/:'.contains(s) && s.length == 1) return false;
    if (s == 'nCr' || s == 'nPr' || s == 'ncr' || s == 'npr') return false;
    return true;
  }

  XNode _addSub() {
    var left = _mulDiv();
    while (_cur == '+' || _cur == '-') {
      final op = _next();
      left = XBin(left, op, _mulDiv());
    }
    return left;
  }

  XNode _mulDiv() {
    var left = _comb();
    while (_cur == '*' || _cur == '/' || _cur == ':' || _startsPrimary(_cur)) {
      var op = '*';
      if (_cur == '*' || _cur == '/' || _cur == ':') {
        op = _next() == '*' ? '*' : '/';
      }
      left = XBin(left, op, _comb());
    }
    return left;
  }

  XNode _comb() {
    var left = _unary();
    while (_cur == 'nCr' || _cur == 'nPr' || _cur == 'ncr' || _cur == 'npr') {
      final perm = _next().toLowerCase() == 'npr';
      left = XComb(left, _unary(), perm);
    }
    return left;
  }

  XNode _unary() {
    if (_cur == '-') {
      _p++;
      return XNeg(_unary());
    }
    if (_cur == '+') {
      _p++;
      return _unary();
    }
    return _power();
  }

  XNode _power() {
    final base = _postfix();
    if (_cur == '^') {
      _p++;
      if (_cur == '-') {
        _p++;
        return XPow(base, XNeg(_power()));
      }
      return XPow(base, _power());
    }
    return base;
  }

  XNode _postfix() {
    var n = _primary();
    while (_cur == '!') {
      _p++;
      n = XFact(n);
    }
    return n;
  }

  XNode _parenOrAtom() {
    if (_cur == '(') {
      _p++;
      final n = _addSub();
      _expect(')', 'Falta cerrar parentesis )');
      return n;
    }
    return _postfix();
  }

  XNode _primary() {
    final tok = _cur;
    if (tok == null) throw const FormatException('Expresion incompleta');
    if (tok == '(') {
      _p++;
      final n = _addSub();
      _expect(')', 'Falta cerrar parentesis )');
      return n;
    }
    if (tok == '|' || tok == 'abs' || tok == 'Abs') {
      _p++;
      if (tok == '|') {
        _absDepth++;
        final n = _addSub();
        _absDepth--;
        _expect('|', 'Falta cerrar el valor absoluto |');
        return XAbs(n);
      }
      _expect('(', 'Falta ( tras Abs');
      final n = _addSub();
      _expect(')', 'Falta cerrar parentesis )');
      return XAbs(n);
    }
    if (tok == '√' || tok == 'sqrt') {
      _p++;
      return XRoot(null, _parenOrAtom());
    }
    if (tok == '∛' || tok == 'cbrt' || tok == '³') {
      _p++;
      if (_cur == '√') _p++;
      return XRoot(XNum(Rational(3)), _parenOrAtom());
    }
    if (tok == 'root' || tok == 'ⁿ') {
      _p++;
      if (_cur == '√') _p++;
      _expect('(', 'Falta ( en la raiz');
      final first = _addSub();
      if (_cur == ',') {
        _p++;
        final rad = _addSub();
        _expect(')', 'Falta cerrar parentesis )');
        return XRoot(first, rad);
      }
      _expect(')', 'Falta cerrar parentesis )');
      return XRoot(null, first);
    }
    if (tok == 'pi' || tok == 'π') {
      _p++;
      return const XConst('pi');
    }
    if (tok == 'ℯ' || tok == 'e') {
      _p++;
      return const XConst('e');
    }
    if (tok.toUpperCase() == 'ANS') {
      _p++;
      return const XVar('ANS');
    }
    final fn = _fnName(tok);
    if (fn != null) return _function(fn);
    if (tok == 'log_') return _logBase();
    if (RegExp(r'^[A-Fa-fWwXYxyZz]$').hasMatch(tok)) {
      _p++;
      return XVar(tok.toUpperCase());
    }
    final num = _number(tok);
    if (num != null) {
      _p++;
      return num;
    }
    throw FormatException('Simbolo inesperado: $tok');
  }

  XNode? _number(String tok) {
    if (RegExp(r'^\d+$').hasMatch(tok)) {
      final v = int.tryParse(tok);
      if (v == null) throw const ExtUnsupported('Numero demasiado grande');
      return XNum(Rational(v));
    }
    if (RegExp(r'^(\d+)?\.\d+$').hasMatch(tok)) {
      final s = tok.startsWith('.') ? '0$tok' : tok;
      return XNum(Rational.fromDecimalString(s), s);
    }
    return null;
  }

  static String? _fnName(String t) => switch (t) {
        'sin' || 'cos' || 'tan' || 'ln' => t,
        'asin' || 'arcsin' || 'sin⁻¹' => 'asin',
        'acos' || 'arccos' || 'cos⁻¹' => 'acos',
        'atan' || 'arctan' || 'tan⁻¹' => 'atan',
        'log' => 'log',
        _ => null,
      };

  XNode _function(String name) {
    _p++;
    if (_cur == '^' && name != 'log' && name != 'ln') {
      // sin^2(x) = (sin x)^2
      _p++;
      final e = _number(_cur ?? '');
      if (e == null) throw const FormatException('Falta el exponente');
      _p++;
      return XPow(XFn(name, _fnArg()), e);
    }
    if (name == 'log' && _cur == '(') {
      _p++;
      final first = _addSub();
      if (_cur == ',') {
        _p++;
        final second = _addSub();
        _expect(')', 'Falta cerrar parentesis )');
        return XFn('log', second, base: first);
      }
      _expect(')', 'Falta cerrar parentesis )');
      return XFn('log', first);
    }
    return XFn(name, _fnArg());
  }

  XNode _fnArg() {
    if (_cur == '(') {
      _p++;
      final n = _addSub();
      _expect(')', 'Falta cerrar parentesis )');
      return n;
    }
    return _postfix();
  }

  XNode _logBase() {
    _p++; // log_
    if (_cur == '(') {
      _p++;
      final b = _addSub();
      if (_cur != ',') {
        throw const FormatException(
          'Pulsa ▶ tras la base para introducir el argumento del logaritmo',
        );
      }
      _p++;
      final a = _addSub();
      _expect(')', 'Falta cerrar parentesis )');
      return XFn('log', a, base: b);
    }
    final b = _postfix();
    if (_cur != '(') throw const FormatException('Se esperaba ( tras la base del logaritmo');
    _p++;
    final a = _addSub();
    _expect(')', 'Falta cerrar parentesis )');
    return XFn('log', a, base: b);
  }
}
