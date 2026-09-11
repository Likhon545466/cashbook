import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/google_auth_config.dart';
import '../services/database_service.dart';
import '../services/data_backup_service.dart';
import '../services/google_cloud_sync_service.dart';

class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider(
    this._databaseService, {
    GoogleCloudSyncService? cloudSyncService,
  }) : _cloudSyncService = cloudSyncService ?? GoogleCloudSyncService();

  final DatabaseService _databaseService;
  final GoogleCloudSyncService _cloudSyncService;

  static const String _autoSyncKey = 'google_cloud_auto_sync';
  static const String _lastSyncTimeKey = 'google_cloud_last_sync_time';
  static const String _serverClientIdKey = 'google_server_client_id';

  static const String _userEmailKey = 'google_user_email';
  static const String _userNameKey = 'google_user_name';
  static const String _userPhotoKey = 'google_user_photo';

  GoogleSignInAccount? _currentUser;
  String? _savedEmail;
  String? _savedDisplayName;
  String? _savedPhotoUrl;
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _autoSyncEnabled = false;
  DateTime? _lastSyncTime;
  CloudBackupMetadata? _cloudMetadata;
  String? _errorMessage;

  GoogleSignInAccount? get currentUser => _currentUser;
  String? get userEmail => _currentUser?.email ?? _savedEmail;
  String? get userDisplayName => _currentUser?.displayName ?? _savedDisplayName;
  String? get userPhotoUrl => _currentUser?.photoUrl ?? _savedPhotoUrl;
  bool get isSignedIn => _currentUser != null || (_savedEmail != null && _savedEmail!.isNotEmpty);
  bool get isSyncing => _isSyncing;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  CloudBackupMetadata? get cloudMetadata => _cloudMetadata;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  static const String _legacyAndroidClientId =
      '879746739863-9l6eks9fvu0jg0d194mejg4p8cg7i12g.apps.googleusercontent.com';

  Future<String?> getServerClientId() async {
    final saved = await _databaseService.getSetting(_serverClientIdKey);
    if (saved != null && saved.trim().isNotEmpty && saved.trim() != _legacyAndroidClientId) {
      return saved.trim();
    }
    if (GoogleAuthConfig.defaultServerClientId.trim().isNotEmpty) {
      if (saved == _legacyAndroidClientId) {
        await _databaseService.setSetting(
          _serverClientIdKey,
          GoogleAuthConfig.defaultServerClientId.trim(),
        );
      }
      return GoogleAuthConfig.defaultServerClientId.trim();
    }
    return null;
  }

  Future<void> setServerClientId(String clientId) async {
    await _databaseService.setSetting(_serverClientIdKey, clientId.trim());
    await _cloudSyncService.ensureInitialized(serverClientId: clientId.trim());
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final autoSyncSetting = await _databaseService.getSetting(_autoSyncKey);
      _autoSyncEnabled = autoSyncSetting == 'true';

      final lastSyncSetting = await _databaseService.getSetting(_lastSyncTimeKey);
      if (lastSyncSetting != null && lastSyncSetting.isNotEmpty) {
        _lastSyncTime = DateTime.tryParse(lastSyncSetting);
      }

      _savedEmail = await _databaseService.getSetting(_userEmailKey);
      _savedDisplayName = await _databaseService.getSetting(_userNameKey);
      _savedPhotoUrl = await _databaseService.getSetting(_userPhotoKey);

      final clientId = await getServerClientId();
      final account = await _cloudSyncService.signInSilently(serverClientId: clientId);
      _currentUser = account;

      if (_currentUser != null) {
        _savedEmail = _currentUser!.email;
        _savedDisplayName = _currentUser!.displayName;
        _savedPhotoUrl = _currentUser!.photoUrl;
      }

      if (isSignedIn) {
        unawaited(fetchCloudMetadata());
      }
    } catch (e) {
      debugPrint('CloudSyncProvider init error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> connectGoogleAccount({String? customServerClientId}) async {
    _errorMessage = null;
    try {
      final clientId = customServerClientId ?? await getServerClientId();
      if (customServerClientId != null && customServerClientId.isNotEmpty) {
        await _databaseService.setSetting(_serverClientIdKey, customServerClientId.trim());
      }

      final account = await _cloudSyncService.signIn(serverClientId: clientId);
      if (account != null) {
        _currentUser = account;
        _savedEmail = account.email;
        _savedDisplayName = account.displayName;
        _savedPhotoUrl = account.photoUrl;

        await _databaseService.setSetting(_userEmailKey, account.email);
        if (account.displayName != null) {
          await _databaseService.setSetting(_userNameKey, account.displayName!);
        }
        if (account.photoUrl != null) {
          await _databaseService.setSetting(_userPhotoKey, account.photoUrl!);
        }

        final autoSyncSetting = await _databaseService.getSetting(_autoSyncKey);
        if (autoSyncSetting == null) {
          // Enable auto-sync by default when user explicitly connects
          await setAutoSyncEnabled(true);
        }
        await fetchCloudMetadata();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      final str = e.toString();
      if (str.contains('serverClientId must be provided') || str.contains('clientConfigurationError')) {
        _errorMessage = 'OAuth Web Client ID is required to connect Google Drive on Android.';
      } else if (str.contains('[16]') || str.contains('reauth failed') || str.contains('DEVELOPER_ERROR')) {
        _errorMessage =
            'Google Sign-In configuration error (Code 16): Ensure your SHA-1 fingerprint is added as an Android Client ID and your email is in Test Users in Google Cloud Console.';
      } else {
        _errorMessage = 'Failed to sign in with Google: $e';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectGoogleAccount() async {
    _errorMessage = null;
    try {
      await _cloudSyncService.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    _currentUser = null;
    _savedEmail = null;
    _savedDisplayName = null;
    _savedPhotoUrl = null;
    _cloudMetadata = null;

    await _databaseService.setSetting(_userEmailKey, '');
    await _databaseService.setSetting(_userNameKey, '');
    await _databaseService.setSetting(_userPhotoKey, '');

    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    if (_autoSyncEnabled == enabled) return;
    _autoSyncEnabled = enabled;
    notifyListeners();
    await _databaseService.setSetting(_autoSyncKey, enabled.toString());
  }

  Future<CloudBackupMetadata?> fetchCloudMetadata() async {
    if (!isSignedIn) {
      _cloudMetadata = null;
      return null;
    }

    try {
      final meta = await _cloudSyncService.getCloudBackupMetadata();
      _cloudMetadata = meta;
      notifyListeners();
      return meta;
    } catch (e) {
      debugPrint('Error fetching cloud metadata: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCloudBackupPayload() async {
    if (!isSignedIn) return null;
    _errorMessage = null;
    try {
      return await _cloudSyncService.fetchLatestBackup();
    } catch (e) {
      _errorMessage = 'Failed to fetch cloud backup payload: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> backupToCloud(DataBackupService dataBackupService) async {
    if (!isSignedIn) {
      _errorMessage = 'Google Account is not connected.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null) {
        final clientId = await getServerClientId();
        _currentUser = await _cloudSyncService.signInSilently(serverClientId: clientId);
      }
      final payload = await dataBackupService.buildBackupPayload();
      final meta = await _cloudSyncService.uploadBackup(payload);
      _cloudMetadata = meta;
      _lastSyncTime = DateTime.now();
      await _databaseService.setSetting(
        _lastSyncTimeKey,
        _lastSyncTime!.toIso8601String(),
      );
      return true;
    } catch (e) {
      _errorMessage = 'Cloud backup failed: $e';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> restoreFromCloud(DataBackupService dataBackupService) async {
    if (!isSignedIn) {
      _errorMessage = 'Google Account is not connected.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_currentUser == null) {
        final clientId = await getServerClientId();
        _currentUser = await _cloudSyncService.signInSilently(serverClientId: clientId);
      }
      final payload = await _cloudSyncService.fetchLatestBackup();
      if (payload == null) {
        throw Exception('No cloud backup was found in your Google Drive App Data.');
      }
      await dataBackupService.restoreFromJsonMap(payload);
      _lastSyncTime = DateTime.now();
      await _databaseService.setSetting(
        _lastSyncTimeKey,
        _lastSyncTime!.toIso8601String(),
      );
      await fetchCloudMetadata();
      return true;
    } catch (e) {
      _errorMessage = 'Cloud restore failed: $e';
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Timer? _debounceTimer;

  void scheduleAutoSync({Duration delay = const Duration(seconds: 4)}) {
    if (!_autoSyncEnabled || !isSignedIn) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      triggerAutoSync();
    });
  }

  Future<void> triggerAutoSync() async {
    final dataBackupService = DataBackupService(_databaseService);
    await triggerAutoSyncIfEnabled(dataBackupService);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> triggerAutoSyncIfEnabled(DataBackupService dataBackupService) async {
    if (!_autoSyncEnabled || !isSignedIn || _isSyncing) return;
    try {
      if (_currentUser == null) {
        final clientId = await getServerClientId();
        _currentUser = await _cloudSyncService.signInSilently(serverClientId: clientId);
      }
      final payload = await dataBackupService.buildBackupPayload();
      final meta = await _cloudSyncService.uploadBackup(payload);
      _cloudMetadata = meta;
      _lastSyncTime = DateTime.now();
      await _databaseService.setSetting(
        _lastSyncTimeKey,
        _lastSyncTime!.toIso8601String(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Auto-sync background upload error: $e');
    }
  }
}
