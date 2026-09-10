import 'package:cashbook/utils/money_formatter.dart';
import 'package:cashbook/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionTile Widget Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('renders title, category, date and time correctly', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              title: 'Dinner at restaurant',
              category: 'Food',
              amount: 1450,
              isIncome: false,
              dateLabel: '10 Sep, 08:30 PM',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Dinner at restaurant'), findsOneWidget);
      expect(find.text('Food • 10 Sep, 08:30 PM'), findsOneWidget);
      expect(find.text('-৳1,450'), findsOneWidget);

      await tester.tap(find.byType(TransactionTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders income transaction with positive symbol and color', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              title: 'Freelance payment',
              category: 'Salary',
              amount: 25000,
              isIncome: true,
              dateLabel: '01 Sep, 10:00 AM',
            ),
          ),
        ),
      );

      expect(find.text('Freelance payment'), findsOneWidget);
      expect(find.text('Salary • 01 Sep, 10:00 AM'), findsOneWidget);
      expect(find.text('+৳25,000'), findsOneWidget);
    });
  });
}
