import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_info.dart';
import '../core/theme/app_colors.dart';
import '../services/app_update_service.dart';

class UpdatePopupDialog extends StatefulWidget {
  final UpdateCheckResult result;
  final AppUpdateService? updateService;

  const UpdatePopupDialog({
    super.key,
    required this.result,
    this.updateService,
  });

  /// Displays the update dialog as a glassmorphic modal popup.
  static Future<void> show(
    BuildContext context,
    UpdateCheckResult result, {
    AppUpdateService? updateService,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => UpdatePopupDialog(
        result: result,
        updateService: updateService,
      ),
    );
  }

  @override
  State<UpdatePopupDialog> createState() => _UpdatePopupDialogState();
}

class _UpdatePopupDialogState extends State<UpdatePopupDialog> {
  late final AppUpdateService _service;
  StreamSubscription<DownloadProgress>? _downloadSub;
  DownloadProgress? _progress;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  void _startInAppDownload(String downloadUrl) {
    HapticFeedback.selectionClick();
    setState(() {
      _isDownloading = true;
      _progress = const DownloadProgress(
        receivedBytes: 0,
        totalBytes: 0,
        progress: 0,
      );
    });

    _downloadSub?.cancel();
    _downloadSub = _service.downloadApkFile(url: downloadUrl).listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          if (progress.isCompleted) {
            _isDownloading = false;
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _progress = DownloadProgress(
            receivedBytes: 0,
            totalBytes: 0,
            progress: 0,
            isFailed: true,
            errorMessage: err.toString(),
          );
        });
      },
    );
  }

  void _cancelDownload() {
    HapticFeedback.selectionClick();
    _downloadSub?.cancel();
    setState(() {
      _isDownloading = false;
      _progress = null;
    });
  }

  Future<void> _installApk(String filePath) async {
    await HapticFeedback.selectionClick();
    final success = await AppUpdateService.installApk(filePath);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not trigger package installer. Opening browser download...'),
        ),
      );
      final downloadUrl = widget.result.downloadUrl ?? AppInfo.githubReleasesUrl;
      _openUrl(downloadUrl);
    }
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
    final result = widget.result;

    final formattedDate = result.publishedAt != null
        ? DateFormat('MMM d, yyyy').format(result.publishedAt!)
        : 'Latest Release';

    final apkSize = result.formattedApkSize;
    final downloadUrl = result.downloadUrl ?? AppInfo.githubReleasesUrl;
    final releaseUrl = result.htmlUrl ?? AppInfo.githubReleasesUrl;

    final isCompleted = _progress?.isCompleted == true;
    final isFailed = _progress?.isFailed == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141A18).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with Rocket / Update Icon
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                          ],
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
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : _isDownloading
                                ? Icons.downloading_rounded
                                : Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title & Subtitle
                  Text(
                    isCompleted
                        ? 'Download Complete!'
                        : _isDownloading
                            ? 'Downloading Update...'
                            : 'Update Available!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted
                        ? 'Ready to install CashBook update.'
                        : _isDownloading
                            ? 'Please keep the app open during download.'
                            : 'A new version of CashBook is ready for you.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFF96A19D)
                          : const Color(0xFF6F7774),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Version Comparison Pill Container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Current version
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Installed',
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
                                'v${AppInfo.currentVersion}+${AppInfo.currentBuildNumber}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        // New version
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata chips (Size & Date)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (apkSize != null) ...[
                        _MetadataChip(
                          icon: Icons.file_present_rounded,
                          label: apkSize,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _MetadataChip(
                        icon: Icons.calendar_today_rounded,
                        label: formattedDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // In-App Download Progress Card
                  if (_isDownloading || isCompleted || isFailed) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFailed
                              ? scheme.error.withValues(alpha: 0.5)
                              : isCompleted
                                  ? AppSemanticColors.savings(context).withValues(alpha: 0.5)
                                  : scheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCompleted
                                    ? 'Downloaded APK'
                                    : isFailed
                                        ? 'Download Failed'
                                        : 'Downloading...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_progress != null && !_progress!.isFailed)
                                Text(
                                  '${_progress!.percentage}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: isCompleted
                                  ? 1.0
                                  : isFailed
                                      ? 0.0
                                      : _progress?.progress ?? 0.0,
                              minHeight: 8,
                              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted
                                    ? AppSemanticColors.savings(context)
                                    : isFailed
                                        ? scheme.error
                                        : scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_progress != null && !isFailed && !isCompleted)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_progress!.formattedReceived} / ${_progress!.formattedTotal}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? const Color(0xFF96A19D)
                                        : const Color(0xFF6F7774),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _progress!.formattedSpeed,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          if (isFailed)
                            Text(
                              _progress?.errorMessage ?? 'An error occurred during download.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Release notes box (shown when not actively downloading)
                  if (!_isDownloading &&
                      result.releaseNotes != null &&
                      result.releaseNotes!.trim().isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else if (!_isDownloading) ...[
                    const SizedBox(height: 8),
                  ],

                  // Dynamic Action Buttons
                  if (isCompleted && _progress?.filePath != null) ...[
                    FilledButton.icon(
                      onPressed: () => _installApk(_progress!.filePath!),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppSemanticColors.savings(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.install_mobile_rounded, size: 20),
                      label: const Text(
                        'Install Update',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_isDownloading) ...[
                    OutlinedButton.icon(
                      onPressed: _cancelDownload,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: Icon(Icons.cancel_outlined, size: 18, color: scheme.error),
                      label: Text(
                        'Cancel Download',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: () => _startInAppDownload(downloadUrl),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download APK',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

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
                            side: BorderSide(
                              color: scheme.outlineVariant.withValues(alpha: 0.5),
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
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF96A19D)
                                : const Color(0xFF6F7774),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF96A19D) : const Color(0xFF6F7774),
            ),
          ),
        ],
      ),
    );
  }
}

