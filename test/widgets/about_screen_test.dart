import 'package:cashbook/core/constants/app_info.dart';
import 'package:cashbook/screens/settings/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AboutScreen Widget Tests', () {
    testWidgets('renders App info, developer profile, and changelog correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AboutScreen(),
        ),
      );

      // Verify AppBar and Branding
      expect(find.text('About CashBook'), findsOneWidget);
      expect(find.text('CashBook'), findsWidgets);
      expect(find.text(AppInfo.fullVersion), findsOneWidget);

      // Verify Developer & GitHub Info
      expect(find.text('Developer & GitHub'), findsOneWidget);
      expect(find.text('${AppInfo.developerName} (@${AppInfo.githubUsername})'), findsOneWidget);
      expect(find.text('${AppInfo.githubUsername}/${AppInfo.githubRepoName}'), findsOneWidget);
      expect(find.text('Issue Tracker'), findsOneWidget);

      // Scroll to Changelog section
      await tester.scrollUntilVisible(
        find.text('Version History & Changelog'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Version History & Changelog'), findsOneWidget);
      expect(find.text(AppInfo.changelog.first.version), findsOneWidget);
      expect(find.text('Time Display & About Hub'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);

      // Scroll to Privacy section
      await tester.scrollUntilVisible(
        find.text('100% Offline & Private'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('100% Offline & Private'), findsOneWidget);
    });
  });
}
