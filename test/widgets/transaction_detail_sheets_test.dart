import 'package:cashbook/models/savings_transfer_model.dart';
import 'package:cashbook/models/transaction_model.dart';
import 'package:cashbook/screens/transactions/widgets/transaction_detail_sheets.dart';
import 'package:cashbook/utils/money_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction Detail Sheets Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('CashDetailSheet displays both Date and Time correctly', (
      tester,
    ) async {
      final transaction = CashTransaction(
        id: 1,
        type: 'expense',
        amount: 2500,
        category: 'Food',
        date: DateTime(2026, 9, 10, 15, 30),
        note: 'Dinner with team',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashDetailSheet(item: transaction),
          ),
        ),
      );

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('10 September 2026'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('03:30 PM'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Dinner with team'), findsWidgets);
      expect(find.text('-৳2,500'), findsOneWidget);
    });

    testWidgets('SavingsDetailSheet displays both Date and Time correctly', (
      tester,
    ) async {
      final transfer = SavingsTransfer(
        id: 1,
        amount: 5000,
        type: 'deposit',
        date: DateTime(2026, 9, 10, 10, 15),
        note: 'Emergency fund saving',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavingsDetailSheet(item: transfer),
          ),
        ),
      );

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('10 September 2026'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('10:15 AM'), findsOneWidget);
      expect(find.text('Available → Savings'), findsOneWidget);
      expect(find.text('+৳5,000'), findsOneWidget);
    });
  });
}
