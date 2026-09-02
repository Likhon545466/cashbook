import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/widgets/balance_card.dart';
import 'package:cashbook/utils/money_formatter.dart';

void main() {
  group('BalanceCard Widget Tests', () {
    setUp(() {
      MoneyFormatter.currencySymbol = '৳';
    });

    testWidgets('renders balance in visible state', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(
              balance: 15400,
              isHidden: false,
              onToggleVisibility: () => toggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Current Balance'), findsOneWidget);
      expect(find.text('৳15,400'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(toggled, isTrue);
    });

    testWidgets('renders masked balance in hidden state with dynamic currency symbol', (tester) async {
      MoneyFormatter.currencySymbol = '\$';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(
              balance: 15400,
              isHidden: true,
              onToggleVisibility: () {},
            ),
          ),
        ),
      );

      expect(find.text('\$ ••••••'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
