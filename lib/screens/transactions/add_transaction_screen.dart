import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/amount_expression.dart';
import '../../utils/category_icon.dart';
import '../../widgets/smart_amount_field.dart';

class AddTransactionScreen extends StatefulWidget {
  final String initialType;
  final CashTransaction? transaction;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'expense',
    this.transaction,
  });

  bool get isEditing => transaction != null;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();

  late String _type;
  String? _category;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _saveCompleted = false;
  bool _queuedDefaultCategory = false;
  String? _categoryPulse;

  Color get _typeColor => _type == 'income'
      ? AppSemanticColors.income(context)
      : AppSemanticColors.expense(context);

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      _type = transaction.type;
      _category = transaction.category;
      _date = transaction.date;
      _amountController.text = transaction.amount.toString();
      _noteController.text = transaction.note;
    } else {
      _type = widget.initialType == 'income' ? 'income' : 'expense';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _queueDefaultCategory(List<String> names) {
    if (_category != null || names.isEmpty || _queuedDefaultCategory) return;

    _queuedDefaultCategory = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedDefaultCategory = false;
      if (!mounted || _category != null || names.isEmpty) return;
      setState(() => _category = names.first);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _date.isAfter(now) ? now : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _date = picked);
    }
  }

  void _setToday() {
    HapticFeedback.selectionClick();
    setState(() => _date = DateTime.now());
  }

  void _setYesterday() {
    HapticFeedback.selectionClick();
    setState(() {
      _date = DateTime.now().subtract(const Duration(days: 1));
    });
  }

  void _changeType(String value, CategoryProvider provider) {
    if (_type == value) return;

    HapticFeedback.selectionClick();

    final next = provider.byType(value);

    setState(() {
      _type = value;
      _category = next.isEmpty ? null : next.first.name;
    });
  }

  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _type == 'income' ? 'Add Income Category' : 'Add Expense Category',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Category name'),
            onSubmitted: (value) {
              Navigator.pop(dialogContext, value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || name == null || name.trim().isEmpty) return;

    final provider = context.read<CategoryProvider>();
    final cleanName = name.trim();

    final added = await provider.addCategory(name: cleanName, type: _type);

    if (!mounted) return;

    if (added) {
      setState(() => _category = cleanName);
      await HapticFeedback.selectionClick();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category already exists or is invalid.')),
      );
    }
  }

  Future<void> _showAllCategories(
    List<String> names,
    List<dynamic> categories,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final onSurface = Theme.of(sheetContext).colorScheme.onSurface;
        final neutral = Theme.of(sheetContext).colorScheme.surfaceContainerLow;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _typeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 19,
                        color: _typeColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More Categories',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose from all ${names.length} categories',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: names.map((name) {
                    final active = _category == name;
                    final isLegacy = !categories.any(
                      (item) => item.name == name,
                    );

                    return ChoiceChip(
                      selected: active,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      labelPadding: const EdgeInsets.only(left: 3, right: 5),
                      backgroundColor: neutral,
                      selectedColor: _typeColor.withValues(alpha: 0.14),
                      side: BorderSide(
                        color: active
                            ? _typeColor.withValues(alpha: 0.68)
                            : Theme.of(sheetContext).dividerColor,
                      ),
                      avatar: Icon(
                        active
                            ? Icons.check_circle_rounded
                            : CategoryIcon.forName(
                                name,
                                isIncome: _type == 'income',
                              ),
                        size: 18,
                        color: active
                            ? _typeColor
                            : onSurface.withValues(alpha: 0.78),
                      ),
                      label: Text(
                        isLegacy ? '$name (old)' : name,
                        softWrap: true,
                        style: TextStyle(
                          color: active ? _typeColor : onSurface,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      onSelected: (_) => Navigator.pop(sheetContext, name),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _category = selected);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = AmountExpression.evaluate(_amountController.text);

    if (amount == null || amount <= 0 || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a category to continue.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<TransactionProvider>();

      final transaction = CashTransaction(
        id: widget.transaction?.id,
        type: _type,
        amount: amount,
        category: _category!,
        date: _date,
        note: _noteController.text.trim(),
      );

      final success = widget.isEditing
          ? await provider.updateTransaction(transaction)
          : await provider.addTransaction(transaction);

      if (!mounted) return;

      if (success) {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;

        setState(() {
          _isSaving = false;
          _saveCompleted = true;
        });

        await Future<void>.delayed(const Duration(milliseconds: 320));

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Could not save transaction.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && !_saveCompleted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.byType(_type);

    final names = categories.map((item) => item.name).toList();

    // Preserve a deleted/legacy category while editing instead of silently
    // replacing it with the first available category.
    if (widget.isEditing && _category != null && !names.contains(_category)) {
      names.insert(0, _category!);
    }

    _queueDefaultCategory(names);

    // Keep the quick category area compact. Show only a small preview so
    // the section stays around two rows on typical phone widths; everything
    // else remains available from the More Categories sheet.
    const quickCategoryLimit = 4;
    final visibleNames = <String>[...names.take(quickCategoryLimit)];

    // If the currently selected category lives in More Categories, keep it
    // visible in the quick area instead of making the selection disappear.
    if (_category != null &&
        names.contains(_category) &&
        !visibleNames.contains(_category) &&
        visibleNames.isNotEmpty) {
      visibleNames[visibleNames.length - 1] = _category!;
    }

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final neutralSurface = Theme.of(context).colorScheme.surfaceContainerLow;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Transaction' : 'Add Transaction',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: AnimatedScale(
            scale: _saveCompleted ? 0.98 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FilledButton(
              style: _saveCompleted
                  ? FilledButton.styleFrom(
                      backgroundColor: AppSemanticColors.income(context),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppSemanticColors.income(
                        context,
                      ),
                      disabledForegroundColor: Colors.white,
                    )
                  : null,
              onPressed: _isSaving || _saveCompleted ? null : _save,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.92,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _saveCompleted
                    ? const Row(
                        key: ValueKey('saved'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded),
                          SizedBox(width: 8),
                          Text(
                            'Saved',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      )
                    : _isSaving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        widget.isEditing
                            ? 'Update Transaction'
                            : _type == 'income'
                            ? 'Save Cash In'
                            : 'Save Cash Out',
                        key: ValueKey(_type),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TypeOption(
                        label: 'Cash In',
                        icon: Icons.south_west_rounded,
                        selected: _type == 'income',
                        color: AppSemanticColors.income(context),
                        onTap: _isSaving
                            ? null
                            : () => _changeType('income', categoryProvider),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypeOption(
                        label: 'Cash Out',
                        icon: Icons.north_east_rounded,
                        selected: _type == 'expense',
                        color: AppSemanticColors.expense(context),
                        onTap: _isSaving
                            ? null
                            : () => _changeType('expense', categoryProvider),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Amount',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.055),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SmartAmountField(
                    focusNode: _amountFocusNode,
                    controller: _amountController,
                    enabled: !_isSaving,
                    autofocus: false,
                    labelText: 'Amount',
                    hintText: 'Enter Amount',
                    premiumCalculator: false,
                    compact: true,
                    accentColor: _typeColor,
                    resultLabel: 'Live total',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: _typeColor,
                    ),
                    prefixStyle: TextStyle(
                      color: _typeColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: _typeColor.withValues(alpha: 0.24),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: _typeColor.withValues(alpha: 0.28),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: _typeColor, width: 1.6),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.6,
                      ),
                    ),
                    validator: (amount) {
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 22),
                _LabelRow(
                  title: 'Category',
                  trailing: TextButton.icon(
                    onPressed: _isSaving ? null : _addCustomCategory,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
                ),
                const SizedBox(height: 10),
                if (names.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No category available. Create one to continue.',
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      ...visibleNames.map((name) {
                        final selected = _category == name;
                        final isLegacy = !categories.any(
                          (item) => item.name == name,
                        );

                        return AnimatedScale(
                          scale: _categoryPulse == name ? 1.06 : 1,
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutBack,
                          child: ChoiceChip(
                            selected: selected,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            labelPadding: const EdgeInsets.only(
                              left: 3,
                              right: 5,
                            ),
                            backgroundColor: neutralSurface,
                            selectedColor: _typeColor.withValues(alpha: 0.14),
                            side: BorderSide(
                              color: selected
                                  ? _typeColor.withValues(alpha: 0.68)
                                  : Theme.of(context).dividerColor,
                            ),
                            avatar: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : CategoryIcon.forName(
                                      name,
                                      isIncome: _type == 'income',
                                    ),
                              size: 18,
                              color: selected
                                  ? _typeColor
                                  : onSurface.withValues(alpha: 0.78),
                            ),
                            label: Text(
                              isLegacy ? '$name (old)' : name,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: selected ? _typeColor : onSurface,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            onSelected: _isSaving
                                ? null
                                : (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _category = name;
                                      _categoryPulse = name;
                                    });
                                    Future<void>.delayed(
                                      const Duration(milliseconds: 180),
                                      () {
                                        if (mounted && _categoryPulse == name) {
                                          setState(() => _categoryPulse = null);
                                        }
                                      },
                                    );
                                  },
                          ),
                        );
                      }),
                      if (names.length > visibleNames.length)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          avatar: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _typeColor,
                          ),
                          label: Text(
                            'More (${names.length - visibleNames.length})',
                            style: TextStyle(
                              color: _typeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          side: BorderSide(
                            color: _typeColor.withValues(alpha: 0.30),
                          ),
                          backgroundColor: _typeColor.withValues(alpha: 0.06),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _showAllCategories(names, categories);
                                },
                        ),
                    ],
                  ),
                const SizedBox(height: 22),
                const _LabelRow(title: 'Date'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DateOption(
                        label: 'Today',
                        selected: _isSameDay(_date, DateTime.now()),
                        onTap: _setToday,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateOption(
                        label: 'Yesterday',
                        selected: _isSameDay(
                          _date,
                          DateTime.now().subtract(const Duration(days: 1)),
                        ),
                        onTap: _setYesterday,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Choose date',
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _LabelRow(title: 'Note', subtitle: 'Optional'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Add a short note',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.68)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? color : onSurface.withValues(alpha: 0.78),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.50)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _LabelRow({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}
