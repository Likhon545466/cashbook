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
  static const String currentVersion = '1.7.5';
  static const int currentBuildNumber = 79;
  static const String fullVersion = 'v$currentVersion (Build $currentBuildNumber)';

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
      version: 'v1.7.5',
      title: 'Time Display & About Hub',
      date: 'September 2026',
      isLatest: true,
      highlights: [
        'Added time display alongside dates in the Home activity feed and Transactions list.',
        'Interactive Home feed: tap any transaction to view details, edit, duplicate, or delete.',
        'Dedicated About & Updates screen with GitHub profile, version history, and live release checker.',
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
