import 'package:package_info_plus/package_info_plus.dart';

class ChangelogEntry {
  final String version;
  final String title;
  final String date;
  final bool isLatest;
  final List<String> highlights;

  const ChangelogEntry({
    required this.version,
    required this.title,
    required this.date,
    this.isLatest = false,
    required this.highlights,
  });
}

class AppInfo {
  static const String appName = 'CashBook';
  static const String appTagline = 'Fast, offline-first personal finance management';

  // Dynamic version state initialized from PackageInfo
  static String _version = '1.8.9';
  static int _buildNumber = 93;
  static bool _initialized = false;

  static String get currentVersion => _version;
  static int get currentBuildNumber => _buildNumber;
  static String get fullVersion => 'v$_version (Build $_buildNumber)';

  /// Reads version and build number directly from native platform / APK manifest.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty && info.version != '0.0.0') {
        _version = info.version;
      }
      final build = int.tryParse(info.buildNumber);
      if (build != null && build > 0) {
        _buildNumber = build;
      }
      _initialized = true;
    } catch (_) {}
  }

  // Developer & Repository Info
  static const String developerName = 'Likhon';
  static const String githubUsername = 'Likhon545466';
  static const String githubRepoName = 'cashbook';
  static const String githubUserUrl = 'https://github.com/Likhon545466';
  static const String githubRepoUrl = 'https://github.com/Likhon545466/cashbook';
  static const String githubReleasesUrl = 'https://github.com/Likhon545466/cashbook/releases';
  static const String githubLatestReleaseApi = 'https://api.github.com/repos/Likhon545466/cashbook/releases/latest';
  static const String githubIssuesUrl = 'https://github.com/Likhon545466/cashbook/issues';

  // Changelog History
  static const List<ChangelogEntry> changelog = [
    ChangelogEntry(
      version: 'v1.8.9',
      title: 'Full Build 86 Parity & Bundled Keystore for GitHub CI/CD',
      date: 'September 2026',
      isLatest: true,
      highlights: [
        'Restored exact Build 86 Google Auth logic and configuration.',
        'Bundled Build 86 release keystore directly into CI/CD pipeline to eliminate signature divergence on GitHub builds.',
        'Guaranteed identical SHA-1 fingerprint on local builds and GitHub Actions releases.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.8',
      title: 'Google OAuth Web Client Fix & Cloud Sync',
      date: 'September 2026',
      highlights: [
        'Configured Google Cloud OAuth 2.0 Web Application Client ID for seamless Google Sign-In.',
        'Added automated legacy Client ID migration in CloudSyncProvider.',
        'Verified Google Drive AppData backup and restore with full test coverage.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.7',
      title: 'Restored Build 86 Signing & Verified Google Drive Sync',
      date: 'September 2026',
      highlights: [
        'Restored original build signing configuration exactly matching Build 86.',
        'Seamless Google Sign-In and Google Drive AppData synchronization.',
        'Retained direct native Android FileProvider package installer.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.6',
      title: 'Google Sign-In & Native Installer Production Release',
      date: 'September 2026',
      highlights: [
        'Aligned release signing keystore with Google Cloud OAuth 2.0 Client credentials.',
        'Verified Google Sign-In and Google Drive Cloud Sync authentication flow.',
        'Native FileProvider package installer integration for instant 1-tap in-place updates.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.5',
      title: 'Google OAuth Certificate Alignment & Release Key',
      date: 'September 2026',
      highlights: [
        'Aligned signing certificate SHA-1 fingerprint with Google Cloud Console OAuth client credentials.',
        'Restored Google Sign-In and Google Drive Cloud Sync functionality on release builds.',
        'Maintained native direct Android package installer and update integrity.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.4',
      title: 'Native Android Installer & Unified Release Keystore',
      date: 'September 2026',
      highlights: [
        'Integrated native Android FileProvider + MethodChannel to prompt direct system package installer on completion.',
        'Unified release signing keystore to resolve Android package signature conflict during in-place app updates.',
        'Added REQUEST_INSTALL_PACKAGES permission in AndroidManifest.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.3',
      title: 'Update Link Optimization & Retry Support',
      date: 'September 2026',
      highlights: [
        'Optimized direct APK download URL encoding and tag matching.',
        'Added 1-tap retry download action and friendly 404 recovery state.',
        'Enhanced release packaging and build automation.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.2',
      title: 'In-App Downloads, Update Frequency & CI/CD',
      date: 'September 2026',
      highlights: [
        'Live streaming APK download progress bar with speed (MB/s) and percentage.',
        'Direct native APK installer prompt on download completion.',
        'Configurable background update check frequency (Startup, Daily, Weekly, Manual) in Settings.',
        'Automated GitHub Actions CI/CD release workflow on tag push.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.1',
      title: 'OTA Update Verification & Fixes',
      date: 'September 2026',
      highlights: [
        'Enhanced in-app update checker verification against live GitHub releases.',
        'Refined direct APK download link handling and notification triggers.',
        'Optimized build pipeline and release version packaging.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.8.0',
      title: 'In-App GitHub Release Update System',
      date: 'September 2026',
      highlights: [
        'Automatic startup update checker with glassmorphic dialog notification.',
        'Interactive in-app update checker modal in Settings with animated radar scanner.',
        'Resilient two-tier fallback: GitHub REST API + Atom feed & raw repo rate-limit bypass.',
        'Direct 1-tap APK downloads with URL-encoded release tag links.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.7.9',
      title: 'About Hub & Versioning Updates',
      date: 'September 2026',
      highlights: [
        'Integrated dynamic PackageInfo version resolution for accurate GitHub update checks.',
        'Refined About & Updates hub with rate-limit resilient Atom feed fallback.',
        'General performance improvements and code cleanup.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.7.8',
      title: 'Time Display & About Hub',
      date: 'September 2026',
      highlights: [
        'Added time display alongside dates in the Home activity feed and Transactions list.',
        'Interactive Home feed: tap any transaction to view details, edit, duplicate, or delete.',
        'Dedicated About & Updates screen with GitHub profile, version history, and live release checker.',
        'Rate-limit resilient update checker with automatic GitHub Atom feed fallback.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.7.4',
      title: 'Time Selection & Dedicated Rows',
      date: 'September 2026',
      highlights: [
        'Native 12-hour AM/PM time picker integrated into transaction creation & editing.',
        'Dedicated Date and Time display rows in Cash and Savings detail sheets.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.7.0',
      title: 'Google Drive Cloud Sync & Security',
      date: 'September 2026',
      highlights: [
        'Automatic Google Drive cloud backup and cross-device restore.',
        'End-to-end AES-256 backup encryption with password protection.',
        'Data integrity diagnostics, conflict resolution, and automatic database health repairs.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.6.0',
      title: 'Complete Debt & Loan Management',
      date: 'August 2026',
      highlights: [
        'Track money you owe vs. money owed to you with borrower/lender contacts.',
        'Partial payment recording, due date extension history, and status badges (Open, Overdue, Paid).',
      ],
    ),
    ChangelogEntry(
      version: 'v1.5.0',
      title: 'Savings & Reserve Fund Vault',
      date: 'August 2026',
      highlights: [
        'Dedicated savings transfers and balance isolation from daily operating cash.',
        'Deposit and withdrawal history with notes and instant metrics.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.4.0',
      title: 'Monthly Budgets & Visual Analytics',
      date: 'August 2026',
      highlights: [
        'Category-level spending limits with progress indicators and threshold warnings.',
        'Interactive monthly cashflow bar charts and spending category donut charts.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.3.0',
      title: 'Recurring Transactions & Statements',
      date: 'July 2026',
      highlights: [
        'Automate recurring income and expenses (daily, weekly, monthly, yearly).',
        'Export statement reports in both CSV and formatted PDF formats.',
      ],
    ),
    ChangelogEntry(
      version: 'v1.0.0',
      title: 'Initial Release',
      date: 'July 2026',
      highlights: [
        'Offline-first SQLite ledger with lightning fast Cash In & Cash Out recording.',
        'Custom books and monthly partitioning for organized tracking.',
        'Biometric fingerprint, face, PIN, and pattern app security lock.',
      ],
    ),
  ];
}
