import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class CloudBackupMetadata {
  final String fileId;
  final DateTime modifiedTime;
  final int sizeBytes;
  final int? backupVersion;
  final int? transactionCount;
  final String? createdAt;

  const CloudBackupMetadata({
    required this.fileId,
    required this.modifiedTime,
    required this.sizeBytes,
    this.backupVersion,
    this.transactionCount,
    this.createdAt,
  });
}

class GoogleCloudSyncService {
  GoogleCloudSyncService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  static const String _backupFileName = 'cashbook_cloud_backup.json';
  static const List<String> _driveScopes = [
    drive.DriveApi.driveAppdataScope,
  ];

  GoogleSignInAccount? _account;
  bool _initialized = false;
  String? _currentServerClientId;

  GoogleSignInAccount? get currentUser => _account;
  bool get isSignedIn => _account != null;

  Future<void> ensureInitialized({String? serverClientId, String? clientId}) async {
    if (_initialized && _currentServerClientId == serverClientId) return;
    try {
      await _googleSignIn.initialize(
        serverClientId: serverClientId,
        clientId: clientId,
      );
      _currentServerClientId = serverClientId;
      _initialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn initialize error: $e');
    }
  }

  Future<GoogleSignInAccount?> signIn({String? serverClientId, String? clientId}) async {
    try {
      await ensureInitialized(serverClientId: serverClientId, clientId: clientId);
      final account = await _googleSignIn.authenticate();
      _account = account;
      return account;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signInSilently({String? serverClientId, String? clientId}) async {
    try {
      await ensureInitialized(serverClientId: serverClientId, clientId: clientId);
      if (_account != null) return _account;

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.attemptLightweightAuthentication();
      } catch (e) {
        debugPrint('Google attemptLightweightAuthentication error: $e');
      }
      _account = account;
      return _account;
    } catch (e) {
      debugPrint('Google Silent Sign-In error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await ensureInitialized();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    } finally {
      _account = null;
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    var account = _account;
    account ??= await signInSilently(serverClientId: _currentServerClientId);
    if (account == null) return null;
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(_driveScopes);
      if (authorization == null) return null;
      final client = authorization.authClient(scopes: _driveScopes);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Error creating DriveApi client: $e');
      return null;
    }
  }

  Future<CloudBackupMetadata?> getCloudBackupMetadata() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return null;

    try {
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime, size, appProperties, description)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) return null;

      final file = files.first;
      final fileId = file.id;
      final modifiedTime = file.modifiedTime ?? DateTime.now();
      final size = int.tryParse(file.size ?? '0') ?? 0;

      int? txCount;
      int? backupVer;
      String? created;

      final props = file.appProperties;
      if (props != null) {
        txCount = int.tryParse(props['transactionCount'] ?? '');
        backupVer = int.tryParse(props['backupVersion'] ?? '');
        created = props['createdAt'];
      }

      if (fileId != null) {
        return CloudBackupMetadata(
          fileId: fileId,
          modifiedTime: modifiedTime,
          sizeBytes: size,
          backupVersion: backupVer,
          transactionCount: txCount,
          createdAt: created,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cloud metadata: $e');
      return null;
    }
  }

  Future<CloudBackupMetadata> uploadBackup(Map<String, dynamic> payload) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive API client is not authenticated.');
    }

    final jsonString = jsonEncode(payload);
    final bytes = utf8.encode(jsonString);
    final stream = Stream.value(bytes);
    final media = drive.Media(stream, bytes.length);

    final txList = payload['transactions'] as List?;
    final txCount = txList?.length ?? 0;
    final backupVersion = payload['backupVersion']?.toString() ?? '4';
    final createdAt = payload['createdAt']?.toString() ?? DateTime.now().toIso8601String();

    final appProperties = {
      'transactionCount': txCount.toString(),
      'backupVersion': backupVersion,
      'createdAt': createdAt,
      'app': 'CashBook',
    };

    // Check if file already exists in AppData
    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id)',
    );

    final existingFiles = fileList.files;
    drive.File uploadedFile;

    if (existingFiles != null && existingFiles.isNotEmpty) {
      final existingId = existingFiles.first.id!;
      final patchFile = drive.File()
        ..modifiedTime = DateTime.now().toUtc()
        ..appProperties = appProperties;

      uploadedFile = await driveApi.files.update(
        patchFile,
        existingId,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime, size, appProperties',
      );
    } else {
      final newFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']
        ..appProperties = appProperties;

      uploadedFile = await driveApi.files.create(
        newFile,
        uploadMedia: media,
        $fields: 'id, name, modifiedTime, size, appProperties',
      );
    }

    return CloudBackupMetadata(
      fileId: uploadedFile.id ?? '',
      modifiedTime: uploadedFile.modifiedTime ?? DateTime.now(),
      sizeBytes: int.tryParse(uploadedFile.size ?? '0') ?? bytes.length,
      backupVersion: int.tryParse(backupVersion),
      transactionCount: txCount,
      createdAt: createdAt,
    );
  }

  Future<Map<String, dynamic>?> fetchLatestBackup() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      throw StateError('Google Drive API client is not authenticated.');
    }

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id)',
    );

    final files = fileList.files;
    if (files == null || files.isEmpty) return null;

    final fileId = files.first.id!;
    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (response is! drive.Media) {
      throw StateError('Failed to download media stream from Google Drive.');
    }

    final byteList = <int>[];
    await for (final chunk in response.stream) {
      byteList.addAll(chunk);
    }

    final jsonString = utf8.decode(byteList);
    final map = jsonDecode(jsonString);

    if (map is Map<String, dynamic>) {
      return map;
    }
    return null;
  }
}
