import 'package:intl/intl.dart';

class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _international = NumberFormat.decimalPattern(
    'en_US',
  );

  static String amount(int value) {
    final sign = value < 0 ? '-' : '';
    return '$sign${_international.format(value.abs())}';
  }

  static String currency(int value) => '৳${amount(value)}';
}
