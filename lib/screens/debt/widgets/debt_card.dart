import 'package:flutter/material.dart';

import '../../../models/debt_model.dart';
import '../../../utils/money_formatter.dart';
import 'debt_models.dart';

class DebtTile extends StatelessWidget {
  final DebtItem item;
  final int remaining;
  final int paid;
  final double progress;
  final String status;
  final int extensionCount;
  final VoidCallback onTap;
  final VoidCallback? onPayment;

  const DebtTile({
    super.key,
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
    final statusColor = debtStatusColor(context, status);
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
                            StatusPill(label: status, color: statusColor),
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
                            : '${debtDueText(item.dueDate!, false)}'
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
                      RecordPaymentButton(onPressed: onPayment!),
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

class RecordPaymentButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RecordPaymentButton({super.key, required this.onPressed});

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

class AmountSummaryCard extends StatelessWidget {
  final int original;
  final int paid;
  final int remaining;
  final double progress;

  const AmountSummaryCard({
    super.key,
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
                  child: MiniAmount(label: 'Original', amount: original),
                ),
                Expanded(
                  child: MiniAmount(label: 'Paid', amount: paid),
                ),
                Expanded(
                  child: MiniAmount(label: 'Remaining', amount: remaining),
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

class MiniAmount extends StatelessWidget {
  final String label;
  final int amount;

  const MiniAmount({super.key, required this.label, required this.amount});

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

class DueBanner extends StatelessWidget {
  final DateTime dueDate;
  final bool isPaid;
  final int extensionCount;

  const DueBanner({
    super.key,
    required this.dueDate,
    required this.isPaid,
    this.extensionCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final text = debtDueText(dueDate, isPaid);
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

class InfoRowItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRowItem({
    super.key,
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

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

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

class DebtCustomFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DebtCustomFilterChip({
    super.key,
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
