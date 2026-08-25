import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/amount_expression.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/animated_progress_bar.dart';
import '../../widgets/smart_amount_field.dart';

class BudgetScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const BudgetScreen({super.key, this.initialMonth});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<BudgetProvider>();
      final initial = widget.initialMonth;
      if (initial == null) {
        provider.loadCurrentMonth();
      } else {
        provider.loadMonth(initial);
      }
    });
  }

  Future<void> _changeMonth(int offset) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final provider = context.read<BudgetProvider>();
    final current = provider.selectedMonth;
    await provider.loadMonth(DateTime(current.year, current.month + offset));
  }

  Future<void> _goCurrentMonth() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    await context.read<BudgetProvider>().loadCurrentMonth();
  }

  int _previousMonthSpend(
    String category,
    DateTime selectedMonth,
    TransactionProvider transactions,
  ) {
    final previous = DateTime(selectedMonth.year, selectedMonth.month - 1);

    return transactions.transactions
        .where(
          (item) =>
              !item.isIncome &&
              item.category == category &&
              item.date.year == previous.year &&
              item.date.month == previous.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  Future<void> _setBudget({
    required String category,
    required int currentBudget,
    required int suggestedBudget,
  }) async {
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toString() : '',
    );

    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$category Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartAmountField(
                    controller: controller,
                    autofocus: true,
                    labelText: 'Monthly budget',
                    compact: true,
                    onSubmitted: (_) {
                      Navigator.pop(
                        dialogContext,
                        AmountExpression.evaluate(controller.text),
                      );
                    },
                  ),
                  if (suggestedBudget > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Based on last month',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(
                        'Use ${MoneyFormatter.currency(suggestedBudget)}',
                      ),
                      onPressed: () {
                        controller.text = suggestedBudget.toString();
                        setDialogState(() {});
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                if (currentBudget > 0)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, -1),
                    child: const Text('Remove'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      AmountExpression.evaluate(controller.text),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (!mounted || amount == null) return;

    final provider = context.read<BudgetProvider>();

    if (amount == -1) {
      await provider.removeBudget(category);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Budget removed.')));
      return;
    }

    if (amount > 0) {
      await provider.setBudget(category: category, amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Budget saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();
    final transactions = context.watch<TransactionProvider>();

    final expenseCategories = categories.byType('expense');
    final totalBudget = budgets.totalBudget();
    final totalSpent = budgets.totalSpent(transactions.transactions);
    final remaining = totalBudget - totalSpent;
    final progress = budgets.totalProgress(transactions.transactions);
    final overBudget = totalBudget > 0 && totalSpent > totalBudget;

    final now = DateTime.now();
    final selected = budgets.selectedMonth;
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final daysLeft = isCurrentMonth
        ? (daysInMonth - now.day + 1).clamp(1, daysInMonth)
        : daysInMonth;

    final safeToSpendPerDay = totalBudget <= 0 || remaining <= 0
        ? 0
        : remaining ~/ daysLeft;

    final budgeted = expenseCategories
        .where((item) => budgets.budgetForCategory(item.name) > 0)
        .toList();

    final notBudgeted = expenseCategories
        .where((item) => budgets.budgetForCategory(item.name) <= 0)
        .toList();

    final statusColor = overBudget
        ? Theme.of(context).colorScheme.error
        : progress >= 0.80
        ? AppSemanticColors.warning(context)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly Budgets',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => budgets.loadMonth(budgets.selectedMonth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat(
                              'MMMM yyyy',
                            ).format(budgets.selectedMonth),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (!isCurrentMonth) ...[
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: _goCurrentMonth,
                              child: Text(
                                'Go to current month',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            totalBudget == 0
                                ? 'Start a monthly budget'
                                : overBudget
                                ? 'Over budget'
                                : progress >= 0.90
                                ? 'Near your limit'
                                : progress >= 0.80
                                ? 'Watch spending'
                                : 'On track',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (totalBudget > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        totalBudget == 0
                            ? 'Set limits by category'
                            : overBudget
                            ? 'Over by ${MoneyFormatter.currency(-remaining)}'
                            : '${MoneyFormatter.currency(remaining)} remaining',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: totalBudget > 0 ? statusColor : null,
                            ),
                      ),
                    ),
                    if (totalBudget > 0) ...[
                      const SizedBox(height: 15),
                      AnimatedProgressBar(value: progress, height: 10),
                      const SizedBox(height: 10),
                      Text(
                        '${MoneyFormatter.currency(totalSpent)} spent of '
                        '${MoneyFormatter.currency(totalBudget)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (totalBudget > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BudgetInsightCard(
                      icon: Icons.calendar_month_outlined,
                      label: 'Days left',
                      value: '$daysLeft',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BudgetInsightCard(
                      icon: Icons.payments_outlined,
                      label: 'Safe to spend/day',
                      value: MoneyFormatter.currency(safeToSpendPerDay),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budgeted Categories',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${budgeted.length}/${expenseCategories.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (budgeted.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No category budgets yet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Choose a category below to set your first limit.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...budgeted.map((category) {
                final budget = budgets.budgetForCategory(category.name);
                final spent = budgets.spentForCategory(
                  category.name,
                  transactions.transactions,
                );
                final categoryProgress = budget <= 0 ? 0.0 : spent / budget;
                final left = budget - spent;
                final over = spent > budget;
                final warning = !over && categoryProgress >= 0.80;
                final color = over
                    ? Theme.of(context).colorScheme.error
                    : warning
                    ? AppSemanticColors.warning(context)
                    : Theme.of(context).colorScheme.primary;
                final previousSpend = _previousMonthSpend(
                  category.name,
                  selected,
                  transactions,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () async {
                      await HapticFeedback.selectionClick();
                      if (!mounted) return;
                      await _setBudget(
                        category: category.name,
                        currentBudget: budget,
                        suggestedBudget: previousSpend,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${MoneyFormatter.currency(spent)} of '
                                      '${MoneyFormatter.currency(budget)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    over
                                        ? 'Over ${MoneyFormatter.currency(-left)}'
                                        : '${MoneyFormatter.currency(left)} left',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${(categoryProgress * 100).toStringAsFixed(0)}%',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          AnimatedProgressBar(
                            value: categoryProgress,
                            height: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            if (notBudgeted.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Not Budgeted',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'Tap a category to add a monthly limit.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              ...notBudgeted.map((category) {
                final previousSpend = _previousMonthSpend(
                  category.name,
                  selected,
                  transactions,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    onTap: () => _setBudget(
                      category: category.name,
                      currentBudget: 0,
                      suggestedBudget: previousSpend,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: previousSpend > 0
                        ? Text(
                            'Last month: '
                            '${MoneyFormatter.currency(previousSpend)}',
                          )
                        : const Text('No previous month spending'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetInsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BudgetInsightCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
