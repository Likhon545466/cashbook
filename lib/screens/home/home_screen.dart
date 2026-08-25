import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../debt/debt_screen.dart';
import '../savings/savings_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavingsProvider>().load();
      context.read<DebtProvider>().load();
    });
  }

  Future<void> _openAdd(String type) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

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
    final transactions = context.watch<TransactionProvider>();
    final savings = context.watch<SavingsProvider>();
    final debts = context.watch<DebtProvider>();
    final settings = context.watch<SettingsProvider>();

    final totalMoney = transactions.balance;
    final savingsBalance = savings.balance;
    final availableBalance = totalMoney - savingsBalance;
    final monthlyNet = transactions.monthlyIncome - transactions.monthlyExpense;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CashBook', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, dd MMMM').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            transactions.loadTransactions(),
            savings.load(),
            debts.load(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            BalanceCard(
              balance: availableBalance,
              isHidden: settings.hideBalance,
              onToggleVisibility: settings.toggleBalanceVisibility,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Cash In',
                    icon: Icons.south_west_rounded,
                    color: AppSemanticColors.income(context),
                    onTap: () => _openAdd('income'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    title: 'Cash Out',
                    icon: Icons.north_east_rounded,
                    color: AppSemanticColors.expense(context),
                    onTap: () => _openAdd('expense'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Savings / Reserve',
              action: 'Manage',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const SavingsScreen()),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: InkWell(
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const SavingsScreen()),
                ),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.savings(
                            context,
                          ).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.savings_outlined,
                          color: AppSemanticColors.savings(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SavingsMetric(
                          label: 'Reserved',
                          value: settings.hideBalance
                              ? '••••'
                              : MoneyFormatter.currency(savingsBalance),
                          color: AppSemanticColors.savings(context),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: Theme.of(context).dividerColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SavingsMetric(
                          label: 'Available',
                          value: settings.hideBalance
                              ? '••••'
                              : MoneyFormatter.currency(availableBalance),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            if (savingsBalance > totalMoney) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: AppSemanticColors.warning(context),
                  ),
                  title: const Text(
                    'Savings exceeds current total cash',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Review savings or edited transactions.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Debt',
              action: 'Manage',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const DebtScreen()),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: InkWell(
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const DebtScreen()),
                ),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.handshake_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DebtMetric(
                              label: 'You owe',
                              value: settings.hideBalance
                                  ? '••••'
                                  : MoneyFormatter.currency(debts.totalYouOwe),
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 38,
                            color: Theme.of(context).dividerColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DebtMetric(
                              label: 'Owed to you',
                              value: settings.hideBalance
                                  ? '••••'
                                  : MoneyFormatter.currency(
                                      debts.totalOwedToYou,
                                    ),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      if (debts.openCount > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              debts.overdueCount > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.pending_actions_outlined,
                              size: 16,
                              color: debts.overdueCount > 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                debts.overdueCount > 0
                                    ? '${debts.openCount} open • ${debts.overdueCount} overdue'
                                    : debts.dueSoonCount > 0
                                    ? '${debts.openCount} open • ${debts.dueSoonCount} due soon'
                                    : '${debts.openCount} open debt${debts.openCount == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (debts.nextAttentionDebt != null) ...[
              const SizedBox(height: 8),
              _DebtReminderCard(
                item: debts.nextAttentionDebt!,
                remaining: debts.remainingFor(debts.nextAttentionDebt!),
                status: debts.statusFor(debts.nextAttentionDebt!),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const DebtScreen()),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'This Month',
              action: DateFormat('MMMM').format(DateTime.now()),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Metric(
                          label: 'Income',
                          value: transactions.monthlyIncome,
                        ),
                        _divider(context),
                        _Metric(
                          label: 'Expense',
                          value: transactions.monthlyExpense,
                        ),
                        _divider(context),
                        _Metric(label: 'Net', value: monthlyNet),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Recent Transactions',
              action: 'See all',
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const TransactionsScreen()),
              ),
            ),
            const SizedBox(height: 10),
            if (transactions.recentTransactions.isEmpty)
              const _EmptyCard()
            else
              ...transactions.recentTransactions
                  .take(5)
                  .map(
                    (item) => TransactionTile(
                      title: item.note.isEmpty ? item.category : item.note,
                      category: item.category,
                      amount: item.amount,
                      isIncome: item.isIncome,
                      dateLabel: DateFormat('dd MMM').format(item.date),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: Theme.of(context).dividerColor,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onTap;

  const _SectionHeader({required this.title, required this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (onTap != null)
          TextButton(onPressed: onTap, child: Text(action))
        else
          Text(action, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                MoneyFormatter.currency(value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 10),
            const Text(
              'No transactions yet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the + button to add your first transaction.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SavingsMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DebtReminderCard extends StatelessWidget {
  final DebtItem item;
  final int remaining;
  final String status;
  final VoidCallback onTap;

  const _DebtReminderCard({
    required this.item,
    required this.remaining,
    required this.status,
    required this.onTap,
  });

  String _dueLabel() {
    final dueDate = item.dueDate;
    if (dueDate == null) return 'Needs attention';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;

    if (days < 0) {
      final late = days.abs();
      return '$late day${late == 1 ? '' : 's'} overdue';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  @override
  Widget build(BuildContext context) {
    final overdue = status == 'Overdue';
    final color = overdue
        ? Theme.of(context).colorScheme.error
        : AppSemanticColors.warning(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  overdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_dueLabel()} • ${item.person}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.isYouOwe ? 'You owe' : 'Owed to you'} ${MoneyFormatter.currency(remaining)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DebtMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
