import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/debt_model.dart';
import '../../../models/debt_payment_model.dart';
import '../../../utils/amount_expression.dart';
import '../../../utils/money_formatter.dart';
import '../../../widgets/smart_amount_field.dart';
import 'debt_models.dart';

class DebtPaymentSheet extends StatefulWidget {
  final DebtItem debt;
  final int remaining;
  final DebtPayment? payment;

  const DebtPaymentSheet({
    super.key,
    required this.debt,
    required this.remaining,
    this.payment,
  });

  @override
  State<DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends State<DebtPaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _useFullRemaining = false;
  String _source = 'main';

  @override
  void initState() {
    super.initState();

    final payment = widget.payment;
    if (payment != null) {
      _amount.text = payment.amount.toString();
      _note.text = payment.note;
      _date = payment.date;
      _source = payment.source;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(
      widget.debt.createdAt.year,
      widget.debt.createdAt.month,
      widget.debt.createdAt.day,
    );
    final initialDate = _date.isBefore(firstDate) ? firstDate : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
    );

    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final amount = AmountExpression.evaluate(_amount.text) ?? 0;

    if (amount <= 0 || amount > widget.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter an amount up to ${MoneyFormatter.currency(widget.remaining)}.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      PaymentDraft(
        amount: amount,
        date: _date,
        note: _note.text.trim(),
        source: _source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            Text(
              widget.payment != null
                  ? 'Edit Debt Payment'
                  : (widget.debt.isYouOwe
                        ? 'Record Repayment'
                        : 'Record Collection'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.debt.person} • Remaining ${MoneyFormatter.currency(widget.remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: _useFullRemaining
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _useFullRemaining
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _useFullRemaining = true;
                      _amount.text = widget.remaining.toString();
                      _amount.selection = TextSelection.collapsed(
                        offset: _amount.text.length,
                      );
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _useFullRemaining
                              ? Icons.check_circle_rounded
                              : Icons.done_all_rounded,
                          size: 18,
                          color: _useFullRemaining
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _useFullRemaining
                                ? 'Full remaining selected • ${MoneyFormatter.currency(widget.remaining)}'
                                : 'Use full remaining ${MoneyFormatter.currency(widget.remaining)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _useFullRemaining
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SmartAmountField(
              controller: _amount,
              autofocus: true,
              labelText: 'Amount',
              compact: true,
              onChanged: (_) {
                if (_useFullRemaining) {
                  setState(() => _useFullRemaining = false);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(DateFormat('dd MMM yyyy').format(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        builder: (sheetContext) {
                          final receive = !widget.debt.isYouOwe;
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      receive ? 'Receive To' : 'Pay From',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  title: const Text('Main Balance'),
                                  trailing: _source == 'main'
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext, 'main');
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.savings_outlined),
                                  title: const Text('Savings'),
                                  trailing: _source == 'savings'
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () {
                                    Navigator.pop(sheetContext, 'savings');
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      );

                      if (!mounted || selected == null) return;

                      setState(() => _source = selected);
                    },
                    icon: Icon(
                      _source == 'main'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.savings_outlined,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _source == 'main' ? 'Main Balance' : 'Savings',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.payment != null ? 'Save Changes' : 'Record Payment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
