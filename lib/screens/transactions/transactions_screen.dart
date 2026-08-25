import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/debt_model.dart';
import '../../models/debt_payment_model.dart';
import '../../models/savings_transfer_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/savings_transfer_sheet.dart';
import '../../widgets/transaction_tile.dart';
import '../debt/debt_screen.dart';
import '../savings/savings_screen.dart';
import 'add_transaction_screen.dart';

enum TransactionTypeFilter { all, income, expense, savings, debt }

enum DateFilter { all, today, thisWeek, thisMonth, custom }

enum TransactionSort { newest, oldest, highestAmount, lowestAmount }

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

    final action = await showModalBottomSheet<_TransactionQuickAction>(
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
              _TransactionQuickTile(
                icon: Icons.south_west_rounded,
                title: 'Cash In',
                color: AppSemanticColors.income(sheetContext),
                onTap: () =>
                    Navigator.pop(sheetContext, _TransactionQuickAction.cashIn),
              ),
              _TransactionQuickTile(
                icon: Icons.north_east_rounded,
                title: 'Cash Out',
                color: AppSemanticColors.expense(sheetContext),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _TransactionQuickAction.cashOut,
                ),
              ),
              _TransactionQuickTile(
                icon: Icons.savings_outlined,
                title: 'Add to Savings',
                color: AppSemanticColors.savings(sheetContext),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _TransactionQuickAction.savings,
                ),
              ),
              _TransactionQuickTile(
                icon: Icons.handshake_outlined,
                title: 'Add Debt',
                color: Theme.of(sheetContext).colorScheme.primary,
                onTap: () =>
                    Navigator.pop(sheetContext, _TransactionQuickAction.debt),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _TransactionQuickAction.cashIn:
        await _openCashAdd('income');
        break;
      case _TransactionQuickAction.cashOut:
        await _openCashAdd('expense');
        break;
      case _TransactionQuickAction.savings:
        await _openSavingsAdd();
        break;
      case _TransactionQuickAction.debt:
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

    final action = await showModalBottomSheet<_CashAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final color = item.isIncome
            ? AppSemanticColors.income(sheetContext)
            : AppSemanticColors.expense(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailHero(
                  icon: item.isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: color,
                  amount:
                      '${item.isIncome ? '+' : '-'}${MoneyFormatter.currency(item.amount)}',
                  title: item.note.isEmpty ? item.category : item.note,
                  badge: item.isIncome ? 'Cash In' : 'Cash Out',
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: item.category,
                ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: DateFormat('dd MMMM yyyy').format(item.date),
                ),
                if (item.note.isNotEmpty)
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Note',
                    value: item.note,
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(sheetContext, _CashAction.duplicate),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Duplicate'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            Navigator.pop(sheetContext, _CashAction.edit),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _CashAction.delete),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(sheetContext).colorScheme.error,
                    ),
                    label: Text(
                      'Delete Transaction',
                      style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _CashAction.edit:
        await _editTransaction(item);
        break;
      case _CashAction.duplicate:
        await _duplicateTransaction(provider, item);
        break;
      case _CashAction.delete:
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
      builder: (sheetContext) {
        final color = item.isDeposit
            ? AppSemanticColors.savings(sheetContext)
            : AppSemanticColors.warning(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailHero(
                  icon: item.isDeposit
                      ? Icons.savings_outlined
                      : Icons.undo_rounded,
                  color: color,
                  amount:
                      '${item.isDeposit ? '+' : '-'}${MoneyFormatter.currency(item.amount)}',
                  title: item.isDeposit
                      ? 'Added to Savings'
                      : 'Withdrawn from Savings',
                  badge: 'Internal Transfer',
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Type',
                  value: item.isDeposit
                      ? 'Available → Savings'
                      : 'Savings → Available',
                ),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Date',
                  value: DateFormat('dd MMM yyyy, hh:mm a').format(item.date),
                ),
                if (item.note.isNotEmpty)
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Note',
                    value: item.note,
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Manage Savings'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Savings transfers do not count as income or expense.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
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

  List<_ActivityItem> _buildActivities(
    List<CashTransaction> transactions,
    List<SavingsTransfer> savings,
    List<DebtItem> debts,
    List<DebtPayment> debtPayments,
  ) {
    final debtById = <int, DebtItem>{
      for (final debt in debts)
        if (debt.id != null) debt.id!: debt,
    };

    // A debt payment has its own Debt Payment History entry. Its linked
    // cash transaction and savings transfer are implementation records and
    // must not appear as separate activities, otherwise one payment looks
    // like multiple transactions.
    final linkedTransactionIds = <int>{
      for (final payment in debtPayments)
        if (payment.transactionId != null) payment.transactionId!,
    };
    final linkedSavingsTransferIds = <int>{
      for (final payment in debtPayments)
        if (payment.savingsTransferId != null) payment.savingsTransferId!,
    };

    final debtActivities = <_DebtActivity>[
      ...debts.map((debt) => _DebtActivity(debt: debt, payment: null)),
      ...debtPayments.map((payment) {
        final debt = debtById[payment.debtId];
        if (debt == null) return null;
        return _DebtActivity(debt: debt, payment: payment);
      }).whereType<_DebtActivity>(),
    ];

    return [
      ...transactions
          .where((item) => !linkedTransactionIds.contains(item.id))
          .map(_ActivityItem.cash),
      ...savings
          .where((item) => !linkedSavingsTransferIds.contains(item.id))
          .map(_ActivityItem.savings),
      ...debtActivities.map(_ActivityItem.debt),
    ];
  }

  bool _matchesType(_ActivityItem item) {
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

  bool _matchesDate(_ActivityItem item) {
    final now = DateTime.now();

    switch (_dateFilter) {
      case DateFilter.all:
        return true;
      case DateFilter.today:
        return _isSameDay(item.date, now);
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

  bool _matchesCategory(_ActivityItem item) {
    if (_categoryFilter == null) return true;
    return item.cash?.category == _categoryFilter;
  }

  bool _matchesQuery(_ActivityItem item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;

    return item.searchText.contains(query);
  }

  List<_ActivityItem> _sortItems(List<_ActivityItem> items) {
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

  Future<DateTimeRange?> _pickCustomRange(DateTimeRange? current) {
    final now = DateTime.now();

    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          current ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
  }

  Future<void> _showFilters(List<String> categories) async {
    var tempType = _typeFilter;
    var tempDate = _dateFilter;
    var tempSort = _sort;
    var tempCategory = _categoryFilter;
    var tempRange = _customRange;

    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter & Sort',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    const _FilterTitle('Activity Type'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _VisibleChoiceChip(
                          label: 'All',
                          selected: tempType == TransactionTypeFilter.all,
                          onSelected: () => setSheetState(
                            () => tempType = TransactionTypeFilter.all,
                          ),
                        ),
                        _VisibleChoiceChip(
                          label: 'Cash In',
                          selected: tempType == TransactionTypeFilter.income,
                          semanticColor: AppSemanticColors.income(context),
                          onSelected: () => setSheetState(
                            () => tempType = TransactionTypeFilter.income,
                          ),
                        ),
                        _VisibleChoiceChip(
                          label: 'Cash Out',
                          selected: tempType == TransactionTypeFilter.expense,
                          semanticColor: AppSemanticColors.expense(context),
                          onSelected: () => setSheetState(
                            () => tempType = TransactionTypeFilter.expense,
                          ),
                        ),
                        _VisibleChoiceChip(
                          label: 'Savings',
                          selected: tempType == TransactionTypeFilter.savings,
                          semanticColor: AppSemanticColors.savings(context),
                          onSelected: () => setSheetState(
                            () => tempType = TransactionTypeFilter.savings,
                          ),
                        ),
                        _VisibleChoiceChip(
                          label: 'Debt',
                          selected: tempType == TransactionTypeFilter.debt,
                          semanticColor: Theme.of(context).colorScheme.primary,
                          onSelected: () => setSheetState(
                            () => tempType = TransactionTypeFilter.debt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _FilterTitle('Date'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in DateFilter.values.where(
                          (item) => item != DateFilter.custom,
                        ))
                          _VisibleChoiceChip(
                            label: _dateChipLabel(option),
                            selected: tempDate == option,
                            onSelected: () =>
                                setSheetState(() => tempDate = option),
                          ),
                        _VisibleChoiceChip(
                          label: tempRange == null
                              ? 'Custom Range'
                              : '${DateFormat('dd MMM').format(tempRange!.start)} - '
                                    '${DateFormat('dd MMM').format(tempRange!.end)}',
                          selected: tempDate == DateFilter.custom,
                          onSelected: () async {
                            final picked = await _pickCustomRange(tempRange);
                            if (picked == null) return;
                            setSheetState(() {
                              tempRange = picked;
                              tempDate = DateFilter.custom;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _FilterTitle('Category'),
                    const SizedBox(height: 6),
                    Text(
                      'Category applies to Cash In / Cash Out. Savings activity '
                      'is hidden when a category filter is active.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _VisibleChoiceChip(
                          label: 'All Categories',
                          selected: tempCategory == null,
                          onSelected: () =>
                              setSheetState(() => tempCategory = null),
                        ),
                        ...categories.map(
                          (category) => _VisibleChoiceChip(
                            label: category,
                            selected: tempCategory == category,
                            onSelected: () =>
                                setSheetState(() => tempCategory = category),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _FilterTitle('Sort'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TransactionSort.values.map((sort) {
                        return _VisibleChoiceChip(
                          label: _sortLabelFor(sort),
                          selected: tempSort == sort,
                          onSelected: () =>
                              setSheetState(() => tempSort = sort),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                tempType = TransactionTypeFilter.all;
                                tempDate = DateFilter.all;
                                tempSort = TransactionSort.newest;
                                tempCategory = null;
                                tempRange = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              _FilterResult(
                                type: tempType,
                                date: tempDate,
                                sort: tempSort,
                                category: tempCategory,
                                range: tempRange,
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              _EmptyTransactions(
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
    List<_ActivityItem> items,
  ) {
    final widgets = <Widget>[];
    String? previousGroup;

    for (final activity in items) {
      final group = _groupLabel(activity.date);

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
            background: const _SwipeBackground(
              alignment: Alignment.centerLeft,
              icon: Icons.edit_outlined,
              label: 'Edit',
              destructive: false,
            ),
            secondaryBackground: const _SwipeBackground(
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
          _SavingsActivityTile(
            item: item,
            onTap: () => _showSavingsDetails(item),
          ),
        );
      } else {
        final item = activity.debt!;
        widgets.add(
          _DebtActivityTile(
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

  String _sortLabelFor(TransactionSort sort) {
    switch (sort) {
      case TransactionSort.newest:
        return 'Newest';
      case TransactionSort.oldest:
        return 'Oldest';
      case TransactionSort.highestAmount:
        return 'Highest Amount';
      case TransactionSort.lowestAmount:
        return 'Lowest Amount';
    }
  }

  String _dateChipLabel(DateFilter value) {
    switch (value) {
      case DateFilter.all:
        return 'Any Date';
      case DateFilter.today:
        return 'Today';
      case DateFilter.thisWeek:
        return 'This Week';
      case DateFilter.thisMonth:
        return 'This Month';
      case DateFilter.custom:
        return 'Custom';
    }
  }

  static String _groupLabel(DateTime date) {
    final now = DateTime.now();

    if (_isSameDay(date, now)) return 'Today';

    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Yesterday';

    if (date.year == now.year) {
      return DateFormat('EEEE, dd MMMM').format(date);
    }

    return DateFormat('dd MMMM yyyy').format(date);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

enum _TransactionQuickAction { cashIn, cashOut, savings, debt }

class _TransactionQuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _TransactionQuickTile({
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

enum _CashAction { edit, duplicate, delete }

class _DebtActivity {
  final DebtItem debt;
  final DebtPayment? payment;

  const _DebtActivity({required this.debt, required this.payment});

  bool get isPayment => payment != null;
  DateTime get date => payment?.date ?? debt.createdAt;
  int get amount => payment?.amount ?? debt.amount;

  String get title {
    if (!isPayment) {
      return debt.isYouOwe
          ? 'Debt Added • You Owe'
          : 'Debt Added • Owed to You';
    }

    return debt.isYouOwe ? 'Debt Repayment' : 'Debt Collection';
  }

  String get subtitle {
    final note = payment?.note ?? debt.note;
    return note.isEmpty ? debt.person : '${debt.person} • $note';
  }
}

class _ActivityItem {
  final CashTransaction? cash;
  final SavingsTransfer? savings;
  final _DebtActivity? debt;

  const _ActivityItem._({this.cash, this.savings, this.debt});

  factory _ActivityItem.cash(CashTransaction item) {
    return _ActivityItem._(cash: item);
  }

  factory _ActivityItem.savings(SavingsTransfer item) {
    return _ActivityItem._(savings: item);
  }

  factory _ActivityItem.debt(_DebtActivity item) {
    return _ActivityItem._(debt: item);
  }

  DateTime get date {
    if (cash != null) return cash!.date;
    if (savings != null) return savings!.date;
    return debt!.date;
  }

  int get amount {
    if (cash != null) return cash!.amount;
    if (savings != null) return savings!.amount;
    return debt!.amount;
  }

  String get searchText {
    final transaction = cash;
    if (transaction != null) {
      return '${transaction.note} ${transaction.category} '
              '${transaction.amount} '
              '${transaction.isIncome ? 'cash in income' : 'cash out expense'}'
          .toLowerCase();
    }

    final savingsItem = savings;
    if (savingsItem != null) {
      return '${savingsItem.note} ${savingsItem.amount} savings reserve '
              '${savingsItem.isDeposit ? 'added deposit' : 'withdrawn withdraw'}'
          .toLowerCase();
    }

    final debtItem = debt!;
    return '${debtItem.title} ${debtItem.subtitle} ${debtItem.amount} debt '
            '${debtItem.debt.isYouOwe ? 'you owe borrowed' : 'owed to you lent'}'
        .toLowerCase();
  }
}

class _SavingsActivityTile extends StatelessWidget {
  final SavingsTransfer item;
  final VoidCallback onTap;

  const _SavingsActivityTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.isDeposit
        ? AppSemanticColors.savings(context)
        : AppSemanticColors.warning(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isDeposit ? Icons.savings_outlined : Icons.undo_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isDeposit
                          ? 'Added to Savings'
                          : 'Withdrawn from Savings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.note.isEmpty ? 'Internal Transfer' : item.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.isDeposit ? '+' : '-'}${MoneyFormatter.currency(item.amount)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM').format(item.date),
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

class _DebtActivityTile extends StatelessWidget {
  final _DebtActivity activity;
  final VoidCallback onTap;

  const _DebtActivityTile({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = activity.debt.isYouOwe
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  activity.isPayment
                      ? Icons.payments_outlined
                      : Icons.handshake_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activity.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyFormatter.currency(activity.amount),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM').format(activity.date),
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

class _DetailHero extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String amount;
  final String title;
  final String badge;

  const _DetailHero({
    required this.icon,
    required this.color,
    required this.amount,
    required this.title,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          amount,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterResult {
  final TransactionTypeFilter type;
  final DateFilter date;
  final TransactionSort sort;
  final String? category;
  final DateTimeRange? range;

  const _FilterResult({
    required this.type,
    required this.date,
    required this.sort,
    required this.category,
    required this.range,
  });
}

class _FilterTitle extends StatelessWidget {
  final String text;

  const _FilterTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _VisibleChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final FutureOr<void> Function() onSelected;
  final Color? semanticColor;

  const _VisibleChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.semanticColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = semanticColor ?? scheme.primary;
    final foreground = selected ? activeColor : scheme.onSurface;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: activeColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected
            ? activeColor.withValues(alpha: 0.62)
            : Theme.of(context).dividerColor,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final String label;
  final bool destructive;

  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    final left = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!left) ...[
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color),
          if (left) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onReset;
  final VoidCallback onAdd;

  const _EmptyTransactions({
    required this.hasFilters,
    required this.onReset,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 46,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching activity' : 'No activity yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try resetting your search or filters.'
                  : 'Add Cash In, Cash Out or move money to Savings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset filters'),
              )
            else
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
