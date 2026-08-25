import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/amount_expression.dart';
import '../utils/money_formatter.dart';

class SmartAmountField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? hintText;
  final bool autofocus;
  final bool enabled;
  final TextStyle? style;
  final TextStyle? prefixStyle;
  final TextAlign textAlign;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final InputBorder? focusedErrorBorder;
  final bool filled;
  final Color? fillColor;
  final ValueChanged<int?>? onResultChanged;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(int? value)? validator;
  final bool compact;
  final bool showCalculator;
  final bool premiumCalculator;
  final Color? accentColor;
  final String resultLabel;

  const SmartAmountField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText = 'Amount',
    this.hintText,
    this.autofocus = false,
    this.enabled = true,
    this.style,
    this.prefixStyle,
    this.textAlign = TextAlign.start,
    this.contentPadding,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.errorBorder,
    this.focusedErrorBorder,
    this.filled = false,
    this.fillColor,
    this.onResultChanged,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.compact = false,
    this.showCalculator = true,
    this.premiumCalculator = false,
    this.accentColor,
    this.resultLabel = 'Total',
  });

  @override
  State<SmartAmountField> createState() => _SmartAmountFieldState();
}

class _SmartAmountFieldState extends State<SmartAmountField> {
  late final FocusNode _internalFocusNode;
  late FocusNode _focusNode;
  int? _result;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _focusNode = widget.focusNode ?? _internalFocusNode;
    widget.controller.addListener(_recalculate);
    _recalculate(notify: false);
  }

  @override
  void didUpdateWidget(covariant SmartAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_recalculate);
      widget.controller.addListener(_recalculate);
      _recalculate(notify: false);
    }

    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode = widget.focusNode ?? _internalFocusNode;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recalculate);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _recalculate({bool notify = true}) {
    final value = AmountExpression.evaluate(widget.controller.text);

    if (_result == value) {
      if (notify) widget.onResultChanged?.call(value);
      return;
    }

    if (mounted) {
      setState(() => _result = value);
    } else {
      _result = value;
    }

    if (notify) widget.onResultChanged?.call(value);
  }

  void _appendOperator(String operator) {
    if (!widget.enabled) return;

    var text = widget.controller.text.trimRight();
    if (text.isEmpty) return;

    final normalized = operator == '×'
        ? '*'
        : operator == '÷'
        ? '/'
        : operator == '−'
        ? '-'
        : operator;

    final last = text[text.length - 1];
    final isLastOperator =
        last == '+' ||
        last == '-' ||
        last == '*' ||
        last == '/' ||
        last == '×' ||
        last == '÷' ||
        last == '−';

    if (isLastOperator) {
      text = text.substring(0, text.length - 1).trimRight();
    }

    final next = '$text $normalized ';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );

    widget.onChanged?.call(widget.controller.text);
    _focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _clear() {
    if (!widget.enabled) return;
    widget.controller.clear();
    widget.onChanged?.call(widget.controller.text);
    _focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _backspace() {
    if (!widget.enabled) return;

    var text = widget.controller.text.trimRight();
    if (text.isEmpty) return;

    text = text.substring(0, text.length - 1).trimRight();

    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    widget.onChanged?.call(widget.controller.text);
    _focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? scheme.primary;
    final expression = widget.controller.text.trim();
    final hasExpression =
        expression.contains(RegExp(r'[+\-*/×÷−]')) && expression.isNotEmpty;
    final result = _result;
    final validPositive = result != null && result > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: widget.textAlign,
          style: widget.style,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-*/×÷− ]')),
            LengthLimitingTextInputFormatter(40),
          ],
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('৳', style: widget.prefixStyle),
            ),
            contentPadding: widget.contentPadding,
            filled: widget.filled,
            fillColor: widget.fillColor,
            border: widget.border,
            enabledBorder: widget.enabledBorder,
            focusedBorder: widget.focusedBorder,
            errorBorder: widget.errorBorder,
            focusedErrorBorder: widget.focusedErrorBorder,
          ),
          validator: (_) => widget.validator?.call(_result),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
        ),
        if (widget.showCalculator) ...[
          SizedBox(height: widget.compact ? 8 : 12),
          widget.premiumCalculator
              ? _PremiumCalculatorPanel(
                  accent: accent,
                  expression: expression,
                  hasExpression: hasExpression,
                  validPositive: validPositive,
                  result: result,
                  resultLabel: widget.resultLabel,
                  enabled: widget.enabled,
                  onOperatorTap: _appendOperator,
                  onBackspace: _backspace,
                  onClear: _clear,
                )
              : _CompactCalculatorPanel(
                  accent: accent,
                  expression: expression,
                  hasExpression: hasExpression,
                  validPositive: validPositive,
                  result: result,
                  resultLabel: widget.resultLabel,
                  enabled: widget.enabled,
                  compact: widget.compact,
                  onOperatorTap: _appendOperator,
                  onBackspace: _backspace,
                  onClear: _clear,
                ),
        ],
      ],
    );
  }
}

class _CompactCalculatorPanel extends StatelessWidget {
  final Color accent;
  final String expression;
  final bool hasExpression;
  final bool validPositive;
  final int? result;
  final String resultLabel;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onOperatorTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _CompactCalculatorPanel({
    required this.accent,
    required this.expression,
    required this.hasExpression,
    required this.validPositive,
    required this.result,
    required this.resultLabel,
    required this.enabled,
    required this.compact,
    required this.onOperatorTap,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasExpression
                      ? expression.replaceAll('*', ' × ').replaceAll('/', ' ÷ ')
                      : 'Quick calculator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: validPositive
                      ? accent.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result == null
                      ? 'Type amount'
                      : '$resultLabel ${MoneyFormatter.currency(result ?? 0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: validPositive ? accent : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            children: [
              for (final operator in const ['+', '−', '×', '÷']) ...[
                Expanded(
                  child: _OperatorButton(
                    label: operator,
                    onTap: enabled ? () => onOperatorTap(operator) : null,
                    accent: accent,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _UtilityButton(
                icon: Icons.backspace_outlined,
                tooltip: 'Backspace',
                onTap: enabled ? onBackspace : null,
                compact: compact,
              ),
              const SizedBox(width: 6),
              _UtilityButton(
                icon: Icons.clear_rounded,
                tooltip: 'Clear',
                onTap: enabled ? onClear : null,
                compact: compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumCalculatorPanel extends StatelessWidget {
  final Color accent;
  final String expression;
  final bool hasExpression;
  final bool validPositive;
  final int? result;
  final String resultLabel;
  final bool enabled;
  final ValueChanged<String> onOperatorTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _PremiumCalculatorPanel({
    required this.accent,
    required this.expression,
    required this.hasExpression,
    required this.validPositive,
    required this.result,
    required this.resultLabel,
    required this.enabled,
    required this.onOperatorTap,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.10), scheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expression',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expression.isEmpty
                            ? 'Type with your keyboard, then use operators below'
                            : expression
                                  .replaceAll('*', ' × ')
                                  .replaceAll('/', ' ÷ '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: expression.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 112,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: validPositive
                      ? accent.withValues(alpha: 0.14)
                      : scheme.surface.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: validPositive
                        ? accent.withValues(alpha: 0.22)
                        : scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resultLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: validPositive ? accent : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result == null
                          ? '—'
                          : MoneyFormatter.currency(result ?? 0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: validPositive ? accent : scheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PremiumOperatorButton(
                  symbol: '+',
                  label: 'Add',
                  onTap: enabled ? () => onOperatorTap('+') : null,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumOperatorButton(
                  symbol: '−',
                  label: 'Minus',
                  onTap: enabled ? () => onOperatorTap('−') : null,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumOperatorButton(
                  symbol: '×',
                  label: 'Multiply',
                  onTap: enabled ? () => onOperatorTap('×') : null,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PremiumOperatorButton(
                  symbol: '÷',
                  label: 'Divide',
                  onTap: enabled ? () => onOperatorTap('÷') : null,
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SecondaryActionButton(
                  icon: Icons.backspace_outlined,
                  label: 'Backspace',
                  onTap: enabled ? onBackspace : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryActionButton(
                  icon: Icons.clear_rounded,
                  label: 'Clear',
                  onTap: enabled ? onClear : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumOperatorButton extends StatelessWidget {
  final String symbol;
  final String label;
  final VoidCallback? onTap;
  final Color accent;

  const _PremiumOperatorButton({
    required this.symbol,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: FilledButton(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: accent.withValues(alpha: 0.12),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _OperatorButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color accent;

  const _OperatorButton({
    required this.label,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: accent.withValues(alpha: 0.10),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool compact;

  const _UtilityButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 38 : 40,
      height: compact ? 38 : 40,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
