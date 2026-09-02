import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/services/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService Unit Tests', () {
    test('encrypts and decrypts payload correctly with correct password', () {
      final samplePayload = <String, dynamic>{
        'app': 'CashBook',
        'backupVersion': 4,
        'createdAt': '2026-09-02T12:00:00.000',
        'transactions': [
          {
            'id': 1,
            'type': 'income',
            'amount': 50000,
            'category': 'Salary',
            'date': '2026-09-01T09:00:00.000',
            'note': 'Main monthly pay',
          }
        ],
        'settings': {'currency_symbol': '৳', 'theme_mode': 'system'},
      };

      const password = 'SecureUserPassword!123';

      final encrypted = BackupEncryptionService.encryptJson(
        payload: samplePayload,
        password: password,
      );

      expect(encrypted['app'], equals('CashBook'));
      expect(encrypted['format'], equals('encrypted_backup'));
      expect(encrypted['cipher'], equals('aes-256-cbc'));
      expect(encrypted['ciphertext'], isNotEmpty);
      expect(BackupEncryptionService.isEncryptedBackup(encrypted), isTrue);

      final decrypted = BackupEncryptionService.decryptJson(
        encryptedEnvelope: encrypted,
        password: password,
      );

      expect(decrypted['app'], equals('CashBook'));
      expect(decrypted['backupVersion'], equals(4));
      expect(decrypted['transactions'], isA<List>());
      expect((decrypted['transactions'] as List).length, equals(1));
      expect(decrypted['settings']['currency_symbol'], equals('৳'));
    });

    test('throws FormatException on wrong password', () {
      final samplePayload = <String, dynamic>{
        'app': 'CashBook',
        'backupVersion': 4,
        'transactions': [],
        'settings': {},
      };

      final encrypted = BackupEncryptionService.encryptJson(
        payload: samplePayload,
        password: 'CorrectPassword123',
      );

      expect(
        () => BackupEncryptionService.decryptJson(
          encryptedEnvelope: encrypted,
          password: 'WrongPassword456',
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException on corrupted envelope', () {
      final samplePayload = <String, dynamic>{
        'app': 'CashBook',
        'backupVersion': 4,
        'transactions': [],
        'settings': {},
      };

      final encrypted = BackupEncryptionService.encryptJson(
        payload: samplePayload,
        password: 'Password123',
      );

      final corrupted = Map<String, dynamic>.from(encrypted)
        ..['ciphertext'] = 'CorruptedBase64String==';

      expect(
        () => BackupEncryptionService.decryptJson(
          encryptedEnvelope: corrupted,
          password: 'Password123',
        ),
        throwsFormatException,
      );
    });
  });
}
