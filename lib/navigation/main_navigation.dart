import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/savings_provider.dart';
import '../providers/transaction_provider.dart';
import '../screens/debt/debt_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/transactions/add_transaction_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../widgets/savings_transfer_sheet.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  Future<void> _quickAdd() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final action = await showModalBottomSheet<_QuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quick Add',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _QuickTile(
                icon: Icons.south_west_rounded,
                title: 'Cash In',
                color: AppSemanticColors.income(sheetContext),
                onTap: () => Navigator.pop(sheetContext, _QuickAction.cashIn),
              ),
              _QuickTile(
                icon: Icons.north_east_rounded,
                title: 'Cash Out',
                color: AppSemanticColors.expense(sheetContext),
                onTap: () => Navigator.pop(sheetContext, _QuickAction.cashOut),
              ),
              _QuickTile(
                icon: Icons.savings_outlined,
                title: 'Add to Savings',
                color: AppSemanticColors.savings(sheetContext),
                onTap: () => Navigator.pop(sheetContext, _QuickAction.savings),
              ),
              _QuickTile(
                icon: Icons.handshake_outlined,
                title: 'Add Debt',
                color: Theme.of(sheetContext).colorScheme.primary,
                onTap: () => Navigator.pop(sheetContext, _QuickAction.debt),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == _QuickAction.debt) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => const DebtScreen(openAddOnStart: true),
        ),
      );
      return;
    }

    if (action == _QuickAction.savings) {
      final transactions = context.read<TransactionProvider>();
      final savings = context.read<SavingsProvider>();
      final available = transactions.balance - savings.balance;

      final changed = await showSavingsTransferSheet(
        context,
        deposit: true,
        availableBalance: available,
      );

      if (!mounted || changed != true) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Money moved to savings.')));
      return;
    }

    final type = action == _QuickAction.cashIn ? 'income' : 'expense';

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == 'income' ? 'Cash in saved.' : 'Cash out saved.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _currentIndex == 0) return;
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton(
                onPressed: _quickAdd,
                tooltip: 'Quick Add',
                child: const Icon(Icons.add_rounded),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (value) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuickAction { cashIn, cashOut, savings, debt }

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
