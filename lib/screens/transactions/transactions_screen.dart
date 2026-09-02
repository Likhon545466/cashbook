import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt_model.dart';
import '../../models/debt_payment_model.dart';
import '../../models/savings_transfer_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/savings_transfer_sheet.dart';
import '../../widgets/transaction_tile.dart';
import '../debt/debt_screen.dart';
import '../savings/savings_screen.dart';
import 'add_transaction_screen.dart';
import 'widgets/transaction_activity_tiles.dart';
import 'widgets/transaction_detail_sheets.dart';
import 'widgets/transaction_empty_view.dart';
import 'widgets/transaction_filter_sheet.dart';
import 'widgets/transaction_models.dart';
import 'widgets/transaction_quick_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  DateFilter _dateFilter = DateFilter.all;
  TransactionSort _sort = TransactionSort.newest;
  String? _categoryFilter;
  DateTimeRange? _customRange;
  bool _searchOpen = false;

  int get _activeFilterCount {
    var count = 0;
    if (_typeFilter != TransactionTypeFilter.all) count++;
    if (_dateFilter != DateFilter.all) count++;
    if (_sort != TransactionSort.newest) count++;
    if (_categoryFilter != null) count++;
    return count;
  }

  Future<void> _openQuickAdd() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final action = await showModalBottomSheet<TransactionQuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const TransactionQuickSheet(),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case TransactionQuickAction.cashIn:
        await _openCashAdd('income');
        break;
      case TransactionQuickAction.cashOut:
        await _openCashAdd('expense');
        break;
      case TransactionQuickAction.savings:
        await _openSavingsAdd();
        break;
      case TransactionQuickAction.debt:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const DebtScreen(openAddOnStart: true),
          ),
        );
        break;
    }
  }

  Future<void> _openCashAdd(String type) async {
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

  Future<void> _openSavingsAdd() async {
    final transactions = context.read<TransactionProvider>();
    final savings = context.read<SavingsProvider>();
    final availableBalance = transactions.balance - savings.balance;

    final changed = await showSavingsTransferSheet(
      context,
      deposit: true,
      availableBalance: availableBalance,
    );

    if (!mounted || changed != true) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Money moved to savings.')));
  }

  Future<void> _editTransaction(CashTransaction item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: item),
      ),
    );

    if (!mounted || updated != true) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction updated.')));
  }

  Future<void> _duplicateTransaction(
    TransactionProvider provider,
    CashTransaction item,
  ) async {
    await HapticFeedback.mediumImpact();

    final success = await provider.addTransaction(
      CashTransaction(
        type: item.type,
        amount: item.amount,
        category: item.category,
        date: DateTime.now(),
        note: item.note,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Transaction duplicated.'
              : provider.errorMessage ?? 'Could not duplicate transaction.',
        ),
      ),
    );
  }

  Future<void> _showCashDetails(
    TransactionProvider provider,
    CashTransaction item,
  ) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final action = await showModalBottomSheet<CashAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => CashDetailSheet(item: item),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case CashAction.edit:
        await _editTransaction(item);
        break;
      case CashAction.duplicate:
        await _duplicateTransaction(provider, item);
        break;
      case CashAction.delete:
        final confirmed = await _confirmDelete(item);
        if (confirmed && mounted) {
          await HapticFeedback.mediumImpact();
          await _deleteWithUndo(provider, item);
        }
        break;
    }
  }

  Future<void> _showSavingsDetails(SavingsTransfer item) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final openManage = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SavingsDetailSheet(item: item),
    );

    if (!mounted || openManage != true) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SavingsScreen()),
    );
  }

  Future<bool> _confirmDelete(CashTransaction item) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: Text(
              item.note.isEmpty
                  ? 'Delete this ${item.category} transaction?'
                  : 'Delete "${item.note}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteWithUndo(
    TransactionProvider provider,
    CashTransaction item,
  ) async {
    if (item.id == null) return;

    final deleted = await provider.deleteTransaction(item.id!);
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Could not delete transaction.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final restored = await provider.restoreTransaction(item);
              if (!mounted || restored) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not restore transaction.')),
              );
            },
          ),
        ),
      );
  }

  List<ActivityItem> _buildActivities(
    List<CashTransaction> transactions,
    List<SavingsTransfer> savings,
    List<DebtItem> debts,
    List<DebtPayment> debtPayments,
  ) {
    final debtById = <int, DebtItem>{
      for (final debt in debts)
        if (debt.id != null) debt.id!: debt,
    };

    final linkedTransactionIds = <int>{
      for (final payment in debtPayments)
        if (payment.transactionId != null) payment.transactionId!,
    };
    final linkedSavingsTransferIds = <int>{
      for (final payment in debtPayments)
        if (payment.savingsTransferId != null) payment.savingsTransferId!,
    };

    final debtActivities = <DebtActivity>[
      ...debts.map((debt) => DebtActivity(debt: debt, payment: null)),
      ...debtPayments.map((payment) {
        final debt = debtById[payment.debtId];
        if (debt == null) return null;
        return DebtActivity(debt: debt, payment: payment);
      }).whereType<DebtActivity>(),
    ];

    return [
      ...transactions
          .where((item) => !linkedTransactionIds.contains(item.id))
          .map(ActivityItem.cash),
      ...savings
          .where((item) => !linkedSavingsTransferIds.contains(item.id))
          .map(ActivityItem.savings),
      ...debtActivities.map(ActivityItem.debt),
    ];
  }

  bool _matchesType(ActivityItem item) {
    switch (_typeFilter) {
      case TransactionTypeFilter.all:
        return true;
      case TransactionTypeFilter.income:
        return item.cash?.isIncome == true;
      case TransactionTypeFilter.expense:
        return item.cash != null && item.cash!.isIncome == false;
      case TransactionTypeFilter.savings:
        return item.savings != null;
      case TransactionTypeFilter.debt:
        return item.debt != null;
    }
  }

  bool _matchesDate(ActivityItem item) {
    final now = DateTime.now();

    switch (_dateFilter) {
      case DateFilter.all:
        return true;
      case DateFilter.today:
        return isSameCalendarDay(item.date, now);
      case DateFilter.thisWeek:
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final end = start.add(const Duration(days: 7));
        return !item.date.isBefore(start) && item.date.isBefore(end);
      case DateFilter.thisMonth:
        return item.date.year == now.year && item.date.month == now.month;
      case DateFilter.custom:
        if (_customRange == null) return true;

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

        return !item.date.isBefore(start) && !item.date.isAfter(end);
    }
  }

  bool _matchesCategory(ActivityItem item) {
    if (_categoryFilter == null) return true;
    return item.cash?.category == _categoryFilter;
  }

  bool _matchesQuery(ActivityItem item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;

    return item.searchText.contains(query);
  }

  List<ActivityItem> _sortItems(List<ActivityItem> items) {
    final sorted = [...items];

    switch (_sort) {
      case TransactionSort.newest:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case TransactionSort.oldest:
        sorted.sort((a, b) => a.date.compareTo(b.date));
        break;
      case TransactionSort.highestAmount:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case TransactionSort.lowestAmount:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return sorted;
  }

  Future<void> _showFilters(List<String> categories) async {
    final result = await showModalBottomSheet<TransactionFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => TransactionFilterSheet(
        initialType: _typeFilter,
        initialDate: _dateFilter,
        initialSort: _sort,
        initialCategory: _categoryFilter,
        initialRange: _customRange,
        categories: categories,
      ),
    );

    if (!mounted || result == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    setState(() {
      _typeFilter = result.type;
      _dateFilter = result.date;
      _sort = result.sort;
      _categoryFilter = result.category;
      _customRange = result.range;
    });
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _typeFilter = TransactionTypeFilter.all;
      _dateFilter = DateFilter.all;
      _sort = TransactionSort.newest;
      _categoryFilter = null;
      _customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>();
    final savings = context.watch<SavingsProvider>();
    final debts = context.watch<DebtProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final categories =
        categoryProvider.categories.map((item) => item.name).toSet().toList()
          ..sort();

    final activities = _sortItems(
      _buildActivities(
            transactions.transactions,
            savings.items,
            debts.items,
            debts.payments,
          )
          .where(_matchesType)
          .where(_matchesDate)
          .where(_matchesCategory)
          .where(_matchesQuery)
          .toList(),
    );

    final loading = transactions.isLoading || savings.loading || debts.loading;
    final hasData =
        transactions.transactions.isNotEmpty ||
        savings.items.isNotEmpty ||
        debts.items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transactions',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Cash, savings and debt activity',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _query = '';
              });
            },
            icon: Icon(
              _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          IconButton.filled(
            tooltip: 'Quick Add',
            onPressed: _openQuickAdd,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
        ],
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchOpen
                  ? Card(
                      key: const ValueKey('search'),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            hintText:
                                'Search note, category, savings or amount',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-search')),
            ),
            if (_searchOpen) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _activeFilterCount == 0
                        ? 'All activity'
                        : '$_activeFilterCount filters active',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_activeFilterCount > 0)
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  child: IconButton.filledTonal(
                    tooltip: 'Filter & Sort',
                    onPressed: () => _showFilters(categories),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (loading && !hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (activities.isEmpty)
              TransactionEmptyView(
                hasFilters: _activeFilterCount > 0 || _query.trim().isNotEmpty,
                onReset: _resetFilters,
                onAdd: _openQuickAdd,
              )
            else
              ..._groupedList(transactions, activities),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedList(
    TransactionProvider provider,
    List<ActivityItem> items,
  ) {
    final widgets = <Widget>[];
    String? previousGroup;

    for (final activity in items) {
      final group = transactionGroupLabel(activity.date);

      if (group != previousGroup) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: previousGroup == null ? 0 : 10,
              bottom: 8,
            ),
            child: Text(group, style: Theme.of(context).textTheme.titleSmall),
          ),
        );
        previousGroup = group;
      }

      if (activity.cash != null) {
        final item = activity.cash!;

        widgets.add(
          Dismissible(
            key: ValueKey('transaction-${item.id}'),
            direction: DismissDirection.horizontal,
            background: const TransactionSwipeBackground(
              alignment: Alignment.centerLeft,
              icon: Icons.edit_outlined,
              label: 'Edit',
              destructive: false,
            ),
            secondaryBackground: const TransactionSwipeBackground(
              alignment: Alignment.centerRight,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await HapticFeedback.selectionClick();
                await _editTransaction(item);
                return false;
              }

              await HapticFeedback.mediumImpact();
              return _confirmDelete(item);
            },
            onDismissed: (_) => _deleteWithUndo(provider, item),
            child: TransactionTile(
              title: item.note.isEmpty ? item.category : item.note,
              category: item.category,
              amount: item.amount,
              isIncome: item.isIncome,
              dateLabel: DateFormat('dd MMM').format(item.date),
              onTap: () => _showCashDetails(provider, item),
            ),
          ),
        );
      } else if (activity.savings != null) {
        final item = activity.savings!;
        widgets.add(
          SavingsActivityTile(
            item: item,
            onTap: () => _showSavingsDetails(item),
          ),
        );
      } else {
        final item = activity.debt!;
        widgets.add(
          DebtActivityTile(
            activity: item,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => DebtScreen(openPaymentId: item.payment?.id),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
