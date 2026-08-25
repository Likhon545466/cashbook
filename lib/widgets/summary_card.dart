import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/money_formatter.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final int amount;
  final IconData icon;
  final bool isIncome;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome
        ? AppSemanticColors.income(context)
        : AppSemanticColors.expense(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormatter.currency(amount),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
