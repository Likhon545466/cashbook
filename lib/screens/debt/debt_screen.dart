import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt_model.dart';
import '../../models/debt_payment_model.dart';
import '../../providers/debt_provider.dart';
import '../../utils/money_formatter.dart';
import 'widgets/debt_card.dart';
import 'widgets/debt_details_sheet.dart';
import 'widgets/debt_due_extension_sheet.dart';
import 'widgets/debt_editor_sheet.dart';
import 'widgets/debt_empty_view.dart';
import 'widgets/debt_models.dart';
import 'widgets/debt_payment_sheet.dart';
import 'widgets/debt_summary_header.dart';

class DebtScreen extends StatefulWidget {
  final bool openAddOnStart;
  final int? openPaymentId;

  const DebtScreen({
    super.key,
    this.openAddOnStart = false,
    this.openPaymentId,
  });

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  DebtFilter _filter = DebtFilter.all;
  DebtSort _sort = DebtSort.newest;
  bool _searchOpen = false;
  bool _showPaid = false;
  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<DebtProvider>().load();

      if (!mounted) return;

      if (widget.openPaymentId != null) {
        final payment = context
            .read<DebtProvider>()
            .payments
            .cast<DebtPayment?>()
            .firstWhere(
              (item) => item?.id == widget.openPaymentId,
              orElse: () => null,
            );
        if (payment != null) {
          final debt = context
              .read<DebtProvider>()
              .items
              .cast<DebtItem?>()
              .firstWhere(
                (item) => item?.id == payment.debtId,
                orElse: () => null,
              );
          if (debt != null && mounted) {
            await _editPayment(debt, payment);
          }
        }
        return;
      }

      if (widget.openAddOnStart) {
        await _addDebt();
      }
    });
  }

  Future<void> _addDebt() async {
    final draft = await showModalBottomSheet<DebtDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DebtEditorSheet(),
    );

    if (!mounted || draft == null) return;

    final provider = context.read<DebtProvider>();
    final success = await provider.addDebt(
      direction: draft.direction,
      person: draft.person,
      amount: draft.amount,
      createdAt: draft.createdAt,
      dueDate: draft.dueDate,
      note: draft.note,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Debt saved.'
              : provider.errorMessage ?? 'Could not save debt.',
        ),
      ),
    );
  }

  Future<void> _editDebt(DebtItem item) async {
    final draft = await showModalBottomSheet<DebtDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtEditorSheet(item: item),
    );

    if (!mounted || draft == null) return;

    final dueChanged = !_sameNullableDay(item.dueDate, draft.dueDate);
    if (dueChanged) {
      final oldLabel = item.dueDate == null
          ? 'No due date'
          : DateFormat('dd MMM yyyy').format(item.dueDate!);
      final newLabel = draft.dueDate == null
          ? 'No due date'
          : DateFormat('dd MMM yyyy').format(draft.dueDate!);

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Correct due date?'),
              content: Text(
                '$oldLabel → $newLabel\n\n'
                'This is treated as a correction and will not count as an extension.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Correct Date'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted || !confirmed) return;
    }

    final provider = context.read<DebtProvider>();
    final success = await provider.updateDebt(
      item.copyWith(
        direction: draft.direction,
        person: draft.person,
        amount: draft.amount,
        createdAt: draft.createdAt,
        dueDate: draft.dueDate,
        clearDueDate: draft.dueDate == null,
        note: draft.note,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Debt updated.'
              : provider.errorMessage ?? 'Could not update debt.',
        ),
      ),
    );
  }

  bool _sameNullableDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _deleteDebt(DebtItem item) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete debt?'),
            content: Text(
              'Delete ${item.person} and all payment history for this debt?',
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

    if (!mounted || !confirmed) return;

    final provider = context.read<DebtProvider>();
    final success = await provider.deleteDebt(item);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Debt deleted.'
              : provider.errorMessage ?? 'Could not delete debt.',
        ),
      ),
    );
  }

  Future<void> _addPayment(DebtItem debt) async {
    final provider = context.read<DebtProvider>();
    final remaining = provider.remainingFor(debt);

    if (remaining <= 0) return;

    final draft = await showModalBottomSheet<PaymentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtPaymentSheet(debt: debt, remaining: remaining),
    );

    if (!mounted || draft == null) return;

    final success = await provider.addPayment(
      debt: debt,
      amount: draft.amount,
      date: draft.date,
      note: draft.note,
      source: draft.source,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Payment recorded.'
              : provider.errorMessage ?? 'Could not save payment.',
        ),
      ),
    );
  }

  Future<void> _extendDueDate(DebtItem debt) async {
    final provider = context.read<DebtProvider>();
    if (provider.remainingFor(debt) <= 0) return;

    final draft = await showModalBottomSheet<DueExtensionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtDueExtensionSheet(debt: debt),
    );

    if (!mounted || draft == null) return;

    final success = await provider.extendDueDate(
      debt: debt,
      newDueDate: draft.newDueDate,
      note: draft.note,
    );

    if (!mounted) return;

    if (success) {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Due date extended to ${DateFormat('dd MMM yyyy').format(draft.newDueDate)}.'
              : provider.errorMessage ?? 'Could not extend due date.',
        ),
      ),
    );
  }

  Future<void> _editPayment(DebtItem debt, DebtPayment payment) async {
    final provider = context.read<DebtProvider>();
    final maxAmount = provider.remainingFor(debt) + payment.amount;

    final draft = await showModalBottomSheet<PaymentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          DebtPaymentSheet(debt: debt, remaining: maxAmount, payment: payment),
    );

    if (!mounted || draft == null) return;

    final success = await provider.updatePayment(
      payment: payment,
      debt: debt,
      amount: draft.amount,
      date: draft.date,
      note: draft.note,
      source: draft.source,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Payment updated.'
              : provider.errorMessage ?? 'Could not update payment.',
        ),
      ),
    );
  }

  Future<void> _deletePayment(DebtPayment payment) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete payment?'),
            content: Text(
              'Remove ${MoneyFormatter.currency(payment.amount)} from payment history?',
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

    if (!mounted || !confirmed) return;

    final provider = context.read<DebtProvider>();
    final success = await provider.deletePayment(payment);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not remove payment.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Payment deleted.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final restored = await provider.restorePayment(payment);
              if (!mounted || restored) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.errorMessage ?? 'Could not restore payment.',
                  ),
                ),
              );
            },
          ),
        ),
      );
  }

  Future<void> _openDetails(DebtItem item) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DebtDetailsSheet(
          item: item,
          onEdit: () => _editDebt(item),
          onExtend: () => _extendDueDate(item),
          onAddPayment: () => _addPayment(item),
          onEditPayment: (payment) => _editPayment(item, payment),
          onDeletePayment: (payment) => _deletePayment(payment),
          onDeleteDebt: () => _deleteDebt(item),
        );
      },
    );
  }

  Future<void> _chooseSort() async {
    final selected = await showModalBottomSheet<DebtSort>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sort Debt',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final sort in DebtSort.values)
                ListTile(
                  onTap: () => Navigator.pop(sheetContext, sort),
                  leading: Icon(debtSortIcon(sort)),
                  title: Text(debtSortLabel(sort)),
                  trailing: _sort == sort
                      ? const Icon(Icons.check_rounded)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _sort = selected);
  }

  List<DebtItem> _visibleItems(DebtProvider provider) {
    final query = _query.trim().toLowerCase();

    final filtered = provider.items.where((item) {
      final status = provider.statusFor(item);

      final matchesFilter = switch (_filter) {
        DebtFilter.all => _showPaid || status != 'Paid',
        DebtFilter.youOwe => item.isYouOwe && (_showPaid || status != 'Paid'),
        DebtFilter.owedToYou =>
          !item.isYouOwe && (_showPaid || status != 'Paid'),
        DebtFilter.open => provider.remainingFor(item) > 0,
        DebtFilter.overdue => status == 'Overdue',
        DebtFilter.paid => status == 'Paid',
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return '${item.person} ${item.note} $status ${item.amount}'
          .toLowerCase()
          .contains(query);
    }).toList();

    switch (_sort) {
      case DebtSort.newest:
        filtered.sort((a, b) {
          final aPriority = debtPriority(provider.statusFor(a), a.dueDate);
          final bPriority = debtPriority(provider.statusFor(b), b.dueDate);

          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case DebtSort.dueSoon:
        filtered.sort((a, b) {
          final aDue = a.dueDate;
          final bDue = b.dueDate;

          if (aDue == null && bDue == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (aDue == null) return 1;
          if (bDue == null) return -1;
          return aDue.compareTo(bDue);
        });
        break;
      case DebtSort.highestRemaining:
        filtered.sort(
          (a, b) =>
              provider.remainingFor(b).compareTo(provider.remainingFor(a)),
        );
        break;
      case DebtSort.person:
        filtered.sort(
          (a, b) => a.person.toLowerCase().compareTo(b.person.toLowerCase()),
        );
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();
    final filtered = _visibleItems(provider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Debt', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(
              'Owe • Owed to you',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search debt',
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
          IconButton(
            tooltip: 'Sort',
            onPressed: _chooseSort,
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton.filled(
            tooltip: 'Add debt',
            onPressed: _addDebt,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchOpen
                  ? Card(
                      key: const ValueKey('debt-search'),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          autofocus: true,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            hintText: 'Search person, note, status or amount',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-debt-search')),
            ),
            if (_searchOpen) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DebtSummaryCard(
                    title: 'You Owe',
                    amount: provider.totalYouOwe,
                    icon: Icons.call_made_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DebtSummaryCard(
                    title: 'Owed to You',
                    amount: provider.totalOwedToYou,
                    icon: Icons.call_received_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DebtNetPositionCard(
              netPosition: provider.netPosition,
              openCount: provider.openCount,
              overdueCount: provider.overdueCount,
              dueSoonCount: provider.dueSoonCount,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DebtCustomFilterChip(
                    label: 'All',
                    selected: _filter == DebtFilter.all,
                    onTap: () => setState(() {
                      _filter = DebtFilter.all;
                    }),
                  ),
                  const SizedBox(width: 8),
                  DebtCustomFilterChip(
                    label: 'You Owe',
                    selected: _filter == DebtFilter.youOwe,
                    onTap: () => setState(() {
                      _filter = DebtFilter.youOwe;
                    }),
                  ),
                  const SizedBox(width: 8),
                  DebtCustomFilterChip(
                    label: 'Owed to You',
                    selected: _filter == DebtFilter.owedToYou,
                    onTap: () => setState(() {
                      _filter = DebtFilter.owedToYou;
                    }),
                  ),
                  const SizedBox(width: 8),
                  DebtCustomFilterChip(
                    label: 'Open',
                    selected: _filter == DebtFilter.open,
                    onTap: () => setState(() {
                      _filter = DebtFilter.open;
                    }),
                  ),
                  const SizedBox(width: 8),
                  DebtCustomFilterChip(
                    label: 'Overdue',
                    selected: _filter == DebtFilter.overdue,
                    onTap: () => setState(() {
                      _filter = DebtFilter.overdue;
                    }),
                  ),
                  const SizedBox(width: 8),
                  DebtCustomFilterChip(
                    label: 'Paid',
                    selected: _filter == DebtFilter.paid,
                    onTap: () => setState(() {
                      _filter = DebtFilter.paid;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} shown • ${debtSortLabel(_sort)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_filter != DebtFilter.paid)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      setState(() => _showPaid = !_showPaid);
                    },
                    icon: Icon(
                      _showPaid
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(_showPaid ? 'Hide Paid' : 'Show Paid'),
                  ),
                if (_filter != DebtFilter.all || _query.isNotEmpty)
                  IconButton(
                    tooltip: 'Reset filters',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _filter = DebtFilter.all;
                        _query = '';
                      });
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 19),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.loading && provider.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              DebtEmptyView(
                hasFilters: _filter != DebtFilter.all || _query.isNotEmpty,
                onAdd: _addDebt,
                onReset: () {
                  setState(() {
                    _filter = DebtFilter.all;
                    _query = '';
                  });
                },
              )
            else
              ...filtered.map(
                (item) => DebtTile(
                  item: item,
                  remaining: provider.remainingFor(item),
                  paid: provider.paidFor(item),
                  progress: provider.progressFor(item),
                  status: provider.statusFor(item),
                  extensionCount: provider.extensionCountFor(item),
                  onTap: () => _openDetails(item),
                  onPayment: provider.remainingFor(item) <= 0
                      ? null
                      : () => _addPayment(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
