import 'package:flutter/material.dart';

class TransactionEmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onReset;
  final VoidCallback onAdd;

  const TransactionEmptyView({
    super.key,
    required this.hasFilters,
    required this.onReset,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              size: 46,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching activity' : 'No activity yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try resetting your search or filters.'
                  : 'Add Cash In, Cash Out or move money to Savings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset filters'),
              )
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add transaction'),
              ),
          ],
        ),
      ),
    );
  }
}
