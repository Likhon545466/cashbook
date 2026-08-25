import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/savings_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/data_backup_service.dart';
import '../../services/data_integrity_service.dart';
import '../../services/database_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  late final DataBackupService _service;
  late final DataIntegrityService _integrityService;

  bool _busy = false;
  int _transactionCount = 0;
  int _customCategoryCount = 0;
  int _savingsTransferCount = 0;
  int _debtCount = 0;

  @override
  void initState() {
    super.initState();
    _service = DataBackupService(DatabaseService.instance);
    _integrityService = DataIntegrityService(DatabaseService.instance);
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final stats = await _service.getStats();

    if (!mounted) return;

    setState(() {
      _transactionCount = stats['transactions'] ?? 0;
      _customCategoryCount = stats['customCategories'] ?? 0;
      _savingsTransferCount = stats['savingsTransfers'] ?? 0;
      _debtCount = stats['debts'] ?? 0;
    });
  }

  Future<void> _checkDataHealth() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final result = await _integrityService.run();

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final healthy = result.healthy;
          final scheme = Theme.of(sheetContext).colorScheme;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: (healthy ? scheme.primary : scheme.error)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          healthy
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          color: healthy ? scheme.primary : scheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              healthy
                                  ? 'Data looks healthy'
                                  : 'Data issues found',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${result.checkedRecords} records checked • ${DateFormat('dd MMM, hh:mm a').format(result.checkedAt)}',
                              style: Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (healthy)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'SQLite integrity, foreign keys, balances, debt payments and core record values passed the checks.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _HealthCount(
                            label: 'Critical',
                            value: result.criticalCount,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HealthCount(
                            label: 'Warnings',
                            value: result.warningCount,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...result.issues.map((issue) {
                      final critical =
                          issue.severity == DataIntegritySeverity.critical;
                      final color = critical ? scheme.error : scheme.tertiary;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            critical
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            color: color,
                          ),
                          title: Text(
                            issue.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(issue.detail),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Text(
                      'This checker does not modify your data. Create a backup before manually correcting any issue.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Data health check failed', error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _backup() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _service.shareBackup();
    } catch (error) {
      if (!mounted) return;
      _showError('Backup failed', error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _service.shareCsv();
    } catch (error) {
      if (!mounted) return;
      _showError('CSV export failed', error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_busy) return;

    final choice = await showModalBottomSheet<_PdfExportChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export PDF',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose what you want in the report.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              ListTile(
                onTap: () =>
                    Navigator.pop(sheetContext, _PdfExportChoice.fullLedger),
                leading: const _DataIcon(icon: Icons.menu_book_outlined),
                title: const Text(
                  'Full Ledger',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'All cash, savings and debt entries in one PDF',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              ListTile(
                onTap: () =>
                    Navigator.pop(sheetContext, _PdfExportChoice.monthly),
                leading: const _DataIcon(icon: Icons.calendar_month_outlined),
                title: const Text(
                  'Monthly Summary',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Colorful summary plus every entry for one month',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              ListTile(
                onTap: () =>
                    Navigator.pop(sheetContext, _PdfExportChoice.customRange),
                leading: const _DataIcon(icon: Icons.date_range_outlined),
                title: const Text(
                  'Custom Date Range',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Choose exact start and end dates for the PDF ledger',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;

    DateTime? month;
    DateTimeRange? range;

    if (choice == _PdfExportChoice.monthly) {
      month = await _selectPdfMonth();
      if (!mounted || month == null) return;
    }

    if (choice == _PdfExportChoice.customRange) {
      final now = DateTime.now();
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        ),
        helpText: 'Select PDF date range',
        saveText: 'USE RANGE',
      );

      if (!mounted || range == null) return;
    }

    setState(() => _busy = true);

    try {
      await _service.sharePdfReport(
        month: choice == _PdfExportChoice.monthly ? month : null,
        startDate: choice == _PdfExportChoice.customRange ? range?.start : null,
        endDate: choice == _PdfExportChoice.customRange ? range?.end : null,
      );
    } catch (error) {
      if (!mounted) return;
      _showError('PDF export failed', error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<DateTime?> _selectPdfMonth() async {
    var selected = DateTime(DateTime.now().year, DateTime.now().month);

    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final now = DateTime.now();
            final currentMonth = DateTime(now.year, now.month);
            final canGoNext = selected.isBefore(currentMonth);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Month',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous month',
                              onPressed: () {
                                setSheetState(() {
                                  selected = DateTime(
                                    selected.year,
                                    selected.month - 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Text(
                                DateFormat('MMMM yyyy').format(selected),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next month',
                              onPressed: canGoNext
                                  ? () {
                                      setSheetState(() {
                                        selected = DateTime(
                                          selected.year,
                                          selected.month + 1,
                                        );
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, selected),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Export This Month'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restore() async {
    if (_busy) return;

    setState(() => _busy = true);

    BackupRestoreResult? backup;

    try {
      backup = await _service.pickAndReadBackup();
    } catch (error) {
      if (!mounted) return;
      _showError('Could not read backup', error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (!mounted || backup == null) return;

    final selectedBackup = backup;
    final transactionCount = selectedBackup.transactions.length;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restore backup?'),
            content: Text(
              selectedBackup.budgets == null
                  ? 'This is an older backup. It will replace transactions, '
                        'custom categories and preferences with $transactionCount '
                        'transactions. Current budgets, savings and debt will be kept.'
                  : selectedBackup.debts == null
                  ? 'This backup predates Debt. It will replace transactions, '
                        'categories, budgets, savings and preferences. Current debt '
                        'records will be kept.'
                  : 'This will replace transactions, custom categories, budgets, '
                        'savings, debt history and preferences with the selected backup '
                        '($transactionCount transactions).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !confirmed) return;

    final transactionProvider = context.read<TransactionProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final savingsProvider = context.read<SavingsProvider>();
    final debtProvider = context.read<DebtProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      await _service.restoreBackup(selectedBackup);

      await Future.wait([
        transactionProvider.loadTransactions(),
        categoryProvider.loadCategories(),
        settingsProvider.loadTheme(),
        savingsProvider.load(),
        debtProvider.load(),
        budgetProvider.loadCurrentMonth(),
      ]);

      await _refreshStats();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: ${_friendlyError(error)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clearAll() async {
    if (_busy) return;

    final controller = TextEditingController();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Clear all CashBook data?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently removes transactions, custom categories, '
                    'budgets, savings and debt history. Theme settings will stay.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'DELETE'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      controller.text.trim() == 'DELETE',
                    );
                  },
                  child: const Text('Clear Data'),
                ),
              ],
            );
          },
        ) ??
        false;

    controller.dispose();

    if (!mounted || !confirmed) return;

    final transactionProvider = context.read<TransactionProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final savingsProvider = context.read<SavingsProvider>();
    final debtProvider = context.read<DebtProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      await _service.clearUserData();

      await Future.wait([
        transactionProvider.loadTransactions(),
        categoryProvider.loadCategories(),
        savingsProvider.load(),
        debtProvider.load(),
        budgetProvider.loadCurrentMonth(),
      ]);

      await _refreshStats();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('CashBook data cleared.')),
      );
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not clear data: ${_friendlyError(error)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showError(String prefix, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$prefix: ${_friendlyError(error)}')),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.replaceFirst('FormatException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Data & Backup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Transactions',
                          value: '$_transactionCount',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Categories',
                          value: '$_customCategoryCount',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Savings',
                          value: '$_savingsTransferCount',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Theme.of(context).dividerColor,
                      ),
                      Expanded(
                        child: _StatItem(label: 'Debt', value: '$_debtCount'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Data Health'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              enabled: !_busy,
              leading: const _DataIcon(icon: Icons.health_and_safety_outlined),
              title: const Text(
                'Check Data Integrity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Scan database structure, balances, debt links and invalid records',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _checkDataHealth,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Backup & Restore'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: !_busy,
                  leading: const _DataIcon(icon: Icons.backup_outlined),
                  title: const Text(
                    'Create Local Backup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Export transactions, budgets, savings, debt and preferences',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _backup,
                ),
                const Divider(),
                ListTile(
                  enabled: !_busy,
                  leading: const _DataIcon(
                    icon: Icons.settings_backup_restore_rounded,
                  ),
                  title: const Text(
                    'Restore Backup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Replace current data from a CashBook JSON backup',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _restore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Export'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: !_busy,
                  leading: const _DataIcon(icon: Icons.picture_as_pdf_outlined),
                  title: const Text(
                    'Export PDF Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Full ledger or colorful monthly summary with entries',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportPdf,
                ),
                const Divider(),
                ListTile(
                  enabled: !_busy,
                  leading: const _DataIcon(icon: Icons.table_view_outlined),
                  title: const Text(
                    'Export Transactions as CSV',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Open in Excel, Google Sheets or other spreadsheet apps',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Danger Zone'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              enabled: !_busy,
              leading: const _DataIcon(
                icon: Icons.delete_forever_outlined,
                destructive: true,
              ),
              title: Text(
                'Clear All Data',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              subtitle: const Text(
                'Delete transactions, budgets, savings, debt and custom categories',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _clearAll,
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

enum _PdfExportChoice { fullLedger, monthly, customRange }

class _HealthCount extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _HealthCount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DataIcon extends StatelessWidget {
  final IconData icon;
  final bool destructive;

  const _DataIcon({required this.icon, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}
