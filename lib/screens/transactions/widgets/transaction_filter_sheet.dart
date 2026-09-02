import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import 'transaction_models.dart';

class TransactionFilterSheet extends StatefulWidget {
  final TransactionTypeFilter initialType;
  final DateFilter initialDate;
  final TransactionSort initialSort;
  final String? initialCategory;
  final DateTimeRange? initialRange;
  final List<String> categories;

  const TransactionFilterSheet({
    super.key,
    required this.initialType,
    required this.initialDate,
    required this.initialSort,
    required this.initialCategory,
    required this.initialRange,
    required this.categories,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionTypeFilter _tempType;
  late DateFilter _tempDate;
  late TransactionSort _tempSort;
  late String? _tempCategory;
  late DateTimeRange? _tempRange;

  @override
  void initState() {
    super.initState();
    _tempType = widget.initialType;
    _tempDate = widget.initialDate;
    _tempSort = widget.initialSort;
    _tempCategory = widget.initialCategory;
    _tempRange = widget.initialRange;
  }

  Future<DateTimeRange?> _pickCustomRange(DateTimeRange? current) {
    final now = DateTime.now();

    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          current ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Sort',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const FilterSectionTitle('Activity Type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VisibleChoiceChip(
                  label: 'All',
                  selected: _tempType == TransactionTypeFilter.all,
                  onSelected: () => setState(
                    () => _tempType = TransactionTypeFilter.all,
                  ),
                ),
                VisibleChoiceChip(
                  label: 'Cash In',
                  selected: _tempType == TransactionTypeFilter.income,
                  semanticColor: AppSemanticColors.income(context),
                  onSelected: () => setState(
                    () => _tempType = TransactionTypeFilter.income,
                  ),
                ),
                VisibleChoiceChip(
                  label: 'Cash Out',
                  selected: _tempType == TransactionTypeFilter.expense,
                  semanticColor: AppSemanticColors.expense(context),
                  onSelected: () => setState(
                    () => _tempType = TransactionTypeFilter.expense,
                  ),
                ),
                VisibleChoiceChip(
                  label: 'Savings',
                  selected: _tempType == TransactionTypeFilter.savings,
                  semanticColor: AppSemanticColors.savings(context),
                  onSelected: () => setState(
                    () => _tempType = TransactionTypeFilter.savings,
                  ),
                ),
                VisibleChoiceChip(
                  label: 'Debt',
                  selected: _tempType == TransactionTypeFilter.debt,
                  semanticColor: Theme.of(context).colorScheme.primary,
                  onSelected: () => setState(
                    () => _tempType = TransactionTypeFilter.debt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const FilterSectionTitle('Date'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in DateFilter.values.where(
                  (item) => item != DateFilter.custom,
                ))
                  VisibleChoiceChip(
                    label: transactionDateChipLabel(option),
                    selected: _tempDate == option,
                    onSelected: () => setState(() => _tempDate = option),
                  ),
                VisibleChoiceChip(
                  label: _tempRange == null
                      ? 'Custom Range'
                      : '${DateFormat('dd MMM').format(_tempRange!.start)} - '
                            '${DateFormat('dd MMM').format(_tempRange!.end)}',
                  selected: _tempDate == DateFilter.custom,
                  onSelected: () async {
                    final picked = await _pickCustomRange(_tempRange);
                    if (picked == null) return;
                    setState(() {
                      _tempRange = picked;
                      _tempDate = DateFilter.custom;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const FilterSectionTitle('Category'),
            const SizedBox(height: 6),
            Text(
              'Category applies to Cash In / Cash Out. Savings activity '
              'is hidden when a category filter is active.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VisibleChoiceChip(
                  label: 'All Categories',
                  selected: _tempCategory == null,
                  onSelected: () => setState(() => _tempCategory = null),
                ),
                ...widget.categories.map(
                  (category) => VisibleChoiceChip(
                    label: category,
                    selected: _tempCategory == category,
                    onSelected: () =>
                        setState(() => _tempCategory = category),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const FilterSectionTitle('Sort'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransactionSort.values.map((sort) {
                return VisibleChoiceChip(
                  label: transactionSortLabelFor(sort),
                  selected: _tempSort == sort,
                  onSelected: () => setState(() => _tempSort = sort),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempType = TransactionTypeFilter.all;
                        _tempDate = DateFilter.all;
                        _tempSort = TransactionSort.newest;
                        _tempCategory = null;
                        _tempRange = null;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TransactionFilterResult(
                        type: _tempType,
                        date: _tempDate,
                        sort: _tempSort,
                        category: _tempCategory,
                        range: _tempRange,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FilterSectionTitle extends StatelessWidget {
  final String text;

  const FilterSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class VisibleChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final FutureOr<void> Function() onSelected;
  final Color? semanticColor;

  const VisibleChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.semanticColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = semanticColor ?? scheme.primary;
    final foreground = selected ? activeColor : scheme.onSurface;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: activeColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected
            ? activeColor.withValues(alpha: 0.62)
            : Theme.of(context).dividerColor,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
