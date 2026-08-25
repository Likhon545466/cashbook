import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/security_provider.dart';
import 'appearance_screen.dart';
import 'budget_screen.dart';
import 'category_management_screen.dart';
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
          const _SectionLabel('Money'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
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
          const _SectionLabel('Data'),
          const SizedBox(height: 8),
          _CardGroup(
            children: [
              _Tile(
                icon: Icons.shield_outlined,
                title: 'Data & Backup',
                subtitle: 'Backup, restore, export and clear data',
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
          const _SectionLabel('About'),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _SettingsIcon(icon: Icons.info_outline_rounded),
              title: Text(
                'CashBook',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Offline personal cash tracking'),
            ),
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
