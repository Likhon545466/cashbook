import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime? minMonth;
  final DateTime? maxMonth;

  const MonthPickerDialog({
    super.key,
    required this.initialMonth,
    this.minMonth,
    this.maxMonth,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialMonth,
    DateTime? minMonth,
    DateTime? maxMonth,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
        initialMonth: initialMonth,
        minMonth: minMonth,
        maxMonth: maxMonth,
      ),
    );
  }

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
  }

  bool _isMonthDisabled(int year, int month) {
    if (widget.minMonth != null) {
      if (year < widget.minMonth!.year ||
          (year == widget.minMonth!.year && month < widget.minMonth!.month)) {
        return true;
      }
    }
    if (widget.maxMonth != null) {
      if (year > widget.maxMonth!.year ||
          (year == widget.maxMonth!.year && month > widget.maxMonth!.month)) {
        return true;
      }
    }
    return false;
  }

  void _onMonthTap(int month) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMonth = month);
  }

  void _onThisMonth() {
    final now = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Select Month',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          TextButton(
            onPressed: _onThisMonth,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('This Month', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Year Selector Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedYear--);
                      },
                    ),
                    Text(
                      '$_selectedYear',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedYear++);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Month Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.0,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final isSelected =
                    _selectedMonth == monthNumber;
                final isCurrentCalendarMonth =
                    now.year == _selectedYear && now.month == monthNumber;
                final isDisabled = _isMonthDisabled(_selectedYear, monthNumber);

                Color? backgroundColor;
                Color textColor;
                Border? border;

                if (isSelected) {
                  backgroundColor = colorScheme.primary;
                  textColor = colorScheme.onPrimary;
                } else if (isCurrentCalendarMonth) {
                  backgroundColor = colorScheme.primary.withValues(alpha: 0.12);
                  textColor = colorScheme.primary;
                  border = Border.all(color: colorScheme.primary, width: 1.5);
                } else if (isDisabled) {
                  backgroundColor = Colors.transparent;
                  textColor = theme.disabledColor;
                } else {
                  backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
                  textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
                }

                return InkWell(
                  onTap: isDisabled ? null : () => _onMonthTap(monthNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: border,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _months[index],
                      style: TextStyle(
                        fontWeight: isSelected || isCurrentCalendarMonth
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, DateTime(_selectedYear, _selectedMonth));
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
