import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_info.dart';
import '../core/theme/app_colors.dart';
import '../services/app_update_service.dart';

class UpdateCheckerModal extends StatefulWidget {
  final AppUpdateService? updateService;

  const UpdateCheckerModal({
    super.key,
    this.updateService,
  });

  /// Displays the interactive update checker modal sheet.
  static Future<void> show(
    BuildContext context, {
    AppUpdateService? updateService,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateCheckerModal(updateService: updateService),
    );
  }

  @override
  State<UpdateCheckerModal> createState() => _UpdateCheckerModalState();
}

class _UpdateCheckerModalState extends State<UpdateCheckerModal> {
  late final AppUpdateService _service;

  bool _isChecking = true;
  UpdateCheckResult? _result;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
    _runCheck();
  }

  Future<void> _runCheck() async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _result = null;
    });

    final res = await _service.checkForUpdates();

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _result = res;
      _checkedAt = DateTime.now();
    });
  }

  Future<void> _openUrl(String url) async {
    await HapticFeedback.selectionClick();
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141917) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Dynamic Body based on state
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStateContent(theme, scheme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme, ColorScheme scheme, bool isDark) {
    if (_isChecking) {
      return _buildCheckingView(theme, scheme, isDark);
    }

    final result = _result;
    if (result == null || !result.isSuccess) {
      return _buildErrorView(theme, scheme, isDark, result?.errorMessage);
    }

    if (result.hasUpdate) {
      return _buildUpdateAvailableView(theme, scheme, isDark, result);
    }

    return _buildUpToDateView(theme, scheme, isDark);
  }

  // 1. Loading / Radar Animation View
  Widget _buildCheckingView(ThemeData theme, ColorScheme scheme, bool isDark) {
    return Padding(
      key: const ValueKey('checking_view'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          _RadarAnimationWidget(color: scheme.primary),
          const SizedBox(height: 20),
          const Text(
            'Checking GitHub for Updates...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Querying GitHub releases and repository fallbacks',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // 2. Up to Date View
  Widget _buildUpToDateView(ThemeData theme, ColorScheme scheme, bool isDark) {
    return Column(
      key: const ValueKey('uptodate_view'),
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppSemanticColors.income(context).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppSemanticColors.income(context),
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'You\'re Up to Date!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _checkedAt != null
              ? 'Checked at ${DateFormat('hh:mm a').format(_checkedAt!)} • Latest build of CashBook'
              : 'You are running the latest build of CashBook.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installed Version',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF96A19D)
                          : const Color(0xFF6F7774),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${AppInfo.currentVersion} (Build ${AppInfo.currentBuildNumber})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.income(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Latest',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppSemanticColors.income(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openUrl(AppInfo.githubReleasesUrl),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'View on GitHub',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Check Again',
              onPressed: _runCheck,
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Update Available View
  Widget _buildUpdateAvailableView(
    ThemeData theme,
    ColorScheme scheme,
    bool isDark,
    UpdateCheckResult result,
  ) {
    final apkSize = result.formattedApkSize;
    final formattedDate = result.publishedAt != null
        ? DateFormat('MMM d, yyyy').format(result.publishedAt!)
        : 'Latest Release';

    final downloadUrl = result.downloadUrl ?? AppInfo.githubReleasesUrl;
    final releaseUrl = result.htmlUrl ?? AppInfo.githubReleasesUrl;

    return Column(
      key: const ValueKey('update_available_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Update Available!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A newer release of CashBook is available on GitHub.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
          ),
        ),
        const SizedBox(height: 14),

        // Comparison Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  children: [
                    Text(
                      'Installed',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF96A19D)
                            : const Color(0xFF6F7774),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${AppInfo.currentVersion}+${AppInfo.currentBuildNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              Flexible(
                child: Column(
                  children: [
                    Text(
                      'New Version',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppSemanticColors.savings(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.savings(context)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.latestBuildNumber != null
                            ? 'v${result.latestVersion}+${result.latestBuildNumber}'
                            : 'v${result.latestVersion}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppSemanticColors.savings(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (apkSize != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_present_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      apkSize,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Release Notes
        if (result.releaseNotes != null &&
            result.releaseNotes!.trim().isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.releaseTitle != null &&
                      result.releaseTitle!.isNotEmpty) ...[
                    Text(
                      result.releaseTitle!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    result.releaseNotes!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Buttons
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            _openUrl(downloadUrl);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text(
            'Download APK',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openUrl(releaseUrl);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text(
                  'GitHub Release',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Error View
  Widget _buildErrorView(
    ThemeData theme,
    ColorScheme scheme,
    bool isDark,
    String? error,
  ) {
    return Column(
      key: const ValueKey('error_view'),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_off_rounded,
            color: scheme.error,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Update Check Failed',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            error ?? 'Could not connect to GitHub. Please check your internet connection.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _runCheck,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Retry Check',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _openUrl(AppInfo.githubReleasesUrl),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Open Releases'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadarAnimationWidget extends StatefulWidget {
  final Color color;

  const _RadarAnimationWidget({required this.color});

  @override
  State<_RadarAnimationWidget> createState() => _RadarAnimationWidgetState();
}

class _RadarAnimationWidgetState extends State<_RadarAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPulsePainter(
              progress: _controller.value,
              color: widget.color,
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom radar pulse animator
class _RadarPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPulsePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    for (var i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress).clamp(0.0, 0.6);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
