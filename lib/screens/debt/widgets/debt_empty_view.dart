import 'package:flutter/material.dart';

class DebtEmptyView extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  const DebtEmptyView({
    super.key,
    required this.hasFilters,
    required this.onAdd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.handshake_outlined,
              size: 46,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matching debt' : 'No debt records',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try resetting search or filters.'
                  : 'Track money you owe or money others owe you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              )
            else
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Debt'),
              ),
          ],
        ),
      ),
    );
  }
}
