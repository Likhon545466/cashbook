import 'dart:convert';
import 'package:cashbook/core/constants/app_info.dart';
import 'package:cashbook/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
                'browser_download_url': 'https://github.com/Likhon545466/cashbook/releases/download/v2.0.0/CashBook-v2.0.0-build99.apk',
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
    <id>tag:github.com,2008:Repository/1346423268/v1.7.3+77</id>
    <updated>2026-09-06T16:46:52Z</updated>
    <link rel="alternate" type="text/html" href="https://github.com/Likhon545466/cashbook/releases/tag/v1.7.3%2B77"/>
    <title>v1.7.3+77</title>
    <content type="html">&lt;p&gt;Google Drive sync and bug fixes.&lt;/p&gt;</content>
  </entry>
</feed>''';

        return http.Response(atomXml, 200, headers: {'content-type': 'application/atom+xml'});
      });

      final service = AppUpdateService(client: mockClient);
      final result = await service.checkForUpdates();

      expect(result.isSuccess, isTrue);
      expect(result.latestVersion, '1.7.3');
      expect(result.latestBuildNumber, 77);
      expect(result.releaseNotes, contains('Google Drive sync'));
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
  });
}
