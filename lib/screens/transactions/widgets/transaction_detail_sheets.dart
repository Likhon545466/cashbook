import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/savings_transfer_model.dart';
import '../../../models/transaction_model.dart';
import '../../../utils/money_formatter.dart';
import 'transaction_models.dart';

class CashDetailSheet extends StatelessWidget {
  final CashTransaction item;

  const CashDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isIncome
        ? AppSemanticColors.income(context)
        : AppSemanticColors.expense(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailHero(
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
            DetailRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: item.category,
            ),
            DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: DateFormat('dd MMMM yyyy').format(item.date),
            ),
            if (item.note.isNotEmpty)
              DetailRow(
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
                        Navigator.pop(context, CashAction.duplicate),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Duplicate'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, CashAction.edit),
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
                onPressed: () => Navigator.pop(context, CashAction.delete),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'Delete Transaction',
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
  }
}

class SavingsDetailSheet extends StatelessWidget {
  final SavingsTransfer item;

  const SavingsDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isDeposit
        ? AppSemanticColors.savings(context)
        : AppSemanticColors.warning(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailHero(
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
            DetailRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Type',
              value: item.isDeposit
                  ? 'Available → Savings'
                  : 'Savings → Available',
            ),
            DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Date',
              value: DateFormat('dd MMM yyyy, hh:mm a').format(item.date),
            ),
            if (item.note.isNotEmpty)
              DetailRow(
                icon: Icons.notes_rounded,
                label: 'Note',
                value: item.note,
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Manage Savings'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Savings transfers do not count as income or expense.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class DetailHero extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String amount;
  final String title;
  final String badge;

  const DetailHero({
    super.key,
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

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow({
    super.key,
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
