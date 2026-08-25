import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/security_provider.dart';
import 'providers/savings_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'services/database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              SettingsProvider(DatabaseService.instance)..loadTheme(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SecurityProvider(DatabaseService.instance, LocalAuthentication())
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CategoryProvider(DatabaseService.instance)..loadCategories(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TransactionProvider(DatabaseService.instance)..loadTransactions(),
        ),
        ChangeNotifierProvider(
          create: (_) => BudgetProvider(DatabaseService.instance),
        ),
        ChangeNotifierProvider(
          create: (_) => SavingsProvider(DatabaseService.instance)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DebtProvider(DatabaseService.instance)..load(),
        ),
      ],
      child: const CashBookApp(),
    ),
  );
}
