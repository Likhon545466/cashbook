import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/widgets/month_picker_dialog.dart';

void main() {
  group('MonthPickerDialog Widget Tests', () {
    testWidgets('renders month picker dialog and selects month', (tester) async {
      DateTime? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selected = await MonthPickerDialog.show(
                      context,
                      initialMonth: DateTime(2026, 9),
                    );
                  },
                  child: const Text('Open Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Month'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);

      // Tap October
      await tester.tap(find.text('Oct'));
      await tester.pumpAndSettle();

      // Tap Select
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.year, equals(2026));
      expect(selected!.month, equals(10));
    });

    testWidgets('changes year when clicking chevron buttons', (tester) async {
      DateTime? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selected = await MonthPickerDialog.show(
                      context,
                      initialMonth: DateTime(2026, 9),
                    );
                  },
                  child: const Text('Open Picker'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Click right chevron to increment year
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(find.text('2027'), findsOneWidget);

      // Tap March in 2027
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.year, equals(2027));
      expect(selected!.month, equals(3));
    });
  });
}
