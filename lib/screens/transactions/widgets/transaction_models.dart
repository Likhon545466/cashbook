import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/debt_model.dart';
import '../../../models/debt_payment_model.dart';
import '../../../models/savings_transfer_model.dart';
import '../../../models/transaction_model.dart';

enum TransactionTypeFilter { all, income, expense, savings, debt }

enum DateFilter { all, today, thisWeek, thisMonth, custom }

enum TransactionSort { newest, oldest, highestAmount, lowestAmount }

enum TransactionQuickAction { cashIn, cashOut, savings, debt }

enum CashAction { edit, duplicate, delete }

class DebtActivity {
  final DebtItem debt;
  final DebtPayment? payment;

  const DebtActivity({required this.debt, required this.payment});

  bool get isPayment => payment != null;
  DateTime get date => payment?.date ?? debt.createdAt;
  int get amount => payment?.amount ?? debt.amount;

  String get title {
    if (!isPayment) {
      return debt.isYouOwe
          ? 'Debt Added • You Owe'
          : 'Debt Added • Owed to You';
    }

    return debt.isYouOwe ? 'Debt Repayment' : 'Debt Collection';
  }

  String get subtitle {
    final note = payment?.note ?? debt.note;
    return note.isEmpty ? debt.person : '${debt.person} • $note';
  }
}

class ActivityItem {
  final CashTransaction? cash;
  final SavingsTransfer? savings;
  final DebtActivity? debt;

  const ActivityItem._({this.cash, this.savings, this.debt});

  factory ActivityItem.cash(CashTransaction item) {
    return ActivityItem._(cash: item);
  }

  factory ActivityItem.savings(SavingsTransfer item) {
    return ActivityItem._(savings: item);
  }

  factory ActivityItem.debt(DebtActivity item) {
    return ActivityItem._(debt: item);
  }

  DateTime get date {
    if (cash != null) return cash!.date;
    if (savings != null) return savings!.date;
    return debt!.date;
  }

  int get amount {
    if (cash != null) return cash!.amount;
    if (savings != null) return savings!.amount;
    return debt!.amount;
  }

  String get searchText {
    final transaction = cash;
    if (transaction != null) {
      return '${transaction.note} ${transaction.category} '
              '${transaction.amount} '
              '${transaction.isIncome ? 'cash in income' : 'cash out expense'}'
          .toLowerCase();
    }

    final savingsItem = savings;
    if (savingsItem != null) {
      return '${savingsItem.note} ${savingsItem.amount} savings reserve '
              '${savingsItem.isDeposit ? 'added deposit' : 'withdrawn withdraw'}'
          .toLowerCase();
    }

    final debtItem = debt!;
    return '${debtItem.title} ${debtItem.subtitle} ${debtItem.amount} debt '
            '${debtItem.debt.isYouOwe ? 'you owe borrowed' : 'owed to you lent'}'
        .toLowerCase();
  }
}

class TransactionFilterResult {
  final TransactionTypeFilter type;
  final DateFilter date;
  final TransactionSort sort;
  final String? category;
  final DateTimeRange? range;

  const TransactionFilterResult({
    required this.type,
    required this.date,
    required this.sort,
    required this.category,
    required this.range,
  });
}

String transactionSortLabelFor(TransactionSort sort) {
  switch (sort) {
    case TransactionSort.newest:
      return 'Newest';
    case TransactionSort.oldest:
      return 'Oldest';
    case TransactionSort.highestAmount:
      return 'Highest Amount';
    case TransactionSort.lowestAmount:
      return 'Lowest Amount';
  }
}

String transactionDateChipLabel(DateFilter value) {
  switch (value) {
    case DateFilter.all:
      return 'Any Date';
    case DateFilter.today:
      return 'Today';
    case DateFilter.thisWeek:
      return 'This Week';
    case DateFilter.thisMonth:
      return 'This Month';
    case DateFilter.custom:
      return 'Custom';
  }
}

String transactionGroupLabel(DateTime date) {
  final now = DateTime.now();

  if (isSameCalendarDay(date, now)) return 'Today';

  final yesterday = now.subtract(const Duration(days: 1));
  if (isSameCalendarDay(date, yesterday)) return 'Yesterday';

  if (date.year == now.year) {
    return DateFormat('EEEE, dd MMMM').format(date);
  }

  return DateFormat('dd MMMM yyyy').format(date);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
