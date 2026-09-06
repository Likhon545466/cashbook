import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cashbook/providers/cloud_sync_provider.dart';
import 'package:cashbook/services/data_backup_service.dart';
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
  Map<String, dynamic>? cloudBackupData;
  CloudBackupMetadata? cloudMetadata;
  bool uploadCalled = false;
  bool fetchCalled = false;

  FakeGoogleCloudSyncService({GoogleSignInAccount? initialAccount})
      : _account = initialAccount;

  @override
  GoogleSignInAccount? get currentUser => _account;

  @override
  bool get isSignedIn => _account != null;

  @override
  Future<GoogleSignInAccount?> signIn({String? serverClientId, String? clientId}) async {
    _account = FakeGoogleSignInAccount(
      displayName: 'Test User',
      email: 'test@example.com',
      id: '12345',
    );
    return _account;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({String? serverClientId, String? clientId}) async {
    return _account;
  }

  @override
  Future<void> signOut() async {
    _account = null;
    cloudMetadata = null;
  }

  @override
  Future<CloudBackupMetadata?> getCloudBackupMetadata() async {
    return cloudMetadata;
  }

  @override
  Future<CloudBackupMetadata> uploadBackup(Map<String, dynamic> payload) async {
    uploadCalled = true;
    cloudBackupData = payload;
    final txList = payload['transactions'] as List?;
    final meta = CloudBackupMetadata(
      fileId: 'mock_file_id_123',
      modifiedTime: DateTime.now(),
      sizeBytes: 1024,
      backupVersion: 4,
      transactionCount: txList?.length ?? 0,
      createdAt: DateTime.now().toIso8601String(),
    );
    cloudMetadata = meta;
    return meta;
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestBackup() async {
    fetchCalled = true;
    return cloudBackupData;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDataBackupService extends DataBackupService {
  FakeDataBackupService(super.databaseService);

  Map<String, dynamic> payloadToReturn = {
    'app': 'CashBook',
    'backupVersion': 4,
    'transactions': [
      {
        'id': 1,
        'type': 'income',
        'amount': 25000,
        'category': 'Salary',
        'date': '2026-09-01T10:00:00.000',
        'note': 'Monthly salary',
      }
    ],
    'settings': {},
  };

  bool restored = false;
  Map<String, dynamic>? restoredData;

  @override
  Future<Map<String, dynamic>> buildBackupPayload() async {
    return payloadToReturn;
  }

  @override
  Future<void> restoreFromJsonMap(Map<String, dynamic> decoded) async {
    restored = true;
    restoredData = decoded;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudBackupMetadata Tests', () {
    test('instantiates with proper attributes', () {
      final now = DateTime.now();
      final meta = CloudBackupMetadata(
        fileId: 'file_abc',
        modifiedTime: now,
        sizeBytes: 2048,
        backupVersion: 4,
        transactionCount: 15,
        createdAt: '2026-09-06T12:00:00.000',
      );

      expect(meta.fileId, equals('file_abc'));
      expect(meta.modifiedTime, equals(now));
      expect(meta.sizeBytes, equals(2048));
      expect(meta.backupVersion, equals(4));
      expect(meta.transactionCount, equals(15));
      expect(meta.createdAt, equals('2026-09-06T12:00:00.000'));
    });
  });

  group('CloudSyncProvider Tests', () {
    late FakeDatabaseService fakeDb;
    late FakeGoogleCloudSyncService fakeSyncService;
    late FakeDataBackupService fakeBackupService;
    late CloudSyncProvider provider;

    setUp(() {
      fakeDb = FakeDatabaseService();
      fakeSyncService = FakeGoogleCloudSyncService();
      fakeBackupService = FakeDataBackupService(fakeDb);
      provider = CloudSyncProvider(
        fakeDb,
        cloudSyncService: fakeSyncService,
      );
    });

    test('initial state is unauthenticated and not syncing', () {
      expect(provider.isSignedIn, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.isSyncing, isFalse);
      expect(provider.autoSyncEnabled, isFalse);
      expect(provider.lastSyncTime, isNull);
      expect(provider.cloudMetadata, isNull);
    });

    test('init() loads saved settings and performs silent sign in', () async {
      fakeDb.settings['google_cloud_auto_sync'] = 'true';
      fakeDb.settings['google_cloud_last_sync_time'] = '2026-09-05T14:30:00.000';
      fakeSyncService._account = FakeGoogleSignInAccount(
        displayName: 'Existing User',
        email: 'existing@example.com',
        id: '999',
      );

      await provider.init();

      expect(provider.isInitialized, isTrue);
      expect(provider.autoSyncEnabled, isTrue);
      expect(provider.lastSyncTime, equals(DateTime.parse('2026-09-05T14:30:00.000')));
      expect(provider.isSignedIn, isTrue);
      expect(provider.currentUser?.email, equals('existing@example.com'));
    });

    test('connectGoogleAccount() signs in user and enables auto-sync by default', () async {
      final success = await provider.connectGoogleAccount();

      expect(success, isTrue);
      expect(provider.isSignedIn, isTrue);
      expect(provider.currentUser?.email, equals('test@example.com'));
      expect(provider.autoSyncEnabled, isTrue);
      expect(fakeDb.settings['google_cloud_auto_sync'], equals('true'));
    });

    test('disconnectGoogleAccount() signs out and clears user state', () async {
      await provider.connectGoogleAccount();
      expect(provider.isSignedIn, isTrue);

      await provider.disconnectGoogleAccount();
      expect(provider.isSignedIn, isFalse);
      expect(provider.currentUser, isNull);
      expect(provider.cloudMetadata, isNull);
    });

    test('setAutoSyncEnabled() updates provider state and persists in database', () async {
      await provider.setAutoSyncEnabled(true);
      expect(provider.autoSyncEnabled, isTrue);
      expect(fakeDb.settings['google_cloud_auto_sync'], equals('true'));

      await provider.setAutoSyncEnabled(false);
      expect(provider.autoSyncEnabled, isFalse);
      expect(fakeDb.settings['google_cloud_auto_sync'], equals('false'));
    });

    test('backupToCloud() fails if not signed in', () async {
      final success = await provider.backupToCloud(fakeBackupService);
      expect(success, isFalse);
      expect(provider.errorMessage, contains('not connected'));
    });

    test('backupToCloud() uploads payload and updates metadata & lastSyncTime', () async {
      await provider.connectGoogleAccount();

      final success = await provider.backupToCloud(fakeBackupService);

      expect(success, isTrue);
      expect(fakeSyncService.uploadCalled, isTrue);
      expect(fakeSyncService.cloudBackupData, isNotNull);
      expect(fakeSyncService.cloudBackupData!['app'], equals('CashBook'));
      expect(provider.cloudMetadata, isNotNull);
      expect(provider.cloudMetadata?.transactionCount, equals(1));
      expect(provider.lastSyncTime, isNotNull);
      expect(fakeDb.settings['google_cloud_last_sync_time'], isNotNull);
    });

    test('restoreFromCloud() restores payload from cloud backup into database', () async {
      await provider.connectGoogleAccount();
      // First backup something to cloud
      await provider.backupToCloud(fakeBackupService);

      final success = await provider.restoreFromCloud(fakeBackupService);

      expect(success, isTrue);
      expect(fakeSyncService.fetchCalled, isTrue);
      expect(fakeBackupService.restored, isTrue);
      expect(fakeBackupService.restoredData!['app'], equals('CashBook'));
    });

    test('triggerAutoSyncIfEnabled() automatically uploads when enabled', () async {
      await provider.connectGoogleAccount();
      fakeSyncService.uploadCalled = false;

      await provider.triggerAutoSyncIfEnabled(fakeBackupService);
      expect(fakeSyncService.uploadCalled, isTrue);
    });

    test('triggerAutoSyncIfEnabled() does nothing when auto-sync is disabled', () async {
      await provider.connectGoogleAccount();
      await provider.setAutoSyncEnabled(false);
      fakeSyncService.uploadCalled = false;

      await provider.triggerAutoSyncIfEnabled(fakeBackupService);
      expect(fakeSyncService.uploadCalled, isFalse);
    });
  });
}
