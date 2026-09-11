import 'package:cashbook/providers/settings_provider.dart';
import 'package:cashbook/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDatabaseService implements DatabaseService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getSetting(String key) async => _storage[key];

  @override
  Future<void> setSetting(String key, String value) async {
    _storage[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SettingsProvider Update Frequency Tests', () {
    late FakeDatabaseService fakeDb;
    late SettingsProvider provider;

    setUp(() {
      fakeDb = FakeDatabaseService();
      provider = SettingsProvider(fakeDb);
    });

    test('initial default update frequency is onStartup', () {
      expect(provider.updateFrequency, UpdateFrequency.onStartup);
      expect(provider.shouldCheckForUpdate(), isTrue);
    });

    test('setUpdateFrequency updates provider and persists in database', () async {
      await provider.setUpdateFrequency(UpdateFrequency.daily);

      expect(provider.updateFrequency, UpdateFrequency.daily);
      expect(
        await fakeDb.getSetting('update_check_frequency'),
        'daily',
      );
    });

    test('loadTheme loads saved update frequency and last check timestamp', () async {
      await fakeDb.setSetting('update_check_frequency', 'weekly');
      final checkTime = DateTime(2026, 9, 10, 12, 0);
      await fakeDb.setSetting('last_update_check_time', checkTime.toIso8601String());

      await provider.loadTheme();

      expect(provider.updateFrequency, UpdateFrequency.weekly);
      expect(provider.lastUpdateCheckTime, checkTime);
    });

    test('shouldCheckForUpdate returns false when set to manualOnly', () async {
      await provider.setUpdateFrequency(UpdateFrequency.manualOnly);
      expect(provider.shouldCheckForUpdate(), isFalse);
    });

    test('shouldCheckForUpdate calculates daily interval correctly', () async {
      await provider.setUpdateFrequency(UpdateFrequency.daily);

      // Never checked before -> should check
      expect(provider.shouldCheckForUpdate(), isTrue);

      // Just checked now -> should not check
      await provider.recordUpdateCheckNow();
      expect(provider.shouldCheckForUpdate(), isFalse);
    });

    test('recordUpdateCheckNow updates timestamp and persists', () async {
      await provider.recordUpdateCheckNow();

      expect(provider.lastUpdateCheckTime, isNotNull);
      final savedStr = await fakeDb.getSetting('last_update_check_time');
      expect(savedStr, isNotNull);
      expect(DateTime.tryParse(savedStr!), isNotNull);
    });
  });
}
