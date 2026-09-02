import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/money_formatter.dart';

class MonthlyCashflowData {
  final String monthLabel;
  final int income;
  final int expense;
  final DateTime date;

  const MonthlyCashflowData({
    required this.monthLabel,
    required this.income,
    required this.expense,
    required this.date,
  });

  int get net => income - expense;
}

class CashflowBarChart extends StatefulWidget {
  final List<MonthlyCashflowData> months;
  final ValueChanged<MonthlyCashflowData?>? onMonthSelected;

  const CashflowBarChart({
    super.key,
    required this.months,
    this.onMonthSelected,
  });

  @override
  State<CashflowBarChart> createState() => _CashflowBarChartState();
}

class _CashflowBarChartState extends State<CashflowBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CashflowBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months != widget.months) {
      _controller.forward(from: 0.0);
      _selectedIndex = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.months.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = widget.months.fold<int>(
      1000,
      (max, m) => math.max(max, math.max(m.income, m.expense)),
    );

    final selected = _selectedIndex != null && _selectedIndex! < widget.months.length
        ? widget.months[_selectedIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cashflow Trend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Income vs Expense history',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _LegendPill(
                    label: 'In',
                    color: AppSemanticColors.income(context),
                  ),
                  const SizedBox(width: 8),
                  _LegendPill(
                    label: 'Out',
                    color: AppSemanticColors.expense(context),
                  ),
                ],
              ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selected.monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Text(
                        'Net: ',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                      Text(
                        '${selected.net >= 0 ? '+' : ''}${MoneyFormatter.currency(selected.net)}',
                        style: TextStyle(
                          color: selected.net >= 0
                              ? AppSemanticColors.income(context)
                              : AppSemanticColors.expense(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / widget.months.length;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < widget.months.length; i++) ...[
                          _MonthBarColumn(
                            data: widget.months[i],
                            maxValue: maxVal,
                            progress: _animation.value,
                            isSelected: _selectedIndex == i,
                            width: itemWidth,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedIndex = (_selectedIndex == i) ? null : i;
                              });
                              widget.onMonthSelected
                                  ?.call(_selectedIndex != null ? widget.months[i] : null);
                            },
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBarColumn extends StatelessWidget {
  final MonthlyCashflowData data;
  final int maxValue;
  final double progress;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  const _MonthBarColumn({
    required this.data,
    required this.maxValue,
    required this.progress,
    required this.isSelected,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const barMaxHeight = 100.0;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final incomeHeight =
        (maxValue > 0 ? (data.income / maxValue) : 0.0) * barMaxHeight * progress;
    final expenseHeight =
        (maxValue > 0 ? (data.expense / maxValue) : 0.0) * barMaxHeight * progress;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: barMaxHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Income bar
                  Container(
                    width: math.max(4.0, (width - 16) / 2),
                    height: math.max(3.0, incomeHeight),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.income(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Expense bar
                  Container(
                    width: math.max(4.0, (width - 16) / 2),
                    height: math.max(3.0, expenseHeight),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.expense(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.monthLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
