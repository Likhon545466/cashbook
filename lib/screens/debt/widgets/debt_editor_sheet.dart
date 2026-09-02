import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/debt_model.dart';
import '../../../utils/amount_expression.dart';
import '../../../widgets/smart_amount_field.dart';
import 'debt_models.dart';

class DebtEditorSheet extends StatefulWidget {
  final DebtItem? item;

  const DebtEditorSheet({super.key, this.item});

  @override
  State<DebtEditorSheet> createState() => _DebtEditorSheetState();
}

class _DebtEditorSheetState extends State<DebtEditorSheet> {
  late String _direction;
  late final TextEditingController _person;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _createdAt;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    _direction = item?.direction ?? 'you_owe';
    _person = TextEditingController(text: item?.person ?? '');
    _amount = TextEditingController(
      text: item == null ? '' : item.amount.toString(),
    );
    _note = TextEditingController(text: item?.note ?? '');
    _createdAt = item?.createdAt ?? DateTime.now();
    _dueDate = item?.dueDate;
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickCreated() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (!mounted || picked == null) return;

    setState(() {
      _createdAt = picked;

      final due = _dueDate;
      if (due != null) {
        final createdDay = DateTime(picked.year, picked.month, picked.day);
        final dueDay = DateTime(due.year, due.month, due.day);

        if (dueDay.isBefore(createdDay)) {
          _dueDate = null;
        }
      }
    });
  }

  Future<void> _pickDue() async {
    final firstDay = DateTime(
      _createdAt.year,
      _createdAt.month,
      _createdAt.day,
    );

    final existing = _dueDate;
    final suggested = _createdAt.add(const Duration(days: 30));

    var initial = existing ?? suggested;
    if (initial.isBefore(firstDay)) {
      initial = firstDay;
    }

    final lastDay = DateTime(_createdAt.year + 20, 12, 31);
    if (initial.isAfter(lastDay)) {
      initial = lastDay;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDay,
      lastDate: lastDay,
    );

    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  void _save() {
    final person = _person.text.trim();
    final amount = AmountExpression.evaluate(_amount.text) ?? 0;

    if (person.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a person and valid amount.')),
      );
      return;
    }

    final due = _dueDate;
    if (due != null) {
      final createdDay = DateTime(
        _createdAt.year,
        _createdAt.month,
        _createdAt.day,
      );
      final dueDay = DateTime(due.year, due.month, due.day);

      if (dueDay.isBefore(createdDay)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Due date cannot be before created date.'),
          ),
        );
        return;
      }
    }

    Navigator.pop(
      context,
      DebtDraft(
        direction: _direction,
        person: person,
        amount: amount,
        createdAt: _createdAt,
        dueDate: _dueDate,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null ? 'Add Debt' : 'Edit Debt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DirectionOptionTile(
                    label: 'You Owe',
                    subtitle: 'I borrowed',
                    icon: Icons.call_made_rounded,
                    selected: _direction == 'you_owe',
                    onTap: () => setState(() {
                      _direction = 'you_owe';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionOptionTile(
                    label: 'Owed to You',
                    subtitle: 'I lent',
                    icon: Icons.call_received_rounded,
                    selected: _direction == 'owed_to_you',
                    onTap: () => setState(() {
                      _direction = 'owed_to_you';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartAmountField(
              controller: _amount,
              autofocus: widget.item == null,
              labelText: 'Total Amount',
              hintText: 'Enter amount first',
              compact: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person / Name',
                hintText: 'Who is this debt with?',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCreated,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: FittedBox(
                      child: Text(DateFormat('dd MMM yyyy').format(_createdAt)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDue,
                    icon: const Icon(Icons.event_outlined),
                    label: FittedBox(
                      child: Text(
                        _dueDate == null
                            ? 'Add Due Date'
                            : DateFormat('dd MMM yyyy').format(_dueDate!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_dueDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _dueDate = null;
                  }),
                  child: const Text('Remove due date'),
                ),
              ),
            if (widget.item != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Use this due date field only to correct a mistake. Use Extend Date when the actual deadline is moved.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 180,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional context',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Save Debt' : 'Update Debt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionOptionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.10)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
