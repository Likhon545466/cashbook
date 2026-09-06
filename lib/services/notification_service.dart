import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../screens/transactions/add_transaction_screen.dart';

class NotificationService {
  NotificationService._();

  static DateTime? _lastReminderDate;

  /// Checks if daily reminder is due and shows a friendly in-app check-in banner.
  static void checkDailyReminder(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    if (!settings.dailyReminderEnabled) return;

    final now = DateTime.now();
    final reminderTime = settings.dailyReminderTime;
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );

    // If current time is after reminder time
    if (now.isAfter(scheduledToday)) {
      // Check if already prompted today
      if (_lastReminderDate != null &&
          _lastReminderDate!.year == now.year &&
          _lastReminderDate!.month == now.month &&
          _lastReminderDate!.day == now.day) {
        return;
      }

      final txProvider = context.read<TransactionProvider>();
      final hasTodayTx = txProvider.transactions.any(
        (t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day,
      );

      // If no transactions have been logged today, prompt user
      if (!hasTodayTx) {
        _lastReminderDate = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.amberAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Expense Reminder',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Have you recorded today\'s expenses (${DateFormat('dd MMM').format(now)})?',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Add Now',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        });
      }
    }
  }
}
