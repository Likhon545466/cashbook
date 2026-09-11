import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_info.dart';
import '../../providers/cloud_sync_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/update_checker_modal.dart';
import '../transactions/recurring_transactions_screen.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'budget_screen.dart';
import 'category_management_screen.dart';
import 'currency_screen.dart';
import 'data_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setAppLock(BuildContext context, bool enabled) async {
    final security = context.read<SecurityProvider>();

    if (!enabled) {
      await security.disableAppLock();
      return;
    }

    final success = await security.enableAppLock();

    if (!context.mounted || success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(security.message ?? 'Could not enable App Lock.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    final settings = context.watch<SettingsProvider>();
    final cloudSync = context.watch<CloudSyncProvider>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage CashBook',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              _Tile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme mode, Dynamic Color and Theme Color',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Security'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: const _SettingsIcon(icon: Icons.fingerprint_rounded),
                title: const Text(
                  'App Lock',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Fingerprint, face, PIN, pattern or password',
                ),
                value: security.appLockEnabled,
                onChanged: security.isAuthenticating
                    ? null
                    : (value) => _setAppLock(context, value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Reminders & Alerts'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: const _SettingsIcon(icon: Icons.notifications_active_outlined),
                title: const Text(
                  'Daily Expense Reminder',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  settings.dailyReminderEnabled
                      ? 'Remind daily at ${settings.dailyReminderTime.format(context)}'
                      : 'Get prompted if you haven\'t logged expenses today',
                ),
                value: settings.dailyReminderEnabled,
                onChanged: (val) => settings.setDailyReminderEnabled(val),
              ),
              if (settings.dailyReminderEnabled) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const _SettingsIcon(icon: Icons.schedule_rounded),
                  title: const Text(
                    'Reminder Time',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Tap to change time'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      settings.dailyReminderTime.format(context),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: settings.dailyReminderTime,
                    );
                    if (picked != null) {
                      await settings.setDailyReminderTime(picked);
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Cloud & Sync'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              if (cloudSync.isSignedIn)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundImage:
                        cloudSync.userPhotoUrl != null && cloudSync.userPhotoUrl!.isNotEmpty
                            ? NetworkImage(cloudSync.userPhotoUrl!)
                            : null,
                    child: (cloudSync.userPhotoUrl == null || cloudSync.userPhotoUrl!.isEmpty)
                        ? Text(
                            (cloudSync.userDisplayName?.isNotEmpty == true
                                    ? cloudSync.userDisplayName![0]
                                    : cloudSync.userEmail?.isNotEmpty == true
                                    ? cloudSync.userEmail![0]
                                    : 'G')
                                .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  title: Text(
                    cloudSync.userDisplayName ??
                        cloudSync.userEmail ??
                        'Google Account',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    cloudSync.isSyncing
                        ? 'Syncing with Google Drive...'
                        : cloudSync.autoSyncEnabled
                        ? 'Auto-Sync enabled • Google Drive'
                        : 'Connected to Google Drive',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataManagementScreen(),
                    ),
                  ),
                )
              else
                _Tile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Google Cloud Sync',
                  subtitle: 'Connect Google Drive for auto-backup & restore',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DataManagementScreen(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Money'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              _Tile(
                icon: Icons.currency_exchange_rounded,
                title: 'Currency',
                subtitle: 'Active: ${settings.currencyCode} (${settings.currencySymbol})',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CurrencyScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _Tile(
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle: 'Income and expense categories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategoryManagementScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _Tile(
                icon: Icons.autorenew_rounded,
                title: 'Recurring & Fixed',
                subtitle: 'Automate rent, bills, salary & subscriptions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecurringTransactionsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _Tile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Monthly Budgets',
                subtitle: 'Plan limits and track spending',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('About & Updates'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              _Tile(
                icon: Icons.system_update_rounded,
                title: 'Check for Updates',
                subtitle: 'Verify GitHub releases & latest APK build',
                onTap: () => UpdateCheckerModal.show(context),
              ),
              const Divider(height: 1),
              _Tile(
                icon: Icons.info_outline_rounded,
                title: 'About CashBook',
                subtitle: '${AppInfo.fullVersion} • Changelog & GitHub',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;

  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(child: Column(children: children));
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _SettingsIcon(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;

  const _SettingsIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20),
    );
  }
}
