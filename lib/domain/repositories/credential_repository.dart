class SaveCredentialInput {
  SaveCredentialInput({
    this.id,
    required this.title,
    this.username,
    required this.password,
    this.websiteUrl,
    this.notes,
    this.category,
    this.favorite = false,
  });

  final String? id;
  final String title;
  final String? username;
  final String password;
  final String? websiteUrl;
  final String? notes;
  final String? category;
  final bool favorite;
}

class CredentialListItem {
  CredentialListItem({
    required this.id,
    required this.title,
    required this.username,
    required this.websiteDomain,
    required this.favorite,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? username;
  final String? websiteDomain;
  final bool favorite;
  final DateTime updatedAt;
}

class CredentialDetail {
  CredentialDetail({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    required this.websiteUrl,
    required this.websiteDomain,
    required this.notes,
    required this.category,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? username;
  final String password;
  final String? websiteUrl;
  final String? websiteDomain;
  final String? notes;
  final String? category;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BackupExportData {
  BackupExportData({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final List<int> bytes;
}

abstract class CredentialRepository {
  Future<String> saveCredential(SaveCredentialInput input);
  Future<List<CredentialListItem>> getCredentials({
    String? query,
    bool favoritesOnly = false,
  });
  Future<CredentialDetail?> getCredentialDetail(String id);
  Future<void> deleteCredential(String id);
  Future<void> markCredentialUsed(String id);
  String generatePassword({
    int length = 20,
    bool uppercase = true,
    bool lowercase = true,
    bool numbers = true,
    bool symbols = true,
  });
  Future<BackupExportData> exportBackup({
    required String currentMasterPassword,
  });
  Future<bool> verifyBackupPassword(
    String filePath, {
    required String backupMasterPassword,
  });
  Future<int> importBackup(
    String filePath, {
    required String backupMasterPassword,
  });
}
