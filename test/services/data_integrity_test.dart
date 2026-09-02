import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/services/data_integrity_service.dart';

void main() {
  group('DataIntegrityService Diagnostic Tests', () {
    test('reports healthy state when issues list is empty', () {
      final result = DataIntegrityResult(
        checkedAt: DateTime.now(),
        issues: const [],
        transactionCount: 20,
        savingsTransferCount: 5,
        debtCount: 10,
        debtPaymentCount: 15,
        debtDueExtensionCount: 2,
      );

      expect(result.healthy, isTrue);
      expect(result.criticalCount, equals(0));
      expect(result.warningCount, equals(0));
      expect(result.checkedRecords, equals(52));
    });

    test('counts critical and warning issues accurately', () {
      final result = DataIntegrityResult(
        checkedAt: DateTime.now(),
        transactionCount: 50,
        savingsTransferCount: 10,
        debtCount: 15,
        debtPaymentCount: 20,
        debtDueExtensionCount: 5,
        issues: const [
          DataIntegrityIssue(
            severity: DataIntegritySeverity.critical,
            title: 'Foreign Key Broken',
            detail: 'Debt payment references missing debt',
          ),
          DataIntegrityIssue(
            severity: DataIntegritySeverity.warning,
            title: 'Zero Amount',
            detail: 'Transaction with zero amount detected',
          ),
          DataIntegrityIssue(
            severity: DataIntegritySeverity.critical,
            title: 'Negative Balance',
            detail: 'Available balance is negative',
          ),
        ],
      );

      expect(result.healthy, isFalse);
      expect(result.criticalCount, equals(2));
      expect(result.warningCount, equals(1));
      expect(result.checkedRecords, equals(100));
    });
  });
}
