import 'dart:convert';
import 'package:cashbook/core/constants/app_info.dart';
import 'package:cashbook/services/app_update_service.dart';
import 'package:cashbook/widgets/update_checker_modal.dart';
import 'package:cashbook/widgets/update_popup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Update Dialog & Modal Widget Tests', () {
    testWidgets('UpdatePopupDialog renders all metadata and actions', (
      tester,
    ) async {
      final updateResult = UpdateCheckResult(
        hasUpdate: true,
        latestVersion: '2.0.0',
        latestBuildNumber: 99,
        releaseTitle: 'CashBook v2.0.0 Feature Release',
        releaseNotes: '- In-app GitHub release updates\n- Performance improvements',
        apkSizeBytes: 29884416,
        publishedAt: DateTime(2026, 9, 11),
        downloadUrl:
            'https://github.com/Likhon545466/cashbook/releases/download/v2.0.0%2B99/CashBook-v2.0.0-build99.apk',
        htmlUrl: 'https://github.com/Likhon545466/cashbook/releases/tag/v2.0.0%2B99',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => UpdatePopupDialog.show(context, updateResult),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify header and titles
      expect(find.text('Update Available!'), findsOneWidget);
      expect(find.text('A new version of CashBook is ready for you.'), findsOneWidget);

      // Verify version pills
      expect(find.text('Installed'), findsOneWidget);
      expect(find.text('New Version'), findsOneWidget);
      expect(find.text('v2.0.0+99'), findsOneWidget);

      // Verify metadata chips
      expect(find.text('28.5 MB'), findsOneWidget);
      expect(find.text('Sep 11, 2026'), findsOneWidget);

      // Verify release notes
      expect(find.text('CashBook v2.0.0 Feature Release'), findsOneWidget);
      expect(find.textContaining('In-app GitHub release updates'), findsOneWidget);

      // Verify buttons
      expect(find.text('Download APK'), findsOneWidget);
      expect(find.text('GitHub Release'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update Available!'), findsNothing);
    });

    testWidgets('UpdateCheckerModal shows up to date state when on latest build', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v${AppInfo.currentVersion}+${AppInfo.currentBuildNumber}',
            'name': 'CashBook Release',
            'body': 'Everything up to date.',
            'assets': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateCheckerModal(updateService: service),
          ),
        ),
      );

      // Initial state is checking
      expect(find.text('Checking GitHub for Updates...'), findsOneWidget);

      // Advance clock past async call to complete update check
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('You\'re Up to Date!'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('View on GitHub'), findsOneWidget);
    });

    testWidgets('UpdateCheckerModal shows update available and allows APK download', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0+99',
            'name': 'CashBook 2.0 Mega Update',
            'body': 'Big enhancements included.',
            'published_at': '2026-09-11T12:00:00Z',
            'assets': [
              {
                'name': 'CashBook-v2.0.0-build99.apk',
                'size': 25000000,
                'browser_download_url':
                    'https://github.com/Likhon545466/cashbook/releases/download/v2.0.0/CashBook-v2.0.0-build99.apk',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateCheckerModal(updateService: service),
          ),
        ),
      );

      // Advance clock past async call
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Update Available!'), findsOneWidget);
      expect(find.text('Download APK'), findsOneWidget);
      expect(find.text('GitHub Release'), findsOneWidget);
      expect(find.text('CashBook 2.0 Mega Update'), findsOneWidget);
    });

    testWidgets('UpdateCheckerModal handles failure and provides Retry', (
      tester,
    ) async {
      var fail = true;
      final mockClient = MockClient((request) async {
        if (fail) {
          throw Exception('Network unreachable');
        }
        return http.Response(
          jsonEncode({
            'tag_name': 'v${AppInfo.currentVersion}+${AppInfo.currentBuildNumber}',
            'assets': [],
          }),
          200,
        );
      });

      final service = AppUpdateService(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateCheckerModal(updateService: service),
          ),
        ),
      );

      // Advance clock past failing async call
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Update Check Failed'), findsOneWidget);
      expect(find.text('Retry Check'), findsOneWidget);

      // Now set fail to false and click retry
      fail = false;
      await tester.tap(find.text('Retry Check'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('You\'re Up to Date!'), findsOneWidget);
    });

    testWidgets('UpdatePopupDialog displays in-app downloading progress bar when triggered', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '.',
      );

      final mockClient = MockClient.streaming((request, bodyStream) async {
        final bytes = List.generate(1024 * 10, (i) => i % 256);
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final updateResult = UpdateCheckResult(
        hasUpdate: true,
        latestVersion: '2.0.0',
        latestBuildNumber: 99,
        releaseTitle: 'CashBook v2.0.0 Feature Release',
        releaseNotes: 'Performance improvements',
        apkSizeBytes: 1024 * 10,
        downloadUrl: 'https://example.com/CashBook.apk',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => UpdatePopupDialog.show(
                    context,
                    updateResult,
                    updateService: service,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Download APK'), findsOneWidget);

      // Tap Download APK to start streaming inside runAsync for real I/O
      await tester.runAsync(() async {
        await tester.tap(find.text('Download APK'));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Download completed
      expect(find.text('Download Complete!'), findsOneWidget);
      expect(find.text('Install Update'), findsOneWidget);
    });
  });
}


