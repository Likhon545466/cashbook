import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recurring_transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/money_formatter.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecurringProvider>().load();
      }
    });
  }

  Future<void> _openAddEditSheet([RecurringTransaction? existing]) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final categories = context.read<CategoryProvider>().categories;
    final transactionProvider = context.read<TransactionProvider>();

    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toString() : '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');

    String type = existing?.type ?? 'expense';
    String category = existing?.category ??
        (categories.where((c) => c.type == type).isNotEmpty
            ? categories.where((c) => c.type == type).first.name
            : 'Other');
    int dayOfMonth = existing?.dayOfMonth ?? 1;
    String? selectedBook = existing?.customBook;

    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = Theme.of(ctx);
          final scheme = theme.colorScheme;
          final availableCategories =
              categories.where((c) => c.type == type).toList();

          if (!availableCategories.any((c) => c.name == category)) {
            if (availableCategories.isNotEmpty) {
              category = availableCategories.first.name;
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null
                            ? 'New Recurring Entry'
                            : 'Edit Recurring Entry',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Templates automatically remind you to log fixed cashflow.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),

                      // Income / Expense Toggle
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'expense',
                            label: Text('Expense (Out)'),
                            icon: Icon(Icons.arrow_upward_rounded),
                          ),
                          ButtonSegment(
                            value: 'income',
                            label: Text('Income (In)'),
                            icon: Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
                        selected: {type},
                        onSelectionChanged: (set) {
                          setModalState(() {
                            type = set.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Title Field
                      TextFormField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Apartment Rent, Salary, WiFi',
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter a title' : null,
                      ),
                      const SizedBox(height: 14),

                      // Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (${MoneyFormatter.currencySymbol})',
                          hintText: 'e.g. 15000',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter an amount';
                          }
                          final parsed = int.tryParse(v.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: availableCategories.any((c) => c.name == category)
                            ? category
                            : (availableCategories.isNotEmpty
                                ? availableCategories.first.name
                                : null),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: availableCategories.map((c) {
                          return DropdownMenuItem(
                            value: c.name,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => category = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Day of Month Stepper
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Day of the Month',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Due on day $dayOfMonth of every month',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded),
                                  onPressed: dayOfMonth > 1
                                      ? () => setModalState(() => dayOfMonth--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$dayOfMonth',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: dayOfMonth < 31
                                      ? () => setModalState(() => dayOfMonth++)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Optional Custom Book
                      if (transactionProvider.customBooks.isNotEmpty) ...[
                        DropdownButtonFormField<String?>(
                          initialValue: selectedBook,
                          decoration: InputDecoration(
                            labelText: 'Assign to Book (Optional)',
                            prefixIcon: const Icon(Icons.folder_special_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Main Monthly Book'),
                            ),
                            ...transactionProvider.customBooks.map((b) {
                              return DropdownMenuItem<String?>(
                                value: b,
                                child: Text(b),
                              );
                            }),
                          ],
                          onChanged: (v) => setModalState(() => selectedBook = v),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Optional Note
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Note (Optional)',
                          hintText: 'Additional details or memo',
                          prefixIcon: const Icon(Icons.notes_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final provider = ctx.read<RecurringProvider>();
                            final amt = int.parse(amountController.text.trim());
                            final item = RecurringTransaction(
                              id: existing?.id,
                              title: titleController.text.trim(),
                              amount: amt,
                              type: type,
                              category: category,
                              dayOfMonth: dayOfMonth,
                              customBook: selectedBook,
                              note: noteController.text.trim(),
                              lastAppliedMonth: existing?.lastAppliedMonth,
                              isActive: existing?.isActive ?? true,
                            );

                            if (existing == null) {
                              await provider.addRecurring(item);
                            } else {
                              await provider.updateRecurring(item);
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                            }
                          }
                        },
                        child: Text(
                          existing == null
                              ? 'Create Template'
                              : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Recurring template created.' : 'Template updated.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = context.watch<RecurringProvider>();
    final items = provider.items;
    final dueItems = provider.dueItems;

    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recurring & Fixed',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Automate rent, bills, salary & subscriptions',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Template',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: provider.loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                // Due Banner if items are ready to apply
                if (dueItems.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.warning(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppSemanticColors.warning(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: AppSemanticColors.warning(context),
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${dueItems.length} recurring ${dueItems.length == 1 ? 'item is' : 'items are'} due',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Apply now to record them into this month\'s ledger.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppSemanticColors.warning(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () async {
                            final applied = await provider.applyAllDue(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    applied > 0
                                        ? 'Applied $applied recurring entries.'
                                        : 'No entries were applied.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Apply All'),
                        ),
                      ],
                    ),
                  ),
                ],

                if (items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.autorenew_rounded,
                            size: 56,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Recurring Templates',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Set up fixed rent, monthly bills, or salary\nto log them easily every month.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    final isAppliedThisMonth =
                        item.lastAppliedMonth == currentMonthKey;
                    final isDueNow = item.isDueForMonth(now);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isDueNow
                              ? AppSemanticColors.warning(context).withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: item.isIncome
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: item.isIncome
                                        ? Colors.green
                                        : Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.cleanTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.category} • Day ${item.dayOfMonth} of month',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: item.isActive,
                                  onChanged: (_) => provider.toggleActive(item),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.isIncome ? '+' : '-'}${MoneyFormatter.currency(item.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        color: item.isIncome
                                            ? AppSemanticColors.income(context)
                                            : AppSemanticColors.expense(context),
                                      ),
                                    ),
                                    if (item.customBook != null)
                                      Text(
                                        'Book: ${item.customBook}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (item.isActive) ...[
                                      if (isAppliedThisMonth)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Applied this month',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          onPressed: () async {
                                            final ok = await provider
                                                .applyRecurring(item, context);
                                            if (context.mounted && ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${item.cleanTitle} added to this month\'s ledger.',
                                                  ),
                                                  action: SnackBarAction(
                                                    label: 'Undo',
                                                    onPressed: () async {
                                                      await provider
                                                          .undoApplyRecurring(
                                                        item,
                                                        context,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Apply Entry'),
                                        ),
                                    ],
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded),
                                      onSelected: (val) async {
                                        if (val == 'undo_apply') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text('Undo "${item.cleanTitle}"?'),
                                              content: const Text(
                                                'This will mark the entry as unapplied for this month and remove the recorded transaction from your ledger.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Undo Apply'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && context.mounted) {
                                            final ok = await provider
                                                .undoApplyRecurring(item, context);
                                            if (context.mounted && ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Undid "${item.cleanTitle}" for this month.',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        } else if (val == 'edit') {
                                          _openAddEditSheet(item);
                                        } else if (val == 'delete') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text('Delete "${item.cleanTitle}"?'),
                                              content: const Text(
                                                'This template will be removed. Existing recorded transactions will remain in your history.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: scheme.error,
                                                    foregroundColor: scheme.onError,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && item.id != null) {
                                            await provider.deleteRecurring(item.id!);
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        if (isAppliedThisMonth)
                                          const PopupMenuItem(
                                            value: 'undo_apply',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.undo_rounded,
                                                  size: 18,
                                                  color: Colors.orangeAccent,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Undo Apply',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit Template'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Colors.redAccent,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
