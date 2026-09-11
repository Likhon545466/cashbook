import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/debt_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/cloud_sync_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/money_formatter.dart';
import '../../services/app_update_service.dart';
import '../../widgets/book_picker_sheet.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/update_popup_dialog.dart';
import '../debt/debt_screen.dart';
import '../savings/savings_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/widgets/transaction_detail_sheets.dart';
import '../transactions/widgets/transaction_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _startupUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavingsProvider>().load();
      context.read<DebtProvider>().load();

      if (!_startupUpdateChecked) {
        _startupUpdateChecked = true;
        _checkAppUpdateSilently();
      }
    });
  }

  Future<void> _checkAppUpdateSilently() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    try {
      final settings = context.read<SettingsProvider>();
      if (!settings.shouldCheckForUpdate()) return;

      final service = AppUpdateService();
      final result = await service.checkForUpdates();
      if (!mounted) return;

      await settings.recordUpdateCheckNow();
      if (!mounted) return;

      if (result.hasUpdate) {
        await UpdatePopupDialog.show(context, result);
      }
    } catch (_) {}
  }

  Future<void> _openAdd(String type) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final transactions = context.read<TransactionProvider>();
    final initialDate = transactions.isCustomBookSelected
        ? DateTime.now()
        : (transactions.isCurrentMonthSelected
            ? DateTime.now()
            : DateTime(
                transactions.selectedMonth.year,
                transactions.selectedMonth.month,
                1,
                12,
                0,
              ));

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: type,
          initialDate: initialDate,
        ),
      ),
    );

    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == 'income' ? 'Cash in saved.' : 'Cash out saved.'),
      ),
    );
  }

  Future<void> _editTransaction(CashTransaction item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: item),
      ),
    );

    if (!mounted || updated != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction updated.')),
    );
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

    if (success && mounted) {
      context.read<CloudSyncProvider>().scheduleAutoSync();
    }

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

  Future<bool> _confirmDelete(CashTransaction item) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: Text(
              item.cleanNote.isEmpty
                  ? 'Delete this ${item.category} transaction?'
                  : 'Delete "${item.cleanNote}"?',
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

    if (mounted) {
      context.read<CloudSyncProvider>().scheduleAutoSync();
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
              if (!mounted) return;
              if (restored) {
                context.read<CloudSyncProvider>().scheduleAutoSync();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not restore transaction.')),
                );
              }
            },
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

  Future<void> _pickBookMonth() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    await BookPickerSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>();
    final savings = context.watch<SavingsProvider>();
    final debts = context.watch<DebtProvider>();
    final settings = context.watch<SettingsProvider>();

    final activeBookTitle = transactions.activeBookTitle;
    final isCustomBook = transactions.isCustomBookSelected;
    final bookIncome = transactions.currentBookIncome;
    final bookExpense = transactions.currentBookExpense;
    final bookNet = transactions.currentBookNet;

    final savingsBalance = savings.balance;
    final bookTransactions = transactions.currentBookTransactions;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CashBook',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              DateFormat('EEE, dd MMM yyyy').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          _BookSelectorPill(
            title: activeBookTitle,
            isCustomBook: isCustomBook,
            onTap: _pickBookMonth,
          ),
          const SizedBox(width: 16),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            // Unified Book Hero Card
            _BookHeroCard(
              monthLabel: activeBookTitle,
              netBalance: bookNet,
              income: bookIncome,
              expense: bookExpense,
              isHidden: settings.hideBalance,
              onToggleVisibility: settings.toggleBalanceVisibility,
              onCashIn: () => _openAdd('income'),
              onCashOut: () => _openAdd('expense'),
            ),
            const SizedBox(height: 14),

            // Compact 2-Column Glance Strip (Savings & Debt)
            Row(
              children: [
                Expanded(
                  child: _GlanceCard(
                    icon: Icons.savings_outlined,
                    label: 'Savings',
                    value: settings.hideBalance
                        ? '••••'
                        : MoneyFormatter.currency(savingsBalance),
                    color: AppSemanticColors.savings(context),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => const SavingsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlanceCard(
                    icon: Icons.handshake_outlined,
                    label: 'Debt',
                    value: settings.hideBalance
                        ? '••••'
                        : (debts.totalYouOwe > 0
                            ? '-${MoneyFormatter.currency(debts.totalYouOwe)}'
                            : (debts.totalOwedToYou > 0
                                ? '+${MoneyFormatter.currency(debts.totalOwedToYou)}'
                                : '৳0')),
                    color: debts.totalYouOwe > 0
                        ? scheme.error
                        : scheme.primary,
                    subtitle: debts.overdueCount > 0
                        ? '${debts.overdueCount} overdue'
                        : (debts.openCount > 0 ? '${debts.openCount} open' : null),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => const DebtScreen()),
                    ),
                  ),
                ),
              ],
            ),

            if (debts.nextAttentionDebt != null) ...[
              const SizedBox(height: 10),
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

            const SizedBox(height: 20),

            // Activity Feed Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$activeBookTitle Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  ),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Activity List
            if (bookTransactions.isEmpty)
              const _EmptyCard()
            else
              ...bookTransactions.take(8).map(
                    (item) => TransactionTile(
                      title: item.cleanNote.isEmpty ? item.category : item.cleanNote,
                      category: item.category,
                      amount: item.amount,
                      isIncome: item.isIncome,
                      dateLabel: DateFormat('dd MMM, hh:mm a').format(item.date),
                      onTap: () => _showCashDetails(transactions, item),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _BookSelectorPill extends StatelessWidget {
  final String title;
  final bool isCustomBook;
  final VoidCallback onTap;

  const _BookSelectorPill({
    required this.title,
    required this.isCustomBook,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCustomBook
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCustomBook
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCustomBook
                    ? Icons.folder_special_rounded
                    : Icons.auto_stories_rounded,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isCustomBook ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookHeroCard extends StatelessWidget {
  final String monthLabel;
  final int netBalance;
  final int income;
  final int expense;
  final bool isHidden;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCashIn;
  final VoidCallback onCashOut;

  const _BookHeroCard({
    required this.monthLabel,
    required this.netBalance,
    required this.income,
    required this.expense,
    required this.isHidden,
    required this.onToggleVisibility,
    required this.onCashIn,
    required this.onCashOut,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final primaryDark = Color.lerp(primary, Colors.black, 0.35)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primary],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthLabel.toUpperCase()} NET',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                tooltip: isHidden ? 'Show balance' : 'Hide balance',
                onPressed: onToggleVisibility,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Large Net Balance
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isHidden ? '${MoneyFormatter.currencySymbol} ••••••' : MoneyFormatter.currency(netBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Cash In / Cash Out Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.south_west_rounded,
                          size: 12,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cash In',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              isHidden ? '••••' : MoneyFormatter.currency(income),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.north_east_rounded,
                          size: 12,
                          color: Color(0xFFF87171),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cash Out',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              isHidden ? '••••' : MoneyFormatter.currency(expense),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Built-in Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCashIn,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Cash In',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCashOut,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  label: const Text(
                    'Cash Out',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlanceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  const _GlanceCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${item.isYouOwe ? 'You owe' : 'Owed to you'} ${MoneyFormatter.currency(remaining)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No transactions in this book',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap Cash In or Cash Out above to record an entry.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
