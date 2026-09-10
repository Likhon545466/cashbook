import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_info.dart';

class UpdateCheckResult {
  final bool hasUpdate;
  final String latestVersion;
  final int? latestBuildNumber;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? htmlUrl;
  final DateTime? publishedAt;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.latestVersion,
    this.latestBuildNumber,
    this.releaseTitle,
    this.releaseNotes,
    this.downloadUrl,
    this.htmlUrl,
    this.publishedAt,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

class AppUpdateService {
  final http.Client _client;

  static const String atomFeedUrl = 'https://github.com/Likhon545466/cashbook/releases.atom';

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Checks for the latest release via GitHub REST API with automatic rate-limit-free Atom fallback.
  Future<UpdateCheckResult> checkForUpdates({
    String apiUrl = AppInfo.githubLatestReleaseApi,
    String feedUrl = atomFeedUrl,
  }) async {
    // 1. Try GitHub REST API first
    try {
      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CashBook-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return _parseJsonResponse(response.body);
      }

      if (response.statusCode == 404) {
        // Fallback to Atom feed in case latest release endpoint isn't populated yet
        return await _fetchAtomFeed(feedUrl);
      }

      // If rate limited (403) or another status code, use Atom feed fallback
      return await _fetchAtomFeed(feedUrl);
    } catch (_) {
      // Try fallback before failing
      try {
        return await _fetchAtomFeed(feedUrl);
      } catch (e) {
        return UpdateCheckResult(
          hasUpdate: false,
          latestVersion: AppInfo.currentVersion,
          errorMessage: 'Could not connect to GitHub. Please check your internet connection.',
        );
      }
    }
  }

  UpdateCheckResult _parseJsonResponse(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final rawTag = (data['tag_name'] as String? ?? '').trim();
    final title = data['name'] as String? ?? rawTag;
    final body = data['body'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? AppInfo.githubReleasesUrl;
    final publishedAtStr = data['published_at'] as String?;
    final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    String? apkDownloadUrl;
    final assets = data['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }
    }

    final parsed = _parseVersion(rawTag);
    final hasUpdate = _isNewer(
      remoteVersion: parsed.version,
      remoteBuild: parsed.buildNumber,
      localVersion: AppInfo.currentVersion,
      localBuild: AppInfo.currentBuildNumber,
    );

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      latestVersion: parsed.version.isEmpty ? rawTag : parsed.version,
      latestBuildNumber: parsed.buildNumber,
      releaseTitle: title,
      releaseNotes: body,
      downloadUrl: apkDownloadUrl ?? htmlUrl,
      htmlUrl: htmlUrl,
      publishedAt: publishedAt,
    );
  }

  Future<UpdateCheckResult> _fetchAtomFeed(String feedUrl) async {
    final response = await _client.get(
      Uri.parse(feedUrl),
      headers: {
        'Accept': 'application/atom+xml, text/xml',
        'User-Agent': 'CashBook-App',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return _parseAtomFeed(response.body);
    }

    if (response.statusCode == 404) {
      return const UpdateCheckResult(
        hasUpdate: false,
        latestVersion: AppInfo.currentVersion,
        releaseNotes: 'You are using the latest version of CashBook.',
      );
    }

    return UpdateCheckResult(
      hasUpdate: false,
      latestVersion: AppInfo.currentVersion,
      errorMessage: 'GitHub returned status code ${response.statusCode}',
    );
  }

  UpdateCheckResult _parseAtomFeed(String xmlString) {
    final entryMatch = RegExp(r'<entry>([\s\S]*?)<\/entry>').firstMatch(xmlString);
    if (entryMatch == null) {
      return const UpdateCheckResult(
        hasUpdate: false,
        latestVersion: AppInfo.currentVersion,
        releaseNotes: 'You are using the latest version of CashBook.',
      );
    }

    final entryContent = entryMatch.group(1)!;
    final titleMatch = RegExp(r'<title>([\s\S]*?)<\/title>').firstMatch(entryContent);
    final linkMatch = RegExp(r'<link[^>]*href="([^"]+)"').firstMatch(entryContent);
    final updatedMatch = RegExp(r'<updated>([\s\S]*?)<\/updated>').firstMatch(entryContent);
    final contentMatch = RegExp(r'<content[^>]*>([\s\S]*?)<\/content>').firstMatch(entryContent);

    final title = titleMatch?.group(1)?.trim() ?? '';
    final htmlUrl = (linkMatch?.group(1) ?? AppInfo.githubReleasesUrl).replaceAll('%2B', '+');
    final updatedStr = updatedMatch?.group(1)?.trim();
    final publishedAt = updatedStr != null ? DateTime.tryParse(updatedStr) : null;

    var rawBody = contentMatch?.group(1) ?? '';
    rawBody = rawBody
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    final cleanBody = rawBody
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parsed = _parseVersion(title);
    final hasUpdate = _isNewer(
      remoteVersion: parsed.version,
      remoteBuild: parsed.buildNumber,
      localVersion: AppInfo.currentVersion,
      localBuild: AppInfo.currentBuildNumber,
    );

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      latestVersion: parsed.version.isEmpty ? title : parsed.version,
      latestBuildNumber: parsed.buildNumber,
      releaseTitle: title,
      releaseNotes: cleanBody.isEmpty ? 'Release $title on GitHub' : cleanBody,
      downloadUrl: htmlUrl,
      htmlUrl: htmlUrl,
      publishedAt: publishedAt,
    );
  }

  /// Parses version string like "v1.7.5+79" or "1.7.5" or "CashBook-v1.6.0-build64"
  static ({String version, int? buildNumber}) _parseVersion(String raw) {
    var cleaned = raw.trim();

    // Remove prefix like "CashBook-" or "Cashbook "
    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z\s_-]*'), '');

    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      return (
        version: parts[0],
        buildNumber: parts.length > 1 ? int.tryParse(parts[1]) : null,
      );
    }

    if (cleaned.contains('-build')) {
      final parts = cleaned.split('-build');
      return (
        version: parts[0],
        buildNumber: parts.length > 1 ? int.tryParse(parts[1]) : null,
      );
    }

    if (cleaned.contains('build')) {
      final parts = cleaned.split('build');
      return (
        version: parts[0].replaceAll(RegExp(r'[^0-9.]'), ''),
        buildNumber: parts.length > 1 ? int.tryParse(parts[1]) : null,
      );
    }

    return (version: cleaned, buildNumber: null);
  }

  /// Compares whether remote version is newer than local version.
  static bool _isNewer({
    required String remoteVersion,
    required int? remoteBuild,
    required String localVersion,
    required int localBuild,
  }) {
    if (remoteVersion.isEmpty) return false;

    final remoteClean = remoteVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    final localClean = localVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final remoteParts = remoteClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final localParts = localClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }
    while (localParts.length < 3) {
      localParts.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }

    if (remoteBuild != null && remoteBuild > localBuild) {
      return true;
    }

    return false;
  }
}
