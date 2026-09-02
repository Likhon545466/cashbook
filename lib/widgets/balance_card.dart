import 'package:flutter/material.dart';

import '../utils/money_formatter.dart';

class BalanceCard extends StatelessWidget {
  final int balance;
  final bool isHidden;
  final VoidCallback onToggleVisibility;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.isHidden,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final primaryDark = Color.lerp(primary, Colors.black, 0.32)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primary],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  tooltip: isHidden ? 'Show balance' : 'Hide balance',
                  onPressed: onToggleVisibility,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    padding: EdgeInsets.zero,
                  ),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      key: ValueKey(isHidden),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: FittedBox(
              key: ValueKey(isHidden),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isHidden
                    ? '${MoneyFormatter.currencySymbol} ••••••'
                    : MoneyFormatter.currency(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  balance >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white70,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    balance >= 0
                        ? 'You are in a positive balance.'
                        : 'Cash out is higher than cash in.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
