import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_info.dart';

/// Progress state of an ongoing in-app APK download.
class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final double speedBytesPerSec;
  final bool isCompleted;
  final bool isFailed;
  final String? errorMessage;
  final String? filePath;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    this.speedBytesPerSec = 0,
    this.isCompleted = false,
    this.isFailed = false,
    this.errorMessage,
    this.filePath,
  });

  String get formattedReceived => AppUpdateService.formatBytes(receivedBytes);
  String get formattedTotal => AppUpdateService.formatBytes(totalBytes);
  String get formattedSpeed =>
      '${AppUpdateService.formatBytes(speedBytesPerSec.toInt())}/s';
  int get percentage => (progress * 100).toInt();
}

/// Result of checking for app updates on GitHub.
class UpdateCheckResult {
  final bool hasUpdate;
  final String latestVersion;
  final int? latestBuildNumber;
  final String? releaseTag;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? htmlUrl;
  final int? apkSizeBytes;
  final DateTime? publishedAt;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.latestVersion,
    this.latestBuildNumber,
    this.releaseTag,
    this.releaseTitle,
    this.releaseNotes,
    this.downloadUrl,
    this.htmlUrl,
    this.apkSizeBytes,
    this.publishedAt,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;

  String? get formattedApkSize =>
      apkSizeBytes != null ? AppUpdateService.formatBytes(apkSizeBytes!) : null;

  String get fullVersionString => latestBuildNumber != null
      ? 'v$latestVersion (Build $latestBuildNumber)'
      : 'v$latestVersion';
}

/// Service to check for releases on GitHub with a multi-tier fallback mechanism.
class AppUpdateService {
  final http.Client _client;
  final String owner;
  final String repo;
  final String defaultBranch;

  static const String defaultOwner = AppInfo.githubUsername;
  static const String defaultRepo = AppInfo.githubRepoName;
  static const String defaultBranchName = 'main';

  AppUpdateService({
    http.Client? client,
    this.owner = defaultOwner,
    this.repo = defaultRepo,
    this.defaultBranch = defaultBranchName,
  }) : _client = client ?? http.Client();

  String get apiUrl => 'https://api.github.com/repos/$owner/$repo/releases/latest';
  String get atomFeedUrl => 'https://github.com/$owner/$repo/releases.atom';
  String get rawVersionUrl =>
      'https://raw.githubusercontent.com/$owner/$repo/$defaultBranch/.cashbook_version';
  String get rawPubspecUrl =>
      'https://raw.githubusercontent.com/$owner/$repo/$defaultBranch/pubspec.yaml';
  String get releasesPageUrl => 'https://github.com/$owner/$repo/releases';

  /// Format raw byte count into human-readable size (e.g. "28.5 MB").
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Constructs direct APK download URL with URL-encoded tags (e.g. replacing '+' with '%2B').
  static String buildDirectApkDownloadUrl({
    required String owner,
    required String repo,
    required String version,
    int? buildNumber,
  }) {
    final cleanVersion = version.startsWith('v') || version.startsWith('V')
        ? version.substring(1)
        : version;

    if (buildNumber != null && buildNumber > 0) {
      final rawTag = 'v$cleanVersion+$buildNumber';
      final encodedTag = Uri.encodeComponent(rawTag);
      final apkFileName = 'CashBook-v$cleanVersion-build$buildNumber.apk';
      return 'https://github.com/$owner/$repo/releases/download/$encodedTag/$apkFileName';
    } else {
      final rawTag = 'v$cleanVersion';
      final encodedTag = Uri.encodeComponent(rawTag);
      final apkFileName = 'CashBook-v$cleanVersion.apk';
      return 'https://github.com/$owner/$repo/releases/download/$encodedTag/$apkFileName';
    }
  }

  /// Builds a release tag web URL (e.g., https://github.com/owner/repo/releases/tag/v1.7.9%2B83).
  static String buildReleasePageUrl({
    required String owner,
    required String repo,
    String? tag,
  }) {
    if (tag != null && tag.isNotEmpty) {
      final encodedTag = Uri.encodeComponent(tag);
      return 'https://github.com/$owner/$repo/releases/tag/$encodedTag';
    }
    return 'https://github.com/$owner/$repo/releases';
  }

  /// Downloads an APK from [url] with live streaming progress reporting.
  /// If [savePath] is omitted, defaults to a file in the temporary directory.
  Stream<DownloadProgress> downloadApkFile({
    required String url,
    String? savePath,
    http.Client? client,
  }) async* {
    final httpClient = client ?? _client;
    IOSink? sink;
    File? outputFile;

    try {
      String targetPath;
      if (savePath != null) {
        targetPath = savePath;
      } else {
        Directory tempDir;
        try {
          tempDir = await getTemporaryDirectory().timeout(
            const Duration(milliseconds: 200),
          );
        } catch (_) {
          tempDir = Directory.systemTemp;
        }
        final rawFileName = url.split('/').last.split('?').first;
        final sanitizedName = rawFileName.isNotEmpty && rawFileName.endsWith('.apk')
            ? rawFileName
            : 'cashbook-update.apk';
        targetPath = '${tempDir.path}${Platform.pathSeparator}$sanitizedName';
      }

      final request = http.Request('GET', Uri.parse(url));
      final response = await httpClient.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield DownloadProgress(
          receivedBytes: 0,
          totalBytes: 0,
          progress: 0,
          isFailed: true,
          errorMessage: 'Server responded with HTTP ${response.statusCode}',
        );
        return;
      }

      outputFile = File(targetPath);
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (_) {}
      }
      await outputFile.create(recursive: true);
      sink = outputFile.openWrite();

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      var lastTime = DateTime.now();
      var bytesSinceLastTime = 0;
      double currentSpeed = 0;

      // Yield initial 0% progress
      yield DownloadProgress(
        receivedBytes: 0,
        totalBytes: totalBytes,
        progress: 0,
        speedBytesPerSec: 0,
        filePath: targetPath,
      );

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        bytesSinceLastTime += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastTime).inMilliseconds;
        if (elapsedMs >= 150) {
          currentSpeed = (bytesSinceLastTime / (elapsedMs / 1000.0));
          lastTime = now;
          bytesSinceLastTime = 0;

          final progress =
              totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: progress,
            speedBytesPerSec: currentSpeed,
            filePath: targetPath,
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      yield DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
        progress: 1.0,
        speedBytesPerSec: currentSpeed,
        isCompleted: true,
        filePath: targetPath,
      );
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      yield DownloadProgress(
        receivedBytes: 0,
        totalBytes: 0,
        progress: 0,
        isFailed: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Attempts to launch installation of the downloaded APK file.
  static Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks for the latest release via GitHub REST API with automatic rate-limit-free fallbacks.
  Future<UpdateCheckResult> checkForUpdates({
    String? customApiUrl,
    String? customFeedUrl,
    String? customRawVersionUrl,
  }) async {
    final targetApiUrl = customApiUrl ?? apiUrl;
    final targetFeedUrl = customFeedUrl ?? atomFeedUrl;
    final targetRawVersionUrl = customRawVersionUrl ?? rawVersionUrl;

    // 1. Try GitHub REST API first
    try {
      final response = await _client.get(
        Uri.parse(targetApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CashBook-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return _parseJsonResponse(response.body);
      }

      if (response.statusCode == 404) {
        // Fallback to Atom feed / raw repo in case latest release endpoint isn't populated
        final fallback = await _fallbackCheck(targetFeedUrl, targetRawVersionUrl);
        if (fallback.isSuccess) {
          return fallback;
        }
        return UpdateCheckResult(
          hasUpdate: false,
          latestVersion: AppInfo.currentVersion,
          latestBuildNumber: AppInfo.currentBuildNumber,
          releaseNotes: 'You are using the latest version of CashBook.',
        );
      }

      // If rate-limited (403) or server error, use fallback
      return await _fallbackCheck(targetFeedUrl, targetRawVersionUrl);
    } catch (_) {
      // Network or parsing error on REST API -> Try fallback
      return await _fallbackCheck(targetFeedUrl, targetRawVersionUrl);
    }
  }

  /// Tier 2 Fallback: Atom feed -> Raw version file
  Future<UpdateCheckResult> _fallbackCheck(
    String feedUrl,
    String rawVersionUrl,
  ) async {
    // 1. Try Atom feed
    try {
      final atomResult = await _fetchAtomFeed(feedUrl);
      if (atomResult.isSuccess) {
        return atomResult;
      }
    } catch (_) {}

    // 2. Try Raw Version file (.cashbook_version / pubspec.yaml)
    try {
      final rawResult = await _fetchRawVersionFile(rawVersionUrl);
      if (rawResult.isSuccess) {
        return rawResult;
      }
    } catch (_) {}

    // If both failed due to connection error or non-200
    return UpdateCheckResult(
      hasUpdate: false,
      latestVersion: AppInfo.currentVersion,
      latestBuildNumber: AppInfo.currentBuildNumber,
      errorMessage:
          'Could not connect to GitHub. Please check your internet connection.',
    );
  }

  UpdateCheckResult _parseJsonResponse(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final rawTag = (data['tag_name'] as String? ?? '').trim();
    final title = data['name'] as String? ?? rawTag;
    final body = data['body'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? releasesPageUrl;
    final publishedAtStr = data['published_at'] as String?;
    final publishedAt =
        publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    String? apkDownloadUrl;
    int? apkSizeBytes;

    final assets = data['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkDownloadUrl = asset['browser_download_url'] as String?;
            apkSizeBytes = asset['size'] as int?;
            break;
          }
        }
      }
    }

    final parsed = parseVersion(rawTag);

    // If no direct asset url is present, construct it accurately
    final finalDownloadUrl = apkDownloadUrl ??
        buildDirectApkDownloadUrl(
          owner: owner,
          repo: repo,
          version: parsed.version.isNotEmpty ? parsed.version : rawTag,
          buildNumber: parsed.buildNumber,
        );

    final hasUpdate = isNewer(
      remoteVersion: parsed.version,
      remoteBuild: parsed.buildNumber,
      localVersion: AppInfo.currentVersion,
      localBuild: AppInfo.currentBuildNumber,
    );

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      latestVersion: parsed.version.isEmpty ? rawTag : parsed.version,
      latestBuildNumber: parsed.buildNumber,
      releaseTag: rawTag,
      releaseTitle: title.isNotEmpty ? title : 'CashBook Release',
      releaseNotes: body,
      downloadUrl: finalDownloadUrl,
      htmlUrl: htmlUrl,
      apkSizeBytes: apkSizeBytes,
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

    return UpdateCheckResult(
      hasUpdate: false,
      latestVersion: AppInfo.currentVersion,
      latestBuildNumber: AppInfo.currentBuildNumber,
      errorMessage: 'Atom feed returned status code ${response.statusCode}',
    );
  }

  UpdateCheckResult _parseAtomFeed(String xmlString) {
    final entryMatch =
        RegExp(r'<entry>([\s\S]*?)<\/entry>').firstMatch(xmlString);
    if (entryMatch == null) {
      return UpdateCheckResult(
        hasUpdate: false,
        latestVersion: AppInfo.currentVersion,
        latestBuildNumber: AppInfo.currentBuildNumber,
        releaseNotes: 'You are using the latest version of CashBook.',
      );
    }

    final entryContent = entryMatch.group(1)!;
    final titleMatch =
        RegExp(r'<title>([\s\S]*?)<\/title>').firstMatch(entryContent);
    final linkMatch =
        RegExp(r'<link[^>]*href="([^"]+)"').firstMatch(entryContent);
    final updatedMatch =
        RegExp(r'<updated>([\s\S]*?)<\/updated>').firstMatch(entryContent);
    final contentMatch =
        RegExp(r'<content[^>]*>([\s\S]*?)<\/content>').firstMatch(entryContent);

    final title = titleMatch?.group(1)?.trim() ?? '';
    final htmlUrl =
        (linkMatch?.group(1) ?? releasesPageUrl).replaceAll('%2B', '+');
    final updatedStr = updatedMatch?.group(1)?.trim();
    final publishedAt =
        updatedStr != null ? DateTime.tryParse(updatedStr) : null;

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

    final parsed = parseVersion(title);
    final hasUpdate = isNewer(
      remoteVersion: parsed.version,
      remoteBuild: parsed.buildNumber,
      localVersion: AppInfo.currentVersion,
      localBuild: AppInfo.currentBuildNumber,
    );

    final directDownloadUrl = buildDirectApkDownloadUrl(
      owner: owner,
      repo: repo,
      version: parsed.version.isNotEmpty ? parsed.version : title,
      buildNumber: parsed.buildNumber,
    );

    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      latestVersion: parsed.version.isEmpty ? title : parsed.version,
      latestBuildNumber: parsed.buildNumber,
      releaseTag: title,
      releaseTitle: title,
      releaseNotes: cleanBody.isEmpty ? 'Release $title on GitHub' : cleanBody,
      downloadUrl: directDownloadUrl,
      htmlUrl: htmlUrl,
      publishedAt: publishedAt,
    );
  }

  Future<UpdateCheckResult> _fetchRawVersionFile(String rawUrl) async {
    final response = await _client.get(
      Uri.parse(rawUrl),
      headers: {
        'Accept': 'text/plain, application/json',
        'User-Agent': 'CashBook-App',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final raw = response.body.trim();
      final parsed = parseVersion(raw);

      final hasUpdate = isNewer(
        remoteVersion: parsed.version,
        remoteBuild: parsed.buildNumber,
        localVersion: AppInfo.currentVersion,
        localBuild: AppInfo.currentBuildNumber,
      );

      final directDownloadUrl = buildDirectApkDownloadUrl(
        owner: owner,
        repo: repo,
        version: parsed.version,
        buildNumber: parsed.buildNumber,
      );

      final releaseUrl = buildReleasePageUrl(
        owner: owner,
        repo: repo,
        tag: parsed.buildNumber != null
            ? 'v${parsed.version}+${parsed.buildNumber}'
            : 'v${parsed.version}',
      );

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        latestVersion: parsed.version,
        latestBuildNumber: parsed.buildNumber,
        releaseTag: 'v$raw',
        releaseTitle: 'CashBook v$raw',
        releaseNotes: 'New version available on GitHub.',
        downloadUrl: directDownloadUrl,
        htmlUrl: releaseUrl,
      );
    }

    return UpdateCheckResult(
      hasUpdate: false,
      latestVersion: AppInfo.currentVersion,
      latestBuildNumber: AppInfo.currentBuildNumber,
      errorMessage:
          'Could not retrieve version metadata from GitHub (status ${response.statusCode}).',
    );
  }

  /// Parses version string like "v1.7.9+83", "1.7.9+83", "CashBook-v1.7.9-build83.apk"
  static ({String version, int? buildNumber}) parseVersion(String raw) {
    var cleaned = raw.trim();

    // If the input is a full line or yaml like "version: 1.7.9+83"
    if (cleaned.contains('version:')) {
      final idx = cleaned.indexOf('version:');
      cleaned = cleaned.substring(idx + 8).trim();
      if (cleaned.contains('\n')) {
        cleaned = cleaned.split('\n').first.trim();
      }
    }

    // Strip leading package names or prefixes like "CashBook-", "cashbook_", "v", "V"
    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z\s_-]*'), '');

    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.endsWith('.apk')) {
      cleaned = cleaned.substring(0, cleaned.length - 4);
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
  static bool isNewer({
    required String remoteVersion,
    required int? remoteBuild,
    required String localVersion,
    required int localBuild,
  }) {
    if (remoteVersion.isEmpty) return false;

    final remoteClean = remoteVersion.replaceAll(RegExp(r'[^0-9.]'), '');
    final localClean = localVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    final remoteParts =
        remoteClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final localParts =
        localClean.split('.').map((s) => int.tryParse(s) ?? 0).toList();

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

    // Semantic versions are identical (e.g. 1.7.9 == 1.7.9) -> compare build numbers
    if (remoteBuild != null && remoteBuild > localBuild) {
      return true;
    }

    return false;
  }
}
