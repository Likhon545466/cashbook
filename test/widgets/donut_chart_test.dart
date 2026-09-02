import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/screens/reports/widgets/donut_chart.dart';
import 'package:cashbook/utils/money_formatter.dart';

void main() {
  group('DonutChart Widget Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('renders empty state when items list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DonutChart(items: []),
          ),
        ),
      );

      expect(find.text('No data for selected period'), findsOneWidget);
    });

    testWidgets('renders total amount and category slices with animation', (tester) async {
      final items = [
        const DonutChartData(label: 'Food', value: 3000, color: Colors.blue),
        const DonutChartData(label: 'Rent', value: 7000, color: Colors.red),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonutChart(
              items: items,
              centerTitle: 'Total Spent',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('৳10,000'), findsOneWidget);
      expect(find.text('Tap slice to inspect'), findsOneWidget);
    });
  });
}
