import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/widgets/smart_amount_field.dart';
import 'package:cashbook/utils/money_formatter.dart';

void main() {
  group('SmartAmountField Widget Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('renders prefix with dynamic currency and evaluates expressions', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SmartAmountField(
                controller: controller,
                labelText: 'Amount',
              ),
            ),
          ),
        ),
      );

      expect(find.text('৳'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '250+150');
      await tester.pump();

      // Calculation preview should appear with result label
      expect(find.text('Total ৳400'), findsOneWidget);
    });
  });
}
