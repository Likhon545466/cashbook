import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/savings_transfer_model.dart';
import '../../providers/savings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/amount_expression.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/savings_transfer_sheet.dart';
import '../../widgets/smart_amount_field.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  Future<void> _edit(BuildContext context, SavingsTransfer item) async {
    final controller = TextEditingController(text: item.amount.toString());

    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          item.isDeposit ? 'Edit Savings Deposit' : 'Edit Withdrawal',
        ),
        content: SmartAmountField(
          controller: controller,
          autofocus: true,
          labelText: 'Amount',
          compact: true,
          onSubmitted: (_) {
            Navigator.pop(
              dialogContext,
              AmountExpression.evaluate(controller.text),
            );
          },
        ),
        actions: [
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
            child: const Text('Update'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!context.mounted || amount == null || amount <= 0) return;

    final provider = context.read<SavingsProvider>();
    final success = await provider.updateTransfer(
      original: item,
      amount: amount,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Savings entry updated.'
              : provider.errorMessage ?? 'Could not update entry.',
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, SavingsTransfer item) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete savings entry?'),
            content: const Text(
              'This changes your reserved balance. This action cannot be undone.',
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

    if (!context.mounted || !confirmed) return;

    final provider = context.read<SavingsProvider>();
    final success = await provider.deleteTransfer(item);

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not delete entry.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Savings entry deleted.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final restored = await provider.restoreTransfer(item);
              if (!context.mounted || restored) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not restore savings entry.'),
                ),
              );
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final savings = context.watch<SavingsProvider>();
    final transactions = context.watch<TransactionProvider>();

    final available = transactions.balance - savings.balance;
    final inconsistent = savings.balance > transactions.balance;
    final now = DateTime.now();

    final addedThisMonth = savings.items
        .where(
          (item) =>
              item.isDeposit &&
              item.date.year == now.year &&
              item.date.month == now.month,
        )
        .fold<int>(0, (sum, item) => sum + item.amount);

    final withdrawnThisMonth = savings.items
        .where(
          (item) =>
              !item.isDeposit &&
              item.date.year == now.year &&
              item.date.month == now.month,
        )
        .fold<int>(0, (sum, item) => sum + item.amount);

    final netThisMonth = addedThisMonth - withdrawnThisMonth;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Savings / Reserve',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: savings.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reserved Balance',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      MoneyFormatter.currency(savings.balance),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: AppSemanticColors.savings(context)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: available <= 0
                                  ? null
                                  : () => showSavingsTransferSheet(
                                      context,
                                      deposit: true,
                                      availableBalance: available,
                                    ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.tonalIcon(
                              onPressed: savings.balance <= 0
                                  ? null
                                  : () => showSavingsTransferSheet(
                                      context,
                                      deposit: false,
                                      availableBalance: available,
                                    ),
                              icon: const Icon(Icons.undo_rounded),
                              label: const Text('Withdraw'),
                            ),
                          ),
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
                  child: _SavingsMetric(
                    label: 'Added',
                    value: MoneyFormatter.currency(addedThisMonth),
                    icon: Icons.add_circle_outline_rounded,
                    color: AppSemanticColors.savings(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SavingsMetric(
                    label: 'Withdrawn',
                    value: MoneyFormatter.currency(withdrawnThisMonth),
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppSemanticColors.warning(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SavingsMetric(
                    label: 'Net',
                    value: MoneyFormatter.currency(netThisMonth),
                    icon: Icons.swap_vert_rounded,
                    color: netThisMonth >= 0
                        ? AppSemanticColors.savings(context)
                        : AppSemanticColors.warning(context),
                  ),
                ),
              ],
            ),
            if (inconsistent) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: AppSemanticColors.warning(context),
                  ),
                  title: const Text(
                    'Reserved money exceeds current total cash',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'This can happen after editing or deleting older transactions. '
                    'Review your savings history or cash transactions.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (savings.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No savings activity yet.')),
                ),
              )
            else
              ...savings.items.map((item) {
                final color = item.isDeposit
                    ? AppSemanticColors.savings(context)
                    : AppSemanticColors.warning(context);

                return Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.isDeposit
                            ? Icons.savings_outlined
                            : Icons.undo_rounded,
                        color: color,
                      ),
                    ),
                    title: Text(
                      item.isDeposit
                          ? 'Added to Savings'
                          : 'Withdrawn from Savings',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      item.note.isEmpty
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(item.date)
                          : '${DateFormat('dd MMM yyyy, hh:mm a').format(item.date)}\n${item.note}',
                      maxLines: item.note.isEmpty ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 118),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${item.isDeposit ? '+' : '-'}${MoneyFormatter.currency(item.amount)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    onTap: () => _edit(context, item),
                    onLongPress: () => _delete(context, item),
                  ),
                );
              }),
            if (savings.items.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Tap an entry to edit. Long-press to delete.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavingsMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SavingsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
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
    );
  }
}
