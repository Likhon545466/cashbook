import 'dart:convert';
import 'dart:io';
import 'package:cashbook/core/constants/app_info.dart';
import 'package:cashbook/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Unit Tests', () {
    test('detects update available when remote version is higher via JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0+99',
            'name': 'CashBook 2.0 Major Update',
            'body': 'Exciting new features and performance improvements.',
            'html_url': 'https://github.com/Likhon545466/cashbook/releases/tag/v2.0.0',
            'published_at': '2026-10-01T12:00:00Z',
            'assets': [
              {
                'name': 'CashBook-v2.0.0-build99.apk',
                'size': 29884416, // ~28.5 MB
                'browser_download_url':
                    'https://github.com/Likhon545466/cashbook/releases/download/v2.0.0%2B99/CashBook-v2.0.0-build99.apk',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '2.0.0');
      expect(result.latestBuildNumber, 99);
      expect(result.releaseTitle, 'CashBook 2.0 Major Update');
      expect(result.downloadUrl, contains('CashBook-v2.0.0-build99.apk'));
      expect(result.apkSizeBytes, 29884416);
      expect(result.formattedApkSize, contains('MB'));
      expect(result.fullVersionString, 'v2.0.0 (Build 99)');
    });

    test('builds direct APK download URL with URL-encoded tag (+ encoded as %2B)', () {
      final directUrl = AppUpdateService.buildDirectApkDownloadUrl(
        owner: 'Likhon545466',
        repo: 'cashbook',
        version: '1.2.0',
        buildNumber: 10,
      );

      expect(
        directUrl,
        'https://github.com/Likhon545466/cashbook/releases/download/v1.2.0%2B10/CashBook-v1.2.0-build10.apk',
      );
    });

    test('builds direct APK download URL without build number', () {
      final directUrl = AppUpdateService.buildDirectApkDownloadUrl(
        owner: 'Likhon545466',
        repo: 'cashbook',
        version: 'v1.2.0',
      );

      expect(
        directUrl,
        'https://github.com/Likhon545466/cashbook/releases/download/v1.2.0/CashBook-v1.2.0.apk',
      );
    });

    test('formats byte counts accurately', () {
      expect(AppUpdateService.formatBytes(0), '0 B');
      expect(AppUpdateService.formatBytes(512), '512.0 B');
      expect(AppUpdateService.formatBytes(1024 * 500), '500.0 KB');
      expect(AppUpdateService.formatBytes(1024 * 1024 * 28), '28.0 MB');
    });

    test('falls back to Atom feed when JSON API is rate-limited (403)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('api.github.com')) {
          return http.Response('{"message": "API rate limit exceeded"}', 403);
        }

        // Atom feed response
        const atomXml = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Release notes</title>
  <entry>
    <id>tag:github.com,2008:Repository/1346423268/v2.5.0+150</id>
    <updated>2026-09-06T16:46:52Z</updated>
    <link rel="alternate" type="text/html" href="https://github.com/Likhon545466/cashbook/releases/tag/v2.5.0%2B150"/>
    <title>v2.5.0+150</title>
    <content type="html">&lt;p&gt;Google Drive sync and bug fixes.&lt;/p&gt;</content>
  </entry>
</feed>''';

        return http.Response(
          atomXml,
          200,
          headers: {'content-type': 'application/atom+xml'},
        );
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '2.5.0');
      expect(result.latestBuildNumber, 150);
      expect(result.releaseNotes, contains('Google Drive sync'));
      expect(result.downloadUrl, contains('v2.5.0%2B150/CashBook-v2.5.0-build150.apk'));
    });

    test('falls back to raw version file when API is 404 and Atom feed is unavailable', () async {
      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('api.github.com') || url.contains('.atom')) {
          return http.Response('Not Found', 404);
        }
        if (url.contains('.cashbook_version')) {
          return http.Response('2.1.0+95', 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '2.1.0');
      expect(result.latestBuildNumber, 95);
      expect(result.downloadUrl, contains('CashBook-v2.1.0-build95.apk'));
    });

    test('version comparison rules work as expected', () {
      // Newer major
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '2.0.0',
          remoteBuild: 1,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isTrue,
      );

      // Newer minor
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '1.8.0',
          remoteBuild: 83,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isTrue,
      );

      // Newer patch
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '1.7.10',
          remoteBuild: 83,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isTrue,
      );

      // Same semantic version, higher build number
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '1.7.9',
          remoteBuild: 84,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isTrue,
      );

      // Same semantic version and same build number
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '1.7.9',
          remoteBuild: 83,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isFalse,
      );

      // Older version
      expect(
        AppUpdateService.isNewer(
          remoteVersion: '1.7.0',
          remoteBuild: 70,
          localVersion: '1.7.9',
          localBuild: 83,
        ),
        isFalse,
      );
    });

    test('detects up-to-date when remote version matches or is lower', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v${AppInfo.currentVersion}+${AppInfo.currentBuildNumber}',
            'name': 'CashBook Release',
            'body': 'Current version release notes.',
            'html_url': 'https://github.com/Likhon545466/cashbook/releases',
            'assets': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, AppInfo.currentVersion);
    });

    test('handles 404 cleanly when no GitHub releases exist yet', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"message": "Not Found"}', 404);
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isFalse);
      expect(result.releaseNotes, contains('latest version'));
    });

    test('handles network error gracefully when all connections fail', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection failed');
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isFalse);
      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, contains('Could not connect'));
    });

    test('downloadApkFile streams progress and writes chunks to file', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final bytes = List.generate(1024 * 50, (i) => i % 256);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final saveFile = File('test_download_tmp.apk');
      if (await saveFile.exists()) await saveFile.delete();

      final progressEvents = await service
          .downloadApkFile(
            url: 'https://example.com/test.apk',
            savePath: saveFile.path,
            client: mockClient,
          )
          .toList();

      expect(progressEvents.isNotEmpty, isTrue);
      final last = progressEvents.last;
      expect(last.isCompleted, isTrue);
      expect(last.progress, 1.0);
      expect(last.receivedBytes, 1024 * 50);
      expect(last.percentage, 100);
      expect(last.formattedTotal, '50.0 KB');

      if (await saveFile.exists()) await saveFile.delete();
    });

    test('downloadApkFile reports failure on non-200 HTTP status', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value([]),
          404,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final saveFile = File('test_download_404.apk');
      final progressEvents = await service
          .downloadApkFile(
            url: 'https://example.com/missing.apk',
            savePath: saveFile.path,
            client: mockClient,
          )
          .toList();

      expect(progressEvents.length, 1);
      expect(progressEvents.first.isFailed, isTrue);
      expect(progressEvents.first.errorMessage, contains('404'));

      if (await saveFile.exists()) await saveFile.delete();
    });
  });
}
