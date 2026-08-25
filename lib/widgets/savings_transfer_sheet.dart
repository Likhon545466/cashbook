import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/savings_provider.dart';
import '../utils/amount_expression.dart';
import '../utils/money_formatter.dart';
import 'smart_amount_field.dart';

Future<bool?> showSavingsTransferSheet(
  BuildContext context, {
  required bool deposit,
  required int availableBalance,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SavingsTransferSheet(
      deposit: deposit,
      availableBalance: availableBalance,
    ),
  );
}

class _SavingsTransferSheet extends StatefulWidget {
  final bool deposit;
  final int availableBalance;

  const _SavingsTransferSheet({
    required this.deposit,
    required this.availableBalance,
  });

  @override
  State<_SavingsTransferSheet> createState() => _SavingsTransferSheetState();
}

class _SavingsTransferSheetState extends State<_SavingsTransferSheet> {
  final _controller = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final amount = AmountExpression.evaluate(_controller.text) ?? 0;
    final savings = context.read<SavingsProvider>();

    if (amount <= 0) {
      _message('Enter a valid amount.');
      return;
    }

    if (widget.deposit && amount > widget.availableBalance) {
      _message('Not enough available balance.');
      return;
    }

    if (!widget.deposit && amount > savings.balance) {
      _message('Not enough savings balance.');
      return;
    }

    setState(() => _saving = true);

    final note = _noteController.text.trim();

    final success = widget.deposit
        ? await savings.deposit(amount: amount, note: note)
        : await savings.withdraw(amount: amount, note: note);

    if (!mounted) return;

    if (success) {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      _message(savings.errorMessage ?? 'Could not update savings.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final savings = context.watch<SavingsProvider>();
    final max = widget.deposit ? widget.availableBalance : savings.balance;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.deposit ? 'Add to Savings' : 'Withdraw from Savings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            'Available: ${MoneyFormatter.currency(max)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          SmartAmountField(
            controller: _controller,
            autofocus: true,
            labelText: 'Amount',
            compact: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: Icon(
                widget.deposit ? Icons.savings_outlined : Icons.undo_rounded,
              ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : widget.deposit
                    ? 'Reserve Money'
                    : 'Withdraw',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
