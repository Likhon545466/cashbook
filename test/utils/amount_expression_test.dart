import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/utils/amount_expression.dart';

void main() {
  group('AmountExpression Unit Tests', () {
    test('evaluates simple integer string', () {
      expect(AmountExpression.evaluate('500'), equals(500));
      expect(AmountExpression.evaluate('0'), equals(0));
      expect(AmountExpression.evaluate('12345'), equals(12345));
    });

    test('evaluates addition expressions', () {
      expect(AmountExpression.evaluate('100+250'), equals(350));
      expect(AmountExpression.evaluate('50+50+50'), equals(150));
    });

    test('evaluates subtraction expressions', () {
      expect(AmountExpression.evaluate('1000-350'), equals(650));
      expect(AmountExpression.evaluate('500-100-50'), equals(350));
    });

    test('evaluates multiplication and division expressions', () {
      expect(AmountExpression.evaluate('50*4'), equals(200));
      expect(AmountExpression.evaluate('1000/4'), equals(250));
    });

    test('handles operator precedence with standard symbols', () {
      expect(AmountExpression.evaluate('100+50*2'), equals(200));
      expect(AmountExpression.evaluate('100*2+50'), equals(250));
    });

    test('handles alternative math operators like × and ÷ and −', () {
      expect(AmountExpression.evaluate('50×4'), equals(200));
      expect(AmountExpression.evaluate('1000÷4'), equals(250));
      expect(AmountExpression.evaluate('1000−350'), equals(650));
    });

    test('handles whitespace gracefully', () {
      expect(AmountExpression.evaluate('  500 + 250  '), equals(750));
      expect(AmountExpression.evaluate(' 100 * 5 + 50 '), equals(550));
    });

    test('returns null for empty or invalid input', () {
      expect(AmountExpression.evaluate(''), isNull);
      expect(AmountExpression.evaluate('   '), isNull);
      expect(AmountExpression.evaluate('abc'), isNull);
      expect(AmountExpression.evaluate('100+'), isNull);
      expect(AmountExpression.evaluate('++50'), isNull);
      expect(AmountExpression.evaluate('100/0'), isNull);
      // Non-integer division returns null
      expect(AmountExpression.evaluate('10/3'), isNull);
    });
  });
}
