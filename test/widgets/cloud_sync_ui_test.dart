import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:cashbook/providers/cloud_sync_provider.dart';
import 'package:cashbook/providers/security_provider.dart';
import 'package:cashbook/providers/settings_provider.dart';
import 'package:cashbook/screens/settings/settings_screen.dart';
import 'package:cashbook/screens/settings/data_management_screen.dart';
import 'package:cashbook/services/database_service.dart';
import 'package:cashbook/services/google_cloud_sync_service.dart';

class FakeGoogleSignInAccount implements GoogleSignInAccount {
  @override
  final String displayName;
  @override
  final String email;
  @override
  final String id;
  @override
  final String? photoUrl;

  FakeGoogleSignInAccount({
    required this.displayName,
    required this.email,
    required this.id,
    this.photoUrl,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleCloudSyncService extends GoogleCloudSyncService {
  GoogleSignInAccount? _account;
  CloudBackupMetadata? metadata;

  FakeGoogleCloudSyncService({GoogleSignInAccount? initialAccount})
      : _account = initialAccount;

  @override
  GoogleSignInAccount? get currentUser => _account;

  @override
  bool get isSignedIn => _account != null;

  @override
  Future<CloudBackupMetadata?> getCloudBackupMetadata() async => metadata;

  @override
  Future<GoogleSignInAccount?> signIn({String? serverClientId, String? clientId}) async {
    _account = FakeGoogleSignInAccount(
      displayName: 'Alex Mercer',
      email: 'alex.mercer@gmail.com',
      id: 'google_user_99',
    );
    return _account;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({String? serverClientId, String? clientId}) async => _account;

  @override
  Future<void> signOut() async {
    _account = null;
  }
}

class FakeDatabaseService implements DatabaseService {
  final Map<String, String> settings = {};

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<Map<String, String>> getAllSettings() async => Map.from(settings);

  @override
  Future<Map<String, int>> getDatabaseStats() async => {
        'transactions': 12,
        'customCategories': 3,
        'savingsTransfers': 2,
        'debts': 1,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecurityProvider extends ChangeNotifier implements SecurityProvider {
  @override
  bool get appLockEnabled => false;
  @override
  bool get isAuthenticating => false;
  @override
  bool get isLoaded => true;
  @override
  String? get message => null;
  @override
  bool get isUnlocked => true;

  @override
  Future<void> disableAppLock() async {}

  @override
  Future<bool> enableAppLock() async => true;

  @override
  Future<void> load() async {}

  @override
  Future<bool> authenticate({required String reason}) async => true;

  @override
  void lock() {}

  @override
  Future<bool> unlock() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsScreen Cloud Sync UI Tests', () {
    testWidgets('displays "Google Cloud Sync" when unauthenticated', (tester) async {
      final fakeDb = FakeDatabaseService();
      final fakeSyncService = FakeGoogleCloudSyncService();
      final cloudProvider = CloudSyncProvider(
        fakeDb,
        cloudSyncService: fakeSyncService,
      );
      final settingsProvider = SettingsProvider(fakeDb);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<SecurityProvider>.value(value: FakeSecurityProvider()),
            ChangeNotifierProvider<CloudSyncProvider>.value(value: cloudProvider),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cloud & Sync'), findsOneWidget);
      expect(find.text('Google Cloud Sync'), findsOneWidget);
      expect(find.text('Connect Google Drive for auto-backup & restore'), findsOneWidget);
    });

    testWidgets('displays user profile info when connected', (tester) async {
      final fakeDb = FakeDatabaseService();
      final fakeSyncService = FakeGoogleCloudSyncService(
        initialAccount: FakeGoogleSignInAccount(
          displayName: 'Likhon Dev',
          email: 'likhon@example.com',
          id: '123',
        ),
      );
      final cloudProvider = CloudSyncProvider(
        fakeDb,
        cloudSyncService: fakeSyncService,
      );
      await cloudProvider.init();

      final settingsProvider = SettingsProvider(fakeDb);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<SecurityProvider>.value(value: FakeSecurityProvider()),
            ChangeNotifierProvider<CloudSyncProvider>.value(value: cloudProvider),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cloud & Sync'), findsOneWidget);
      expect(find.text('Likhon Dev'), findsOneWidget);
      expect(find.text('Connected to Google Drive'), findsOneWidget);
    });
  });

  group('DataManagementScreen Google Cloud Sync Section Tests', () {
    testWidgets('renders "Connect Google Account" button when signed out', (tester) async {
      final fakeDb = FakeDatabaseService();
      final fakeSyncService = FakeGoogleCloudSyncService();
      final cloudProvider = CloudSyncProvider(
        fakeDb,
        cloudSyncService: fakeSyncService,
      );
      final settingsProvider = SettingsProvider(fakeDb);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<CloudSyncProvider>.value(value: cloudProvider),
          ],
          child: MaterialApp(
            home: DataManagementScreen(databaseService: fakeDb),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Google Drive Cloud Sync'), findsOneWidget);
      expect(find.text('Google Drive Cloud Backup'), findsOneWidget);
      expect(find.text('Connect Google Account'), findsOneWidget);
    });
  });
}
