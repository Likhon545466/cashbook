import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/utils/money_formatter.dart';

void main() {
  group('MoneyFormatter Unit Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    test('formats numbers with thousand separators', () {
      expect(MoneyFormatter.amount(0), equals('0'));
      expect(MoneyFormatter.amount(500), equals('500'));
      expect(MoneyFormatter.amount(1000), equals('1,000'));
      expect(MoneyFormatter.amount(1234567), equals('1,234,567'));
    });

    test('formats currency with default symbol', () {
      expect(MoneyFormatter.currency(500), equals('৳500'));
      expect(MoneyFormatter.currency(15000), equals('৳15,000'));
    });

    test('formats currency with custom symbol override', () {
      expect(MoneyFormatter.currency(500, '\$'), equals('\$500'));
      expect(MoneyFormatter.currency(15000, '€'), equals('€15,000'));
      expect(MoneyFormatter.currency(1000, '₹'), equals('₹1,000'));
    });

    test('updates global currencySymbol dynamically', () {
      MoneyFormatter.currencySymbol = '\$';
      expect(MoneyFormatter.currency(250), equals('\$250'));

      MoneyFormatter.currencySymbol = '£';
      expect(MoneyFormatter.currency(250), equals('£250'));
    });
  });
}
