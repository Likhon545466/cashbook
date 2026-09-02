import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupEncryptionService {
  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _iterations = 10000;
  static const int _keyLength = 32;

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    var derivedKey = Uint8List(0);
    var blockIndex = 1;

    while (derivedKey.length < _keyLength) {
      final hmac = Hmac(sha256, passwordBytes);
      final initialBlock = Uint8List(salt.length + 4);
      initialBlock.setRange(0, salt.length, salt);
      initialBlock[salt.length] = (blockIndex >> 24) & 0xff;
      initialBlock[salt.length + 1] = (blockIndex >> 16) & 0xff;
      initialBlock[salt.length + 2] = (blockIndex >> 8) & 0xff;
      initialBlock[salt.length + 3] = blockIndex & 0xff;

      var u = Uint8List.fromList(hmac.convert(initialBlock).bytes);
      final block = Uint8List.fromList(u);

      for (var i = 1; i < _iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      final combined = Uint8List(derivedKey.length + block.length);
      combined.setRange(0, derivedKey.length, derivedKey);
      combined.setRange(derivedKey.length, combined.length, block);
      derivedKey = combined;
      blockIndex++;
    }

    return Uint8List.sublistView(derivedKey, 0, _keyLength);
  }

  static Map<String, dynamic> encryptJson({
    required Map<String, dynamic> payload,
    required String password,
  }) {
    final jsonString = jsonEncode(payload);
    final salt = _generateRandomBytes(_saltLength);
    final ivBytes = _generateRandomBytes(_ivLength);
    final keyBytes = _deriveKey(password, salt);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    return {
      'app': 'CashBook',
      'format': 'encrypted_backup',
      'version': 1,
      'kdf': 'pbkdf2_sha256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(ivBytes),
      'cipher': 'aes-256-cbc',
      'ciphertext': encrypted.base64,
    };
  }

  static Map<String, dynamic> decryptJson({
    required Map<String, dynamic> encryptedEnvelope,
    required String password,
  }) {
    if (encryptedEnvelope['app'] != 'CashBook' ||
        encryptedEnvelope['format'] != 'encrypted_backup') {
      throw const FormatException('Not a valid encrypted CashBook backup.');
    }

    final salt = base64Decode(encryptedEnvelope['salt'] as String);
    final ivBytes = base64Decode(encryptedEnvelope['iv'] as String);
    final ciphertext = encryptedEnvelope['ciphertext'] as String;

    final keyBytes = _deriveKey(password, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    try {
      final decrypted = encrypter.decrypt64(ciphertext, iv: iv);
      final decoded = jsonDecode(decrypted);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid decrypted backup structure.');
      }
      return decoded;
    } catch (_) {
      throw const FormatException('Incorrect password or corrupted backup.');
    }
  }

  static bool isEncryptedBackup(Map<String, dynamic> data) {
    return data['app'] == 'CashBook' && data['format'] == 'encrypted_backup';
  }
}
