import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../utils/money_formatter.dart';

class BookPickerSheet extends StatefulWidget {
  const BookPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const BookPickerSheet(),
    );
  }

  @override
  State<BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<BookPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;

  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: provider.isCustomBookSelected ? 1 : 0,
    );
    _selectedYear = provider.selectedMonth.year;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _promptNewCustomBook(BuildContext dialogContext) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final createdName = await showDialog<String>(
      context: dialogContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(dialogCtx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: Theme.of(dialogCtx).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('New Custom Book', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a dedicated book for trips, projects, side businesses, or special events.',
                style: Theme.of(dialogCtx).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Book Name',
                  hintText: 'e.g. Trip to Cox\'s Bazar',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a book name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, controller.text.trim());
              }
            },
            child: const Text('Create Book'),
          ),
        ],
      ),
    );

    if (createdName != null && createdName.isNotEmpty && mounted) {
      final provider = context.read<TransactionProvider>();
      await provider.createCustomBook(createdName);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = context.watch<TransactionProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Active Book',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Switch between monthly books and custom books',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                labelColor: scheme.onPrimary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.calendar_month_rounded, size: 18),
                    text: 'Monthly Books',
                  ),
                  Tab(
                    icon: Icon(Icons.bookmark_added_rounded, size: 18),
                    text: 'Custom Books',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            SizedBox(
              height: 310,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Monthly Books
                  _buildMonthlyTab(context, provider),

                  // Tab 2: Custom Books
                  _buildCustomBooksTab(context, provider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTab(BuildContext context, TransactionProvider provider) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    final isSelectedMonthInView = !provider.isCustomBookSelected &&
        provider.selectedMonth.year == _selectedYear;

    return Column(
      children: [
        // Year Stepper
        Row(
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
        const SizedBox(height: 10),

        // 12 Months Grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isCurrent = now.year == _selectedYear && now.month == month;
              final isSelected = isSelectedMonthInView &&
                  provider.selectedMonth.month == month;

              final monthDate = DateTime(_selectedYear, month);
              final txCount = provider
                  .transactionsForMonth(monthDate)
                  .where((t) => t.customBook == null)
                  .length;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.setSelectedMonth(monthDate);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : isCurrent
                            ? scheme.primaryContainer.withValues(alpha: 0.5)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : isCurrent
                              ? scheme.primary.withValues(alpha: 0.4)
                              : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _months[index],
                        style: TextStyle(
                          color: isSelected
                              ? scheme.onPrimary
                              : isCurrent
                                  ? scheme.primary
                                  : scheme.onSurface,
                          fontWeight: isSelected || isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (txCount > 0) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$txCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Action Row: Clear Selected Month Data & Jump to Today
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) {
                  final activeMonth = provider.selectedMonth;
                  final activeMonthTxs = provider
                      .transactionsForMonth(activeMonth)
                      .where((t) => t.customBook == null)
                      .length;

                  if (activeMonthTxs == 0) return const SizedBox.shrink();

                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () async {
                      final monthName =
                          '${_months[activeMonth.month - 1]} ${activeMonth.year}';
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete $monthName data?'),
                          content: Text(
                            'This will delete all $activeMonthTxs transactions in $monthName.\n\nThis cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                                foregroundColor: scheme.onError,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete Data'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        final deleted = await provider
                            .deleteMonthTransactions(activeMonth);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                deleted
                                    ? '$monthName data deleted.'
                                    : 'Could not delete month data.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: Text(
                      'Clear ${_months[activeMonth.month - 1]} data',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  provider.resetToCurrentMonth();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.today_rounded, size: 16),
                label: const Text('Jump to This Month'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBooksTab(BuildContext context, TransactionProvider provider) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customBooks = provider.customBooks;

    return Column(
      children: [
        // Create New Book Button
        FilledButton.tonalIcon(
          onPressed: () => _promptNewCustomBook(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'New Custom Book',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Custom Books List
        Expanded(
          child: customBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 48,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No custom books yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "+ New Custom Book" above to create one.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: customBooks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bookName = customBooks[index];
                    final isSelected = provider.isCustomBookSelected &&
                        provider.selectedCustomBook == bookName;

                    final bookTransactions = provider.transactions
                        .where((t) => t.customBook == bookName)
                        .toList();
                    final bookIncome = bookTransactions
                        .where((t) => t.isIncome)
                        .fold(0, (sum, t) => sum + t.amount);
                    final bookExpense = bookTransactions
                        .where((t) => !t.isIncome)
                        .fold(0, (sum, t) => sum + t.amount);
                    final bookNet = bookIncome - bookExpense;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.5)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? scheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.selectCustomBook(bookName);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.folder_special_rounded,
                            size: 18,
                            color: isSelected ? scheme.onPrimary : scheme.primary,
                          ),
                        ),
                        title: Text(
                          bookName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${bookTransactions.length} records • Net: ${MoneyFormatter.currency(bookNet)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              tooltip: 'Delete Book & Data',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete "$bookName"?'),
                                    content: Text(
                                      'This will delete the custom book and all ${bookTransactions.length} transactions under it.\n\nThis cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: scheme.error,
                                          foregroundColor: scheme.onError,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete Book & Data'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  await provider.deleteCustomBookTransactions(bookName);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
