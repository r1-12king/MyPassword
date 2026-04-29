import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExportDirectorySelection {
  const ExportDirectorySelection({
    required this.uri,
    required this.label,
  });

  final String uri;
  final String label;
}

class BackupFileSelection {
  const BackupFileSelection({
    required this.path,
    required this.label,
  });

  final String path;
  final String label;
}

class ExportDirectoryService {
  static const _channel = MethodChannel('my_password/export_directory');

  Future<ExportDirectorySelection?> pickDirectory() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickDirectory',
    );
    if (result == null) return null;
    return ExportDirectorySelection(
      uri: result['uri']! as String,
      label: result['label']! as String,
    );
  }

  Future<BackupFileSelection?> pickBackupFile() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickBackupFile',
    );
    if (result == null) return null;
    return BackupFileSelection(
      path: result['path']! as String,
      label: result['label']! as String,
    );
  }

  Future<String> writeBackupFile({
    required String directoryUri,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'writeBackupFile',
      {
        'directoryUri': directoryUri,
        'fileName': fileName,
        'bytes': bytes,
      },
    );
    if (result == null || result['uri'] == null) {
      throw StateError('Unable to write backup file');
    }
    return result['uri']! as String;
  }
}

final exportDirectoryServiceProvider = Provider<ExportDirectoryService>((ref) {
  return ExportDirectoryService();
});
