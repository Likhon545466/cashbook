import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/category_icon.dart';
import '../utils/money_formatter.dart';

class TransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final int amount;
  final bool isIncome;
  final String? dateLabel;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    this.dateLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome
        ? AppSemanticColors.income(context)
        : AppSemanticColors.expense(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
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
                  CategoryIcon.forName(category, isIncome: isIncome),
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel == null ? category : '$category • $dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isIncome ? '+' : '-'}${MoneyFormatter.currency(amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
