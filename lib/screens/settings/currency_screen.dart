import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../utils/money_formatter.dart';

class CurrencyOption {
  final String symbol;
  final String code;
  final String name;

  const CurrencyOption({
    required this.symbol,
    required this.code,
    required this.name,
  });
}

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  static const List<CurrencyOption> defaultCurrencies = [
    CurrencyOption(symbol: '৳', code: 'BDT', name: 'Bangladeshi Taka'),
    CurrencyOption(symbol: '\$', code: 'USD', name: 'US Dollar'),
    CurrencyOption(symbol: '€', code: 'EUR', name: 'Euro'),
    CurrencyOption(symbol: '£', code: 'GBP', name: 'British Pound'),
    CurrencyOption(symbol: '₹', code: 'INR', name: 'Indian Rupee'),
    CurrencyOption(symbol: 'C\$', code: 'CAD', name: 'Canadian Dollar'),
    CurrencyOption(symbol: 'A\$', code: 'AUD', name: 'Australian Dollar'),
    CurrencyOption(symbol: '¥', code: 'JPY', name: 'Japanese Yen'),
    CurrencyOption(symbol: '¥', code: 'CNY', name: 'Chinese Yuan'),
    CurrencyOption(symbol: '₩', code: 'KRW', name: 'South Korean Won'),
    CurrencyOption(symbol: '﷼', code: 'SAR', name: 'Saudi Riyal'),
    CurrencyOption(symbol: 'د.إ', code: 'AED', name: 'UAE Dirham'),
    CurrencyOption(symbol: '₨', code: 'PKR', name: 'Pakistani Rupee'),
    CurrencyOption(symbol: 'Rs', code: 'LKR', name: 'Sri Lankan Rupee'),
    CurrencyOption(symbol: 'Rs', code: 'NPR', name: 'Nepalese Rupee'),
    CurrencyOption(symbol: 'RM', code: 'MYR', name: 'Malaysian Ringgit'),
    CurrencyOption(symbol: 'S\$', code: 'SGD', name: 'Singapore Dollar'),
    CurrencyOption(symbol: 'Rp', code: 'IDR', name: 'Indonesian Rupiah'),
    CurrencyOption(symbol: '₱', code: 'PHP', name: 'Philippine Peso'),
    CurrencyOption(symbol: '฿', code: 'THB', name: 'Thai Baht'),
    CurrencyOption(symbol: '₫', code: 'VND', name: 'Vietnamese Dong'),
    CurrencyOption(symbol: 'R\$', code: 'BRL', name: 'Brazilian Real'),
    CurrencyOption(symbol: '₺', code: 'TRY', name: 'Turkish Lira'),
    CurrencyOption(symbol: 'R', code: 'ZAR', name: 'South African Rand'),
    CurrencyOption(symbol: 'Fr', code: 'CHF', name: 'Swiss Franc'),
    CurrencyOption(symbol: '₦', code: 'NGN', name: 'Nigerian Naira'),
    CurrencyOption(symbol: 'E£', code: 'EGP', name: 'Egyptian Pound'),
  ];

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCurrency(String symbol, String code) async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    await context.read<SettingsProvider>().setCurrency(
      symbol: symbol,
      code: code,
    );
  }

  Future<void> _openCustomCurrencyDialog() async {
    final settings = context.read<SettingsProvider>();
    final symbolController = TextEditingController(text: settings.currencySymbol);
    final codeController = TextEditingController(text: settings.currencyCode);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolController,
              autofocus: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Currency Symbol (e.g. \$, ৳, ₿, Kr)',
                hintText: '\$',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Currency Code (e.g. USD, BDT, BTC)',
                hintText: 'USD',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final newSymbol = symbolController.text.trim();
    final newCode = codeController.text.trim().toUpperCase();

    symbolController.dispose();
    codeController.dispose();

    if (confirmed == true && newSymbol.isNotEmpty && mounted) {
      await _selectCurrency(newSymbol, newCode.isNotEmpty ? newCode : newSymbol);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Currency changed to $newSymbol ($newCode)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentSymbol = settings.currencySymbol;
    final currentCode = settings.currencyCode;
    final scheme = Theme.of(context).colorScheme;

    final filtered = CurrencyScreen.defaultCurrencies.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(query) ||
          item.code.toLowerCase().contains(query) ||
          item.symbol.toLowerCase().contains(query);
    }).toList();

    final isCustomSelected = !CurrencyScreen.defaultCurrencies.any(
      (item) => item.symbol == currentSymbol && item.code == currentCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Currency',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Custom Currency',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _openCustomCurrencyDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      currentSymbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Currency: $currentCode ($currentSymbol)',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preview: ${MoneyFormatter.currency(12500)}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search currency name or code...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: 14),
          if (isCustomSelected) ...[
            Card(
              color: scheme.primary.withValues(alpha: 0.08),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(currentSymbol, style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                title: Text('$currentCode (Custom)', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Symbol: $currentSymbol'),
                trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...filtered.map((item) {
            final isSelected = item.symbol == currentSymbol && item.code == currentCode;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _selectCurrency(item.symbol, item.code),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isSelected ? scheme.primary : scheme.surfaceContainerLow)
                        .withValues(alpha: isSelected ? 0.15 : 1.0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.symbol,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                title: Text(
                  '${item.name} (${item.code})',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? scheme.primary : null,
                  ),
                ),
                subtitle: Text('Example: ${MoneyFormatter.currency(1500, item.symbol)}'),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : null,
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openCustomCurrencyDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add / Use Custom Currency'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
