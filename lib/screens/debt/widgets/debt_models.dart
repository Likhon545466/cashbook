import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DebtFilter { all, youOwe, owedToYou, open, overdue, paid }

enum DebtSort { newest, dueSoon, highestRemaining, person }

class DebtDraft {
  final String direction;
  final String person;
  final int amount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String note;

  const DebtDraft({
    required this.direction,
    required this.person,
    required this.amount,
    required this.createdAt,
    required this.dueDate,
    required this.note,
  });
}

class PaymentDraft {
  final int amount;
  final DateTime date;
  final String note;
  final String source;

  const PaymentDraft({
    required this.amount,
    required this.date,
    required this.note,
    required this.source,
  });
}

class DueExtensionDraft {
  final DateTime newDueDate;
  final String note;

  const DueExtensionDraft({required this.newDueDate, required this.note});
}

Color debtStatusColor(BuildContext context, String status) {
  switch (status) {
    case 'Paid':
      return Theme.of(context).colorScheme.primary;
    case 'Overdue':
      return Theme.of(context).colorScheme.error;
    case 'Partially Paid':
      return Theme.of(context).colorScheme.tertiary;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

String debtDueText(DateTime dueDate, bool isPaid) {
  if (isPaid) {
    return 'Settled • Due date was ${DateFormat('dd MMM yyyy').format(dueDate)}';
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

  final days = due.difference(today).inDays;

  if (days < 0) {
    final overdue = days.abs();
    return '$overdue day${overdue == 1 ? '' : 's'} overdue';
  }

  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';

  return 'Due in $days days • ${DateFormat('dd MMM').format(dueDate)}';
}

int debtPriority(String status, DateTime? dueDate) {
  if (status == 'Overdue') return 0;
  if (status == 'Paid') return 4;

  if (dueDate != null) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = due.difference(today).inDays;

    if (days <= 7) return 1;
    return 2;
  }

  return 3;
}

String debtSortLabel(DebtSort sort) {
  switch (sort) {
    case DebtSort.newest:
      return 'Newest';
    case DebtSort.dueSoon:
      return 'Due Soon';
    case DebtSort.highestRemaining:
      return 'Highest Remaining';
    case DebtSort.person:
      return 'Person A-Z';
  }
}

IconData debtSortIcon(DebtSort sort) {
  switch (sort) {
    case DebtSort.newest:
      return Icons.schedule_rounded;
    case DebtSort.dueSoon:
      return Icons.event_outlined;
    case DebtSort.highestRemaining:
      return Icons.south_rounded;
    case DebtSort.person:
      return Icons.sort_by_alpha_rounded;
  }
}
