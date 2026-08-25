class AmountExpression {
  AmountExpression._();

  static int? evaluate(String raw) {
    final expression = raw
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll(' ', '');

    if (expression.isEmpty) return null;

    final tokens = <String>[];
    var number = StringBuffer();

    bool isOperator(String value) =>
        value == '+' || value == '-' || value == '*' || value == '/';

    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];

      if (RegExp(r'\d').hasMatch(char)) {
        number.write(char);
        continue;
      }

      if (!isOperator(char)) return null;

      if (number.isEmpty) {
        if (char == '-' && tokens.isEmpty) {
          number.write(char);
          continue;
        }
        return null;
      }

      tokens.add(number.toString());
      number = StringBuffer();
      tokens.add(char);
    }

    if (number.isEmpty) return null;
    tokens.add(number.toString());

    final values = <int>[];
    final operators = <String>[];

    int precedence(String operator) {
      if (operator == '*' || operator == '/') return 2;
      return 1;
    }

    bool applyTop() {
      if (operators.isEmpty || values.length < 2) return false;

      final operator = operators.removeLast();
      final right = values.removeLast();
      final left = values.removeLast();

      int result;
      switch (operator) {
        case '+':
          result = left + right;
          break;
        case '-':
          result = left - right;
          break;
        case '*':
          result = left * right;
          break;
        case '/':
          if (right == 0 || left % right != 0) return false;
          result = left ~/ right;
          break;
        default:
          return false;
      }

      if (result.abs() > 999999999999) return false;
      values.add(result);
      return true;
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (!isOperator(token)) {
        final value = int.tryParse(token);
        if (value == null || value.abs() > 999999999999) return null;
        values.add(value);
        continue;
      }

      while (operators.isNotEmpty &&
          precedence(operators.last) >= precedence(token)) {
        if (!applyTop()) return null;
      }
      operators.add(token);
    }

    while (operators.isNotEmpty) {
      if (!applyTop()) return null;
    }

    if (values.length != 1) return null;
    return values.single;
  }

  static bool isSimpleNumber(String raw) =>
      RegExp(r'^\s*\d+\s*$').hasMatch(raw);
}
