import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/debt_model.dart';
import '../../models/debt_due_extension_model.dart';
import '../../models/debt_payment_model.dart';
import '../../providers/debt_provider.dart';
import '../../utils/amount_expression.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/smart_amount_field.dart';

enum _DebtFilter { all, youOwe, owedToYou, open, overdue, paid }

enum _DebtSort { newest, dueSoon, highestRemaining, person }

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
  _DebtFilter _filter = _DebtFilter.all;
  _DebtSort _sort = _DebtSort.newest;
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
    final draft = await showModalBottomSheet<_DebtDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DebtEditorSheet(),
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
    final draft = await showModalBottomSheet<_DebtDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DebtEditorSheet(item: item),
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

    final draft = await showModalBottomSheet<_PaymentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaymentSheet(debt: debt, remaining: remaining),
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

    final draft = await showModalBottomSheet<_DueExtensionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DueExtensionSheet(debt: debt),
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

    final draft = await showModalBottomSheet<_PaymentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _PaymentSheet(debt: debt, remaining: maxAmount, payment: payment),
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
        return Consumer<DebtProvider>(
          builder: (context, provider, _) {
            final remaining = provider.remainingFor(item);
            final paid = provider.paidFor(item);
            final progress = provider.progressFor(item);
            final payments = provider.paymentsFor(item);
            final extensions = provider.extensionsFor(item);
            final status = provider.statusFor(item);
            final color = item.isYouOwe
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            item.isYouOwe
                                ? Icons.call_made_rounded
                                : Icons.call_received_rounded,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.person,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.isYouOwe ? 'You owe' : 'Owed to you',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(
                          label: status,
                          color: _statusColor(context, status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _AmountSummary(
                      original: item.amount,
                      paid: paid,
                      remaining: remaining,
                      progress: progress,
                    ),
                    const SizedBox(height: 16),
                    if (item.dueDate != null)
                      _DueBanner(
                        dueDate: item.dueDate!,
                        isPaid: remaining <= 0,
                        extensionCount: extensions.length,
                      ),
                    if (item.dueDate != null) const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created',
                      value: DateFormat('dd MMM yyyy').format(item.createdAt),
                    ),
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: 'Due',
                      value: item.dueDate == null
                          ? 'No due date'
                          : DateFormat('dd MMM yyyy').format(item.dueDate!),
                    ),
                    if (item.note.isNotEmpty)
                      _InfoRow(
                        icon: Icons.notes_rounded,
                        label: 'Note',
                        value: item.note,
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _editDebt(item);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const FittedBox(
                                child: Text(
                                  'Edit Debt',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (remaining > 0) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _extendDueDate(item);
                                },
                                icon: const Icon(
                                  Icons.event_repeat_rounded,
                                  size: 18,
                                ),
                                label: FittedBox(
                                  child: Text(
                                    item.dueDate == null
                                        ? 'Set Due Date'
                                        : 'Extend Date',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _addPayment(item);
                          },
                          icon: const Icon(Icons.payments_outlined, size: 19),
                          label: Text(
                            'Add Payment • ${MoneyFormatter.currency(remaining)} remaining',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                    if (extensions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Due Date History',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${extensions.length} extension${extensions.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ...extensions.map(
                        (extension) =>
                            _DueExtensionHistoryTile(extension: extension),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Payment History',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${payments.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (payments.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No payments recorded yet.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      )
                    else
                      ...payments.map(
                        (payment) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            title: Text(
                              MoneyFormatter.currency(payment.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              [
                                DateFormat('dd MMM yyyy').format(payment.date),
                                payment.source == 'savings'
                                    ? (item.isYouOwe
                                          ? 'Paid from Savings'
                                          : 'Received to Savings')
                                    : (item.isYouOwe
                                          ? 'Paid from Main Balance'
                                          : 'Received to Main Balance'),
                                if (payment.note.isNotEmpty) payment.note,
                              ].join(' • '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit payment',
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _editPayment(item, payment);
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete payment',
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _deletePayment(payment);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _deleteDebt(item);
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(
                          'Delete Debt',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
      },
    );
  }

  Future<void> _chooseSort() async {
    final selected = await showModalBottomSheet<_DebtSort>(
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
              for (final sort in _DebtSort.values)
                ListTile(
                  onTap: () => Navigator.pop(sheetContext, sort),
                  leading: Icon(_sortIcon(sort)),
                  title: Text(_sortLabel(sort)),
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
        _DebtFilter.all => _showPaid || status != 'Paid',
        _DebtFilter.youOwe => item.isYouOwe && (_showPaid || status != 'Paid'),
        _DebtFilter.owedToYou =>
          !item.isYouOwe && (_showPaid || status != 'Paid'),
        _DebtFilter.open => provider.remainingFor(item) > 0,
        _DebtFilter.overdue => status == 'Overdue',
        _DebtFilter.paid => status == 'Paid',
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return '${item.person} ${item.note} $status ${item.amount}'
          .toLowerCase()
          .contains(query);
    }).toList();

    switch (_sort) {
      case _DebtSort.newest:
        filtered.sort((a, b) {
          final aPriority = _debtPriority(provider.statusFor(a), a.dueDate);
          final bPriority = _debtPriority(provider.statusFor(b), b.dueDate);

          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case _DebtSort.dueSoon:
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
      case _DebtSort.highestRemaining:
        filtered.sort(
          (a, b) =>
              provider.remainingFor(b).compareTo(provider.remainingFor(a)),
        );
        break;
      case _DebtSort.person:
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
                  child: _SummaryCard(
                    title: 'You Owe',
                    amount: provider.totalYouOwe,
                    icon: Icons.call_made_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    title: 'Owed to You',
                    amount: provider.totalOwedToYou,
                    icon: Icons.call_received_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _NetPositionCard(
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
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _DebtFilter.all,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.all;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'You Owe',
                    selected: _filter == _DebtFilter.youOwe,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.youOwe;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Owed to You',
                    selected: _filter == _DebtFilter.owedToYou,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.owedToYou;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Open',
                    selected: _filter == _DebtFilter.open,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.open;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Overdue',
                    selected: _filter == _DebtFilter.overdue,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.overdue;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Paid',
                    selected: _filter == _DebtFilter.paid,
                    onTap: () => setState(() {
                      _filter = _DebtFilter.paid;
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
                    '${filtered.length} shown • ${_sortLabel(_sort)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_filter != _DebtFilter.paid)
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
                if (_filter != _DebtFilter.all || _query.isNotEmpty)
                  IconButton(
                    tooltip: 'Reset filters',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _filter = _DebtFilter.all;
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
              _DebtEmpty(
                hasFilters: _filter != _DebtFilter.all || _query.isNotEmpty,
                onAdd: _addDebt,
                onReset: () {
                  setState(() {
                    _filter = _DebtFilter.all;
                    _query = '';
                  });
                },
              )
            else
              ...filtered.map(
                (item) => _DebtTile(
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

class _DebtEditorSheet extends StatefulWidget {
  final DebtItem? item;

  const _DebtEditorSheet({this.item});

  @override
  State<_DebtEditorSheet> createState() => _DebtEditorSheetState();
}

class _DebtEditorSheetState extends State<_DebtEditorSheet> {
  late String _direction;
  late final TextEditingController _person;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _createdAt;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _direction = item?.direction ?? 'you_owe';
    _person = TextEditingController(text: item?.person ?? '');
    _amount = TextEditingController(
      text: item == null ? '' : item.amount.toString(),
    );
    _note = TextEditingController(text: item?.note ?? '');
    _createdAt = item?.createdAt ?? DateTime.now();
    _dueDate = item?.dueDate;
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCreated() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (!mounted || picked == null) return;

    setState(() {
      _createdAt = picked;

      final due = _dueDate;
      if (due != null) {
        final createdDay = DateTime(picked.year, picked.month, picked.day);
        final dueDay = DateTime(due.year, due.month, due.day);

        if (dueDay.isBefore(createdDay)) {
          _dueDate = null;
        }
      }
    });
  }

  Future<void> _pickDue() async {
    final firstDay = DateTime(
      _createdAt.year,
      _createdAt.month,
      _createdAt.day,
    );

    final existing = _dueDate;
    final suggested = _createdAt.add(const Duration(days: 30));

    var initial = existing ?? suggested;
    if (initial.isBefore(firstDay)) {
      initial = firstDay;
    }

    final lastDay = DateTime(_createdAt.year + 20, 12, 31);
    if (initial.isAfter(lastDay)) {
      initial = lastDay;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDay,
      lastDate: lastDay,
    );

    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  void _save() {
    final person = _person.text.trim();
    final amount = AmountExpression.evaluate(_amount.text) ?? 0;

    if (person.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a person and valid amount.')),
      );
      return;
    }

    final due = _dueDate;
    if (due != null) {
      final createdDay = DateTime(
        _createdAt.year,
        _createdAt.month,
        _createdAt.day,
      );
      final dueDay = DateTime(due.year, due.month, due.day);

      if (dueDay.isBefore(createdDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Due date cannot be before created date.'),
          ),
        );
        return;
      }
    }

    Navigator.pop(
      context,
      _DebtDraft(
        direction: _direction,
        person: person,
        amount: amount,
        createdAt: _createdAt,
        dueDate: _dueDate,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null ? 'Add Debt' : 'Edit Debt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DirectionOption(
                    label: 'You Owe',
                    subtitle: 'I borrowed',
                    icon: Icons.call_made_rounded,
                    selected: _direction == 'you_owe',
                    onTap: () => setState(() {
                      _direction = 'you_owe';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionOption(
                    label: 'Owed to You',
                    subtitle: 'I lent',
                    icon: Icons.call_received_rounded,
                    selected: _direction == 'owed_to_you',
                    onTap: () => setState(() {
                      _direction = 'owed_to_you';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartAmountField(
              controller: _amount,
              autofocus: widget.item == null,
              labelText: 'Total Amount',
              hintText: 'Enter amount first',
              compact: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person / Name',
                hintText: 'Who is this debt with?',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCreated,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: FittedBox(
                      child: Text(DateFormat('dd MMM yyyy').format(_createdAt)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDue,
                    icon: const Icon(Icons.event_outlined),
                    label: FittedBox(
                      child: Text(
                        _dueDate == null
                            ? 'Add Due Date'
                            : DateFormat('dd MMM yyyy').format(_dueDate!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_dueDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _dueDate = null;
                  }),
                  child: const Text('Remove due date'),
                ),
              ),
            if (widget.item != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Use this due date field only to correct a mistake. Use Extend Date when the actual deadline is moved.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 180,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional context',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Save Debt' : 'Update Debt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final DebtItem debt;
  final int remaining;
  final DebtPayment? payment;

  const _PaymentSheet({
    required this.debt,
    required this.remaining,
    this.payment,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _useFullRemaining = false;
  String _source = 'main';

  @override
  void initState() {
    super.initState();

    final payment = widget.payment;
    if (payment != null) {
      _amount.text = payment.amount.toString();
      _note.text = payment.note;
      _date = payment.date;
      _source = payment.source;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(
      widget.debt.createdAt.year,
      widget.debt.createdAt.month,
      widget.debt.createdAt.day,
    );
    final initialDate = _date.isBefore(firstDate) ? firstDate : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
    );

    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final amount = AmountExpression.evaluate(_amount.text) ?? 0;

    if (amount <= 0 || amount > widget.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter an amount up to ${MoneyFormatter.currency(widget.remaining)}.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      _PaymentDraft(
        amount: amount,
        date: _date,
        note: _note.text.trim(),
        source: _source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.payment != null
                  ? 'Edit Debt Payment'
                  : (widget.debt.isYouOwe
                        ? 'Record Repayment'
                        : 'Record Collection'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.debt.person} • Remaining ${MoneyFormatter.currency(widget.remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: _useFullRemaining
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _useFullRemaining
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _useFullRemaining = true;
                      _amount.text = widget.remaining.toString();
                      _amount.selection = TextSelection.collapsed(
                        offset: _amount.text.length,
                      );
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _useFullRemaining
                              ? Icons.check_circle_rounded
                              : Icons.done_all_rounded,
                          size: 18,
                          color: _useFullRemaining
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _useFullRemaining
                                ? 'Full remaining selected • ${MoneyFormatter.currency(widget.remaining)}'
                                : 'Use full remaining ${MoneyFormatter.currency(widget.remaining)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _useFullRemaining
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SmartAmountField(
              controller: _amount,
              autofocus: true,
              labelText: 'Amount',
              compact: true,
              onChanged: (_) {
                if (_useFullRemaining) {
                  setState(() => _useFullRemaining = false);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(DateFormat('dd MMM yyyy').format(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        builder: (sheetContext) {
                          final receive = !widget.debt.isYouOwe;
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      receive ? 'Receive To' : 'Pay From',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  title: const Text('Main Balance'),
                                  trailing: _source == 'main'
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext, 'main');
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.savings_outlined),
                                  title: const Text('Savings'),
                                  trailing: _source == 'savings'
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext, 'savings');
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      );

                      if (!mounted || selected == null) return;

                      setState(() => _source = selected);
                    },
                    icon: Icon(
                      _source == 'main'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.savings_outlined,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _source == 'main' ? 'Main Balance' : 'Savings',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.payment != null ? 'Save Changes' : 'Record Payment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtDraft {
  final String direction;
  final String person;
  final int amount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String note;

  const _DebtDraft({
    required this.direction,
    required this.person,
    required this.amount,
    required this.createdAt,
    required this.dueDate,
    required this.note,
  });
}

class _DueExtensionDraft {
  final DateTime newDueDate;
  final String note;

  const _DueExtensionDraft({required this.newDueDate, required this.note});
}

class _DueExtensionSheet extends StatefulWidget {
  final DebtItem debt;

  const _DueExtensionSheet({required this.debt});

  @override
  State<_DueExtensionSheet> createState() => _DueExtensionSheetState();
}

class _DueExtensionSheetState extends State<_DueExtensionSheet> {
  final _note = TextEditingController();
  late DateTime _date;

  DateTime get _minimumDate {
    final base = widget.debt.dueDate ?? widget.debt.createdAt;
    return DateTime(
      base.year,
      base.month,
      base.day,
    ).add(const Duration(days: 1));
  }

  @override
  void initState() {
    super.initState();

    final base = widget.debt.dueDate ?? widget.debt.createdAt;
    _date = DateTime(base.year, base.month + 1, base.day);

    if (_date.isBefore(_minimumDate)) {
      _date = _minimumDate;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(_minimumDate) ? _minimumDate : _date,
      firstDate: _minimumDate,
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
      helpText: widget.debt.dueDate == null
          ? 'Set new due date'
          : 'Extend due date',
    );

    if (!mounted || picked == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    setState(() => _date = picked);
  }

  void _save() {
    Navigator.pop(
      context,
      _DueExtensionDraft(newDueDate: _date, note: _note.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.debt.dueDate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previous == null ? 'Set Due Date' : 'Extend Due Date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.debt.person,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (previous != null)
              _ExtensionDateCompare(
                label: 'Current due',
                value: previous,
                muted: true,
              ),
            if (previous != null) const SizedBox(height: 8),
            _ExtensionDateCompare(
              label: previous == null ? 'Due date' : 'Extended to',
              value: _date,
              highlighted: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 120,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason / Note',
                hintText: 'Optional, e.g. partial payment, agreed extension',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  previous == null ? 'Set Due Date' : 'Confirm Extension',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionDateCompare extends StatelessWidget {
  final String label;
  final DateTime value;
  final bool muted;
  final bool highlighted;
  final VoidCallback? onTap;

  const _ExtensionDateCompare({
    required this.label,
    required this.value,
    this.muted = false,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: highlighted
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                highlighted
                    ? Icons.event_available_rounded
                    : Icons.event_outlined,
                color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(value),
                style: TextStyle(
                  color: highlighted
                      ? scheme.primary
                      : muted
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DueExtensionHistoryTile extends StatelessWidget {
  final DebtDueExtension extension;

  const _DueExtensionHistoryTile({required this.extension});

  @override
  Widget build(BuildContext context) {
    final oldLabel = extension.oldDueDate == null
        ? 'No previous due date'
        : DateFormat('dd MMM yyyy').format(extension.oldDueDate!);
    final newLabel = DateFormat('dd MMM yyyy').format(extension.newDueDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$oldLabel → $newLabel',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    extension.note.isEmpty
                        ? 'Changed ${DateFormat('dd MMM yyyy').format(extension.changedAt)}'
                        : '${DateFormat('dd MMM yyyy').format(extension.changedAt)} • ${extension.note}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDraft {
  final int amount;
  final DateTime date;
  final String note;
  final String source;

  const _PaymentDraft({
    required this.amount,
    required this.date,
    required this.note,
    required this.source,
  });
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormatter.currency(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetPositionCard extends StatelessWidget {
  final int netPosition;
  final int openCount;
  final int overdueCount;
  final int dueSoonCount;

  const _NetPositionCard({
    required this.netPosition,
    required this.openCount,
    required this.overdueCount,
    required this.dueSoonCount,
  });

  @override
  Widget build(BuildContext context) {
    final positive = netPosition >= 0;
    final color = positive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    netPosition == 0
                        ? 'Balanced debt position'
                        : positive
                        ? 'Net owed to you'
                        : 'Net you owe',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MoneyFormatter.currency(netPosition.abs()),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            _MiniPill(
              icon: Icons.pending_actions_outlined,
              label: '$openCount open',
            ),
            if (overdueCount > 0) ...[
              const SizedBox(width: 6),
              _MiniPill(
                icon: Icons.warning_amber_rounded,
                label: '$overdueCount late',
              ),
            ] else if (dueSoonCount > 0) ...[
              const SizedBox(width: 6),
              _MiniPill(
                icon: Icons.schedule_rounded,
                label: '$dueSoonCount soon',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  final DebtItem item;
  final int remaining;
  final int paid;
  final double progress;
  final String status;
  final int extensionCount;
  final VoidCallback onTap;
  final VoidCallback? onPayment;

  const _DebtTile({
    required this.item,
    required this.remaining,
    required this.paid,
    required this.progress,
    required this.status,
    required this.extensionCount,
    required this.onTap,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.isYouOwe
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final statusColor = _statusColor(context, status);
    final paidOut = status == 'Paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            paidOut ? 10 : 11,
            12,
            paidOut ? 10 : 11,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.isYouOwe
                          ? Icons.call_made_rounded
                          : Icons.call_received_rounded,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.person,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(label: status, color: statusColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.isYouOwe ? 'You owe' : 'Owed to you',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FittedBox(
                    child: Text(
                      MoneyFormatter.currency(remaining),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!paidOut) ...[
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.dueDate == null
                            ? paid <= 0
                                  ? 'No due date'
                                  : '${(progress * 100).toStringAsFixed(0)}% paid'
                            : '${_dueText(item.dueDate!, false)}'
                                  '${extensionCount > 0 ? ' • Extended ${extensionCount}x' : ''}'
                                  '${paid > 0 ? ' • ${(progress * 100).toStringAsFixed(0)}% paid' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: item.dueDate == null ? null : statusColor,
                        ),
                      ),
                    ),
                    if (onPayment != null) ...[
                      const SizedBox(width: 10),
                      _RecordPaymentButton(onPressed: onPayment!),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordPaymentButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecordPaymentButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 36,
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pay',
                  maxLines: 1,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  final int original;
  final int paid;
  final int remaining;
  final double progress;

  const _AmountSummary({
    required this.original,
    required this.paid,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniAmount(label: 'Original', amount: original),
                ),
                Expanded(
                  child: _MiniAmount(label: 'Paid', amount: paid),
                ),
                Expanded(
                  child: _MiniAmount(label: 'Remaining', amount: remaining),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}% paid',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  final String label;
  final int amount;

  const _MiniAmount({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        FittedBox(
          child: Text(
            MoneyFormatter.currency(amount),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DueBanner extends StatelessWidget {
  final DateTime dueDate;
  final bool isPaid;
  final int extensionCount;

  const _DueBanner({
    required this.dueDate,
    required this.isPaid,
    this.extensionCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final text = _dueText(dueDate, isPaid);
    final overdue = text.contains('overdue');
    final color = overdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              extensionCount > 0 ? '$text • Extended ${extensionCount}x' : text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DirectionOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.primary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? scheme.primary.withValues(alpha: 0.55)
            : Theme.of(context).dividerColor,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DebtEmpty extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  const _DebtEmpty({
    required this.hasFilters,
    required this.onAdd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.handshake_outlined,
              size: 46,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching debt' : 'No debt records',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try resetting search or filters.'
                  : 'Track money you owe or money others owe you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              )
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Debt'),
              ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'Paid':
      return Theme.of(context).colorScheme.primary;
    case 'Overdue':
      return Theme.of(context).colorScheme.error;
    case 'Partially Paid':
      return Theme.of(context).colorScheme.tertiary;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

String _dueText(DateTime dueDate, bool isPaid) {
  if (isPaid) {
    return 'Settled • Due date was ${DateFormat('dd MMM yyyy').format(dueDate)}';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

  final days = due.difference(today).inDays;

  if (days < 0) {
    final overdue = days.abs();
    return '$overdue day${overdue == 1 ? '' : 's'} overdue';
  }

  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';

  return 'Due in $days days • ${DateFormat('dd MMM').format(dueDate)}';
}

int _debtPriority(String status, DateTime? dueDate) {
  if (status == 'Overdue') return 0;

  if (status == 'Paid') return 4;

  if (dueDate != null) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;

    if (days <= 7) return 1;
    return 2;
  }

  return 3;
}

String _sortLabel(_DebtSort sort) {
  switch (sort) {
    case _DebtSort.newest:
      return 'Newest';
    case _DebtSort.dueSoon:
      return 'Due Soon';
    case _DebtSort.highestRemaining:
      return 'Highest Remaining';
    case _DebtSort.person:
      return 'Person A-Z';
  }
}

IconData _sortIcon(_DebtSort sort) {
  switch (sort) {
    case _DebtSort.newest:
      return Icons.schedule_rounded;
    case _DebtSort.dueSoon:
      return Icons.event_outlined;
    case _DebtSort.highestRemaining:
      return Icons.south_rounded;
    case _DebtSort.person:
      return Icons.sort_by_alpha_rounded;
  }
}
