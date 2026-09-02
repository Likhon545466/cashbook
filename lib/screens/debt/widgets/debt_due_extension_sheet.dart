import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/debt_due_extension_model.dart';
import '../../../models/debt_model.dart';
import 'debt_models.dart';

class DebtDueExtensionSheet extends StatefulWidget {
  final DebtItem debt;

  const DebtDueExtensionSheet({super.key, required this.debt});

  @override
  State<DebtDueExtensionSheet> createState() => _DebtDueExtensionSheetState();
}

class _DebtDueExtensionSheetState extends State<DebtDueExtensionSheet> {
  final _note = TextEditingController();
  late DateTime _date;

  DateTime get _minimumDate {
    final base = widget.debt.dueDate ?? widget.debt.createdAt;
    return DateTime(
      base.year,
      base.month,
      base.day,
    ).add(const Duration(days: 1));
  }

  @override
  void initState() {
    super.initState();

    final base = widget.debt.dueDate ?? widget.debt.createdAt;
    _date = DateTime(base.year, base.month + 1, base.day);

    if (_date.isBefore(_minimumDate)) {
      _date = _minimumDate;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(_minimumDate) ? _minimumDate : _date,
      firstDate: _minimumDate,
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
      helpText: widget.debt.dueDate == null
          ? 'Set new due date'
          : 'Extend due date',
    );

    if (!mounted || picked == null) return;

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    setState(() => _date = picked);
  }

  void _save() {
    Navigator.pop(
      context,
      DueExtensionDraft(newDueDate: _date, note: _note.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.debt.dueDate;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        previous == null ? 'Set Due Date' : 'Extend Due Date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.debt.person,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (previous != null)
              ExtensionDateCompare(
                label: 'Current due',
                value: previous,
                muted: true,
              ),
            if (previous != null) const SizedBox(height: 8),
            ExtensionDateCompare(
              label: previous == null ? 'Due date' : 'Extended to',
              value: _date,
              highlighted: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 120,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason / Note',
                hintText: 'Optional, e.g. partial payment, agreed extension',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  previous == null ? 'Set Due Date' : 'Confirm Extension',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExtensionDateCompare extends StatelessWidget {
  final String label;
  final DateTime value;
  final bool muted;
  final bool highlighted;
  final VoidCallback? onTap;

  const ExtensionDateCompare({
    super.key,
    required this.label,
    required this.value,
    this.muted = false,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: highlighted
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                highlighted
                    ? Icons.event_available_rounded
                    : Icons.event_outlined,
                color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(value),
                style: TextStyle(
                  color: highlighted
                      ? scheme.primary
                      : muted
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DueExtensionHistoryTile extends StatelessWidget {
  final DebtDueExtension extension;

  const DueExtensionHistoryTile({super.key, required this.extension});

  @override
  Widget build(BuildContext context) {
    final oldLabel = extension.oldDueDate == null
        ? 'No previous due date'
        : DateFormat('dd MMM yyyy').format(extension.oldDueDate!);
    final newLabel = DateFormat('dd MMM yyyy').format(extension.newDueDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$oldLabel → $newLabel',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    extension.note.isEmpty
                        ? 'Changed ${DateFormat('dd MMM yyyy').format(extension.changedAt)}'
                        : '${DateFormat('dd MMM yyyy').format(extension.changedAt)} • ${extension.note}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
