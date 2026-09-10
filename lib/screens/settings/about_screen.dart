import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../services/app_update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AppUpdateService _updateService = AppUpdateService();
  bool _isChecking = false;
  UpdateCheckResult? _updateResult;
  DateTime? _lastCheckedTime;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _updateResult = null;
    });

    await AppInfo.init();
    final result = await _updateService.checkForUpdates();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _updateResult = result;
      _lastCheckedTime = DateTime.now();
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open link.')));
      }
    }
  }

  Future<void> _shareApp() async {
    await HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Check out CashBook - a fast, offline-first personal finance app: ${AppInfo.githubRepoUrl}',
        subject: 'CashBook App',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text(
          'About CashBook',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Share App',
            onPressed: _shareApp,
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Branding Hero Card
          _buildHeroCard(theme, scheme),
          const SizedBox(height: 16),

          // Update Checker Card
          _buildUpdateCheckerCard(theme, scheme),
          const SizedBox(height: 20),

          // Developer & GitHub Card
          const _SectionTitle('Developer & GitHub'),
          const SizedBox(height: 8),
          _buildDeveloperCard(theme, scheme),
          const SizedBox(height: 20),

          // Changelog Timeline
          const _SectionTitle('Version History & Changelog'),
          const SizedBox(height: 8),
          _buildChangelogList(theme, scheme),
          const SizedBox(height: 20),

          // Open Source & Privacy Badge
          _buildPrivacyCard(theme, scheme),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              AppInfo.appName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppInfo.appTagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppInfo.fullVersion,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCheckerCard(ThemeData theme, ColorScheme scheme) {
    final result = _updateResult;
    final isUpdateAvailable = result != null && result.hasUpdate;
    final isSuccess = result != null && result.isSuccess;

    Color cardBorderColor = scheme.outlineVariant.withValues(alpha: 0.4);
    if (isUpdateAvailable) {
      cardBorderColor = scheme.primary.withValues(alpha: 0.6);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cardBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isChecking
                        ? scheme.primary.withValues(alpha: 0.1)
                        : (isUpdateAvailable
                              ? AppSemanticColors.savings(
                                  context,
                                ).withValues(alpha: 0.15)
                              : (isSuccess
                                    ? AppSemanticColors.income(
                                        context,
                                      ).withValues(alpha: 0.12)
                                    : scheme.error.withValues(alpha: 0.12))),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isChecking
                        ? Icons.sync_rounded
                        : (isUpdateAvailable
                              ? Icons.system_update_rounded
                              : (isSuccess
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.cloud_off_rounded)),
                    color: _isChecking
                        ? scheme.primary
                        : (isUpdateAvailable
                              ? AppSemanticColors.savings(context)
                              : (isSuccess
                                    ? AppSemanticColors.income(context)
                                    : scheme.error)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isChecking
                            ? 'Checking for updates...'
                            : (isUpdateAvailable
                                  ? 'Update Available: ${result.latestVersion}'
                                  : (isSuccess
                                        ? 'You\'re on the latest version'
                                        : 'Update check failed')),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastCheckedTime != null
                            ? 'Checked: ${DateFormat('hh:mm a').format(_lastCheckedTime!)}'
                            : 'GitHub Releases API',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!_isChecking)
                  IconButton(
                    tooltip: 'Check Again',
                    onPressed: _checkForUpdates,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
              ],
            ),

            if (isUpdateAvailable &&
                result.releaseNotes != null &&
                result.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.releaseTitle != null)
                      Text(
                        result.releaseTitle!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      result.releaseNotes!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (result.downloadUrl != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(result.downloadUrl!),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download APK'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openUrl(result.htmlUrl ?? AppInfo.githubReleasesUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View Release'),
                  ),
                ],
              ),
            ],

            if (!isUpdateAvailable && isSuccess) ...[
              const SizedBox(height: 10),
              Text(
                'Running v${AppInfo.currentVersion} (Build ${AppInfo.currentBuildNumber}). No new updates found on GitHub.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],

            if (!isSuccess && result?.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                result!.errorMessage!,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openUrl(AppInfo.githubReleasesUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Visit GitHub Releases page'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCard(ThemeData theme, ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.person_outline_rounded, size: 22),
            ),
            title: const Text(
              '${AppInfo.developerName} (@${AppInfo.githubUsername})',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Developer & Maintainer'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _openUrl(AppInfo.githubUserUrl),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.code_rounded, size: 22),
            ),
            title: const Text(
              '${AppInfo.githubUsername}/${AppInfo.githubRepoName}',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('GitHub Source Code Repository'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _openUrl(AppInfo.githubRepoUrl),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bug_report_outlined, size: 22),
            ),
            title: const Text(
              'Issue Tracker',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Report bugs or request new features'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _openUrl(AppInfo.githubIssuesUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogList(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: AppInfo.changelog.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: entry.isLatest
                  ? scheme.primary.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: entry.isLatest
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.version,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: entry.isLatest
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (entry.isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.savings(
                            context,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Latest',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppSemanticColors.savings(context),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      entry.date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...entry.highlights.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrivacyCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: scheme.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '100% Offline & Private',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your financial data stays exclusively on your device. Built with Flutter, Dart & SQLite.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
