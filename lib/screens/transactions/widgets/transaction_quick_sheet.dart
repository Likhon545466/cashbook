import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'transaction_models.dart';

class TransactionQuickSheet extends StatelessWidget {
  const TransactionQuickSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            TransactionQuickTile(
              icon: Icons.south_west_rounded,
              title: 'Cash In',
              color: AppSemanticColors.income(context),
              onTap: () => Navigator.pop(
                context,
                TransactionQuickAction.cashIn,
              ),
            ),
            TransactionQuickTile(
              icon: Icons.north_east_rounded,
              title: 'Cash Out',
              color: AppSemanticColors.expense(context),
              onTap: () => Navigator.pop(
                context,
                TransactionQuickAction.cashOut,
              ),
            ),
            TransactionQuickTile(
              icon: Icons.savings_outlined,
              title: 'Add to Savings',
              color: AppSemanticColors.savings(context),
              onTap: () => Navigator.pop(
                context,
                TransactionQuickAction.savings,
              ),
            ),
            TransactionQuickTile(
              icon: Icons.handshake_outlined,
              title: 'Add Debt',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => Navigator.pop(
                context,
                TransactionQuickAction.debt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionQuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const TransactionQuickTile({
    super.key,
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
