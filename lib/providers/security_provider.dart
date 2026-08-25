import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../services/database_service.dart';

class SecurityProvider extends ChangeNotifier {
  SecurityProvider(this._databaseService, this._localAuthentication);

  static const _appLockKey = 'app_lock_enabled';

  final DatabaseService _databaseService;
  final LocalAuthentication _localAuthentication;

  bool _isLoaded = false;
  bool _appLockEnabled = false;
  bool _isUnlocked = true;
  bool _isAuthenticating = false;
  String? _message;

  bool get isLoaded => _isLoaded;
  bool get appLockEnabled => _appLockEnabled;
  bool get isUnlocked => _isUnlocked;
  bool get isAuthenticating => _isAuthenticating;
  String? get message => _message;

  Future<void> load() async {
    try {
      final value = await _databaseService.getSetting(_appLockKey);
      _appLockEnabled = value == 'true';
      _isUnlocked = !_appLockEnabled;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> enableAppLock() async {
    if (_isAuthenticating) return false;

    final supported = await _canAuthenticate();
    if (!supported) {
      _message =
          'Set up a device screen lock or biometric authentication first.';
      notifyListeners();
      return false;
    }

    final authenticated = await authenticate(
      reason: 'Authenticate to enable CashBook App Lock',
    );

    if (!authenticated) return false;

    _appLockEnabled = true;
    _isUnlocked = true;
    _message = null;

    await _databaseService.setSetting(_appLockKey, 'true');
    notifyListeners();
    return true;
  }

  Future<void> disableAppLock() async {
    _appLockEnabled = false;
    _isUnlocked = true;
    _message = null;

    await _databaseService.setSetting(_appLockKey, 'false');
    notifyListeners();
  }

  void lock() {
    if (!_appLockEnabled || !_isUnlocked) return;

    _isUnlocked = false;
    _message = null;
    notifyListeners();
  }

  Future<bool> unlock() async {
    if (!_appLockEnabled) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }

    final authenticated = await authenticate(reason: 'Unlock CashBook');

    if (authenticated) {
      _isUnlocked = true;
      _message = null;
      notifyListeners();
    }

    return authenticated;
  }

  Future<bool> authenticate({required String reason}) async {
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    _message = null;
    notifyListeners();

    try {
      final result = await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!result) {
        _message = 'Authentication was not completed.';
      }

      return result;
    } on LocalAuthException catch (error) {
      _message = _messageForException(error);
      return false;
    } catch (_) {
      _message = 'Authentication is currently unavailable.';
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> _canAuthenticate() async {
    try {
      final biometric = await _localAuthentication.canCheckBiometrics;
      final device = await _localAuthentication.isDeviceSupported();
      return biometric || device;
    } catch (_) {
      return false;
    }
  }

  String _messageForException(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Biometric hardware is unavailable on this device.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Authentication is temporarily locked. Try again shortly.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Authentication is locked. Use your device credentials.';
      default:
        return 'Could not authenticate. Try again.';
    }
  }
}
