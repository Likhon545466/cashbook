import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/screens/reports/widgets/cashflow_bar_chart.dart';
import 'package:cashbook/utils/money_formatter.dart';

void main() {
  group('CashflowBarChart Widget Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('renders monthly bar columns and labels', (tester) async {
      final months = [
        MonthlyCashflowData(
          monthLabel: 'Jul',
          income: 20000,
          expense: 12000,
          date: DateTime(2026, 7, 1),
        ),
        MonthlyCashflowData(
          monthLabel: 'Aug',
          income: 25000,
          expense: 15000,
          date: DateTime(2026, 8, 1),
        ),
        MonthlyCashflowData(
          monthLabel: 'Sep',
          income: 30000,
          expense: 18000,
          date: DateTime(2026, 9, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashflowBarChart(months: months),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cashflow Trend'), findsOneWidget);
      expect(find.text('Jul'), findsOneWidget);
      expect(find.text('Aug'), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('In'), findsOneWidget);
      expect(find.text('Out'), findsOneWidget);
    });
  });
}
