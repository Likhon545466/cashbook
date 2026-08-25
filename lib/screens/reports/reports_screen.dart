import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/animated_progress_bar.dart';
import '../settings/budget_screen.dart';
import '../transactions/add_transaction_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? _customRange;
  bool _useCustomRange = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BudgetProvider>().loadMonth(_selectedMonth);
    });
  }

  List<CashTransaction> _filteredTransactions(
    List<CashTransaction> transactions,
  ) {
    if (_useCustomRange && _customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );

      return transactions.where((item) {
        return !item.date.isBefore(start) && !item.date.isAfter(end);
      }).toList();
    }

    return transactions.where((item) {
      return item.date.year == _selectedMonth.year &&
          item.date.month == _selectedMonth.month;
    }).toList();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );

    if (picked == null || !mounted) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    setState(() {
      _customRange = picked;
      _useCustomRange = true;
    });
  }

  Future<void> _changeMonth(int offset) async {
    final budgetProvider = context.read<BudgetProvider>();

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final next = DateTime(_selectedMonth.year, _selectedMonth.month + offset);

    setState(() {
      _useCustomRange = false;
      _selectedMonth = next;
    });

    await budgetProvider.loadMonth(next);
  }

  Future<void> _openBudget() async {
    if (_useCustomRange) return;

    final provider = context.read<BudgetProvider>();
    await provider.loadMonth(_selectedMonth);

    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BudgetScreen(initialMonth: _selectedMonth),
      ),
    );

    if (!mounted) return;
    await provider.loadMonth(_selectedMonth);
  }

  Future<void> _openAdd() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  Map<String, int> _categoryTotals(
    List<CashTransaction> transactions,
    bool income,
  ) {
    final totals = <String, int>{};

    for (final item in transactions.where((item) => item.isIncome == income)) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }

    return totals;
  }

  int _periodDays() {
    if (_useCustomRange && _customRange != null) {
      return _customRange!.end.difference(_customRange!.start).inDays + 1;
    }

    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );
    final first = DateTime(_selectedMonth.year, _selectedMonth.month, 1);

    return nextMonth.difference(first).inDays;
  }

  MapEntry<String, int>? _highestSpendingDay(
    List<CashTransaction> transactions,
  ) {
    final totals = <String, int>{};

    for (final item in transactions.where((item) => !item.isIncome)) {
      final key = DateFormat('yyyy-MM-dd').format(item.date);
      totals[key] = (totals[key] ?? 0) + item.amount;
    }

    if (totals.isEmpty) return null;

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first;
  }

  double? _changePercent(int current, int previous) {
    if (previous == 0) {
      if (current == 0) return 0;
      return null;
    }
    return ((current - previous) / previous) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final budgets = context.watch<BudgetProvider>();
    final items = _filteredTransactions(provider.transactions);

    final income = items
        .where((item) => item.isIncome)
        .fold<int>(0, (sum, item) => sum + item.amount);

    final expense = items
        .where((item) => !item.isIncome)
        .fold<int>(0, (sum, item) => sum + item.amount);

    final net = income - expense;
    final savingsRate = income <= 0 ? 0.0 : (net / income) * 100;
    final averageDailyExpense = _periodDays() <= 0
        ? 0
        : expense ~/ _periodDays();

    final expenseCategories = _categoryTotals(items, false).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final incomeCategories = _categoryTotals(items, true).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topExpense = expenseCategories.isEmpty
        ? null
        : expenseCategories.first;
    final highestDay = _highestSpendingDay(items);

    final periodLabel = _useCustomRange && _customRange != null
        ? '${DateFormat('dd MMM').format(_customRange!.start)} - '
              '${DateFormat('dd MMM yyyy').format(_customRange!.end)}'
        : DateFormat('MMMM yyyy').format(_selectedMonth);

    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    final previousIncome = provider.incomeForMonth(previousMonth);
    final previousExpense = provider.expenseForMonth(previousMonth);

    final incomeChange = _useCustomRange
        ? null
        : _changePercent(income, previousIncome);
    final expenseChange = _useCustomRange
        ? null
        : _changePercent(expense, previousExpense);

    final totalBudget = _useCustomRange ? 0 : budgets.totalBudget();
    final totalSpent = _useCustomRange
        ? 0
        : budgets.totalSpent(provider.transactions);
    final remaining = totalBudget - totalSpent;
    final budgetProgress = totalBudget <= 0 ? 0.0 : totalSpent / totalBudget;

    final now = DateTime.now();
    final isCurrentSelectedMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final daysInSelectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final daysLeft = isCurrentSelectedMonth
        ? (daysInSelectedMonth - now.day + 1).clamp(1, daysInSelectedMonth)
        : daysInSelectedMonth;
    final safePerDay = remaining <= 0 ? 0 : remaining ~/ daysLeft;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Understand your money flow',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadTransactions();
          if (!_useCustomRange) {
            await budgets.loadMonth(_selectedMonth);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  _changeMonth(1);
                } else if (velocity > 250) {
                  _changeMonth(-1);
                }
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          periodLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
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
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickCustomRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                _useCustomRange ? 'Change Custom Range' : 'Custom Date Range',
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              _ReportEmpty(onAdd: _openAdd)
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Balance',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          MoneyFormatter.currency(net),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: net >= 0
                                    ? AppSemanticColors.income(context)
                                    : AppSemanticColors.expense(context),
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            label: '${items.length} entries',
                            icon: Icons.receipt_long_outlined,
                          ),
                          _Pill(
                            label: 'Savings ${savingsRate.toStringAsFixed(0)}%',
                            icon: Icons.savings_outlined,
                          ),
                          _Pill(
                            label:
                                'Avg daily ${MoneyFormatter.currency(averageDailyExpense)}',
                            icon: Icons.calendar_today_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ValueCard(
                      title: 'Income',
                      amount: income,
                      positive: true,
                      change: incomeChange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ValueCard(
                      title: 'Expense',
                      amount: expense,
                      positive: false,
                      change: expenseChange,
                    ),
                  ),
                ],
              ),
              if (!_useCustomRange) ...[
                const SizedBox(height: 12),
                _BudgetPreview(
                  totalBudget: totalBudget,
                  spent: totalSpent,
                  remaining: remaining,
                  progress: budgetProgress,
                  safePerDay: safePerDay,
                  onTap: _openBudget,
                ),
              ],
              if (topExpense != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppSemanticColors.warning(
                          context,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        color: AppSemanticColors.warning(context),
                      ),
                    ),
                    title: const Text(
                      'Top spending category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      expense <= 0
                          ? topExpense.key
                          : '${topExpense.key} • '
                                '${((topExpense.value / expense) * 100).toStringAsFixed(0)}% of spending',
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: FittedBox(
                        child: Text(
                          MoneyFormatter.currency(topExpense.value),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (highestDay != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.bolt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text(
                      'Highest spending day',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(highestDay.key)),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: FittedBox(
                        child: Text(
                          MoneyFormatter.currency(highestDay.value),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _BreakdownSection(
                title: 'Expense Breakdown',
                emptyText: 'No expenses in this period',
                entries: expenseCategories,
                total: expense,
              ),
              const SizedBox(height: 20),
              _BreakdownSection(
                title: 'Income Breakdown',
                emptyText: 'No income in this period',
                entries: incomeCategories,
                total: income,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetPreview extends StatelessWidget {
  final int totalBudget;
  final int spent;
  final int remaining;
  final double progress;
  final int safePerDay;
  final VoidCallback onTap;

  const _BudgetPreview({
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.progress,
    required this.safePerDay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final over = totalBudget > 0 && spent > totalBudget;
    final warning = totalBudget > 0 && progress >= 0.80;
    final statusColor = over
        ? Theme.of(context).colorScheme.error
        : warning
        ? AppSemanticColors.warning(context)
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: totalBudget <= 0
              ? Row(
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
                        Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Budget',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 3),
                          Text('No budget set for this month'),
                        ],
                      ),
                    ),
                    const Text(
                      'Set Budget',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Monthly Budget',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${MoneyFormatter.currency(spent)} of '
                      '${MoneyFormatter.currency(totalBudget)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 11),
                    AnimatedProgressBar(value: progress, height: 8),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            over
                                ? 'Over ${MoneyFormatter.currency(-remaining)}'
                                : 'Remaining ${MoneyFormatter.currency(remaining)}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Safe/day ${MoneyFormatter.currency(safePerDay)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final String title;
  final int amount;
  final bool positive;
  final double? change;

  const _ValueCard({
    required this.title,
    required this.amount,
    required this.positive,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive
        ? AppSemanticColors.income(context)
        : AppSemanticColors.expense(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              positive ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 21,
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormatter.currency(amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (change != null) ...[
              const SizedBox(height: 6),
              Text(
                '${change! >= 0 ? '↑' : '↓'} '
                '${change!.abs().toStringAsFixed(0)}% vs last month',
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Pill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<MapEntry<String, int>> entries;
  final int total;

  const _BreakdownSection({
    required this.title,
    required this.emptyText,
    required this.entries,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          )
        else
          ...entries
              .take(6)
              .map(
                (entry) => _BreakdownTile(
                  name: entry.key,
                  amount: entry.value,
                  total: total,
                ),
              ),
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final String name;
  final int amount;
  final int total;

  const _BreakdownTile({
    required this.name,
    required this.amount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : amount / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  MoneyFormatter.currency(amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 9),
            AnimatedProgressBar(value: progress, height: 7),
          ],
        ),
      ),
    );
  }
}

class _ReportEmpty extends StatelessWidget {
  final VoidCallback onAdd;

  const _ReportEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 44,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing to report yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Add transactions to see spending insights and budget progress.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}
