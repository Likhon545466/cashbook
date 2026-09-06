import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cashbook/models/budget_model.dart';
import 'package:cashbook/models/category_model.dart';
import 'package:cashbook/models/debt_model.dart';
import 'package:cashbook/models/recurring_transaction_model.dart';
import 'package:cashbook/models/savings_transfer_model.dart';
import 'package:cashbook/models/transaction_model.dart';
import 'package:cashbook/navigation/main_navigation.dart';
import 'package:cashbook/providers/budget_provider.dart';
import 'package:cashbook/providers/category_provider.dart';
import 'package:cashbook/providers/cloud_sync_provider.dart';
import 'package:cashbook/providers/debt_provider.dart';
import 'package:cashbook/providers/recurring_provider.dart';
import 'package:cashbook/providers/savings_provider.dart';
import 'package:cashbook/providers/security_provider.dart';
import 'package:cashbook/providers/settings_provider.dart';
import 'package:cashbook/providers/transaction_provider.dart';
import 'package:cashbook/services/database_service.dart';
import 'package:cashbook/services/google_cloud_sync_service.dart';

class FakeDatabaseService implements DatabaseService {
  @override
  Future<String?> getSetting(String key) async => null;

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Map<String, String>> getAllSettings() async => {};

  @override
  Future<List<CashTransaction>> getTransactions() async => [];

  @override
  Future<List<CashCategory>> getCategories() async => [];

  @override
  Future<List<CashBudget>> getBudgetsForMonth({required int year, required int month}) async => [];

  @override
  Future<List<SavingsTransfer>> getSavingsTransfers() async => [];

  @override
  Future<List<DebtItem>> getDebts() async => [];

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleCloudSyncService extends GoogleCloudSyncService {
  @override
  bool get isSignedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecurityProvider extends ChangeNotifier implements SecurityProvider {
  @override
  bool get appLockEnabled => false;
  @override
  bool get isAuthenticating => false;
  @override
  bool get isLoaded => true;
  @override
  String? get message => null;
  @override
  bool get isUnlocked => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MainNavigation renders tabs and switches properly', (tester) async {
    final fakeDb = FakeDatabaseService();

    final settingsProvider = SettingsProvider(fakeDb);
    final categoryProvider = CategoryProvider(fakeDb);
    final transactionProvider = TransactionProvider(fakeDb);
    final budgetProvider = BudgetProvider(fakeDb);
    final savingsProvider = SavingsProvider(fakeDb);
    final debtProvider = DebtProvider(fakeDb);
    final recurringProvider = RecurringProvider(fakeDb);
    final cloudProvider = CloudSyncProvider(
      fakeDb,
      cloudSyncService: FakeGoogleCloudSyncService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
          ChangeNotifierProvider<TransactionProvider>.value(value: transactionProvider),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
          ChangeNotifierProvider<SavingsProvider>.value(value: savingsProvider),
          ChangeNotifierProvider<DebtProvider>.value(value: debtProvider),
          ChangeNotifierProvider<RecurringProvider>.value(value: recurringProvider),
          ChangeNotifierProvider<SecurityProvider>.value(value: FakeSecurityProvider()),
          ChangeNotifierProvider<CloudSyncProvider>.value(value: cloudProvider),
        ],
        child: const MaterialApp(home: MainNavigation()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Transactions tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // Switch to Reports tab
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // Switch to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // Switch back to Home tab
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

