import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/debt_model.dart';
import '../../../models/debt_payment_model.dart';
import '../../../providers/debt_provider.dart';
import '../../../utils/money_formatter.dart';
import 'debt_card.dart';
import 'debt_due_extension_sheet.dart';
import 'debt_models.dart';

class DebtDetailsSheet extends StatelessWidget {
  final DebtItem item;
  final VoidCallback onEdit;
  final VoidCallback onExtend;
  final VoidCallback onAddPayment;
  final void Function(DebtPayment payment) onEditPayment;
  final void Function(DebtPayment payment) onDeletePayment;
  final VoidCallback onDeleteDebt;

  const DebtDetailsSheet({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onExtend,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onDeletePayment,
    required this.onDeleteDebt,
  });

  @override
  Widget build(BuildContext context) {
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
                    StatusPill(
                      label: status,
                      color: debtStatusColor(context, status),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AmountSummaryCard(
                  original: item.amount,
                  paid: paid,
                  remaining: remaining,
                  progress: progress,
                ),
                const SizedBox(height: 16),
                if (item.dueDate != null)
                  DueBanner(
                    dueDate: item.dueDate!,
                    isPaid: remaining <= 0,
                    extensionCount: extensions.length,
                  ),
                if (item.dueDate != null) const SizedBox(height: 12),
                InfoRowItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Created',
                  value: DateFormat('dd MMM yyyy').format(item.createdAt),
                ),
                InfoRowItem(
                  icon: Icons.event_outlined,
                  label: 'Due',
                  value: item.dueDate == null
                      ? 'No due date'
                      : DateFormat('dd MMM yyyy').format(item.dueDate!),
                ),
                if (item.note.isNotEmpty)
                  InfoRowItem(
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
                            Navigator.pop(context);
                            onEdit();
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
                              Navigator.pop(context);
                              onExtend();
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
                        Navigator.pop(context);
                        onAddPayment();
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
                        DueExtensionHistoryTile(extension: extension),
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
                                Navigator.pop(context);
                                onEditPayment(payment);
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete payment',
                              onPressed: () {
                                Navigator.pop(context);
                                onDeletePayment(payment);
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
                      Navigator.pop(context);
                      onDeleteDebt();
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
  }
}
