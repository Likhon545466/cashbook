import 'package:flutter/material.dart';

import '../../../utils/money_formatter.dart';

class DebtSummaryCard extends StatelessWidget {
  final String title;
  final int amount;
  final IconData icon;
  final Color color;

  const DebtSummaryCard({
    super.key,
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

class DebtNetPositionCard extends StatelessWidget {
  final int netPosition;
  final int openCount;
  final int overdueCount;
  final int dueSoonCount;

  const DebtNetPositionCard({
    super.key,
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
            DebtMiniPill(
              icon: Icons.pending_actions_outlined,
              label: '$openCount open',
            ),
            if (overdueCount > 0) ...[
              const SizedBox(width: 6),
              DebtMiniPill(
                icon: Icons.warning_amber_rounded,
                label: '$overdueCount late',
              ),
            ] else if (dueSoonCount > 0) ...[
              const SizedBox(width: 6),
              DebtMiniPill(
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

class DebtMiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const DebtMiniPill({super.key, required this.icon, required this.label});

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
