import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import '../storage/secure_key_storage.dart';

class VaultMetaRecord {
  VaultMetaRecord({
    required this.id,
    required this.kdfAlgorithm,
    required this.kdfMemoryKb,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.saltBase64,
    required this.wrappedVaultKeyBase64,
    required this.vaultVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultMetaRecord.fromRow(Map<String, Object?> row) {
    return VaultMetaRecord(
      id: row['id'] as String,
      kdfAlgorithm: row['master_password_kdf'] as String,
      kdfMemoryKb: row['kdf_memory_kb'] as int,
      kdfIterations: row['kdf_iterations'] as int,
      kdfParallelism: row['kdf_parallelism'] as int,
      saltBase64: row['salt_base64'] as String,
      wrappedVaultKeyBase64: row['wrapped_vault_key_base64'] as String,
      vaultVersion: row['vault_version'] as int,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
    );
  }

  final String id;
  final String kdfAlgorithm;
  final int kdfMemoryKb;
  final int kdfIterations;
  final int kdfParallelism;
  final String saltBase64;
  final String wrappedVaultKeyBase64;
  final int vaultVersion;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'master_password_kdf': kdfAlgorithm,
      'kdf_memory_kb': kdfMemoryKb,
      'kdf_iterations': kdfIterations,
      'kdf_parallelism': kdfParallelism,
      'salt_base64': saltBase64,
      'wrapped_vault_key_base64': wrappedVaultKeyBase64,
      'vault_version': vaultVersion,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class VaultSetupResult {
  VaultSetupResult({
    required this.vaultMetaRecord,
    required this.biometricEnvelope,
  });

  final Map<String, Object?> vaultMetaRecord;
  final String? biometricEnvelope;
}

abstract class CryptoService {
  bool get isUnlocked;
  Future<VaultSetupResult> createVaultSetup(String masterPassword);
  Future<bool> verifyMasterPassword({
    required String masterPassword,
    required VaultMetaRecord vaultMeta,
  });
  Future<bool> unlock({
    required String masterPassword,
    required VaultMetaRecord vaultMeta,
  });
  Future<Map<String, Object?>> changeMasterPassword({
    required String currentMasterPassword,
    required String newMasterPassword,
    required VaultMetaRecord vaultMeta,
  });
  Future<Map<String, Object?>> createPasswordVerifier(String password);
  Future<bool> verifyPasswordWithVerifier({
    required String password,
    required Map<String, dynamic> verifier,
  });
  Future<List<int>> encryptToBytes(String plaintext);
  Future<String> decryptFromBytes(List<int> ciphertext);
  Future<List<int>> encryptWithPassword({
    required String plaintext,
    required String password,
  });
  Future<String> decryptWithPassword({
    required List<int> ciphertext,
    required String password,
  });
  Future<void> lock();
  Future<String> createBiometricEnvelope();
  Future<bool> unlockWithBiometricEnvelope(String envelope);
}

class CryptoServiceImpl implements CryptoService {
  CryptoServiceImpl({
    required SecureKeyStorage secureKeyStorage,
  }) : _secureKeyStorage = secureKeyStorage;

  final SecureKeyStorage _secureKeyStorage;
  final Cipher _cipher = AesGcm.with256bits();
  final Random _random = Random.secure();

  Uint8List? _vaultKeyBytes;

  @override
  bool get isUnlocked => _vaultKeyBytes != null;

  @override
  Future<VaultSetupResult> createVaultSetup(String masterPassword) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final salt = _randomBytes(16);
    final vaultKey = _randomBytes(32);
    final derivedKey = await _deriveKey(
      masterPassword: masterPassword,
      salt: salt,
      iterations: 120000,
      bits: 256,
    );
    final wrappedPayload = await _encryptBytes(
      plaintext: vaultKey,
      secretKey: derivedKey,
    );
    _vaultKeyBytes = vaultKey;

    return VaultSetupResult(
      vaultMetaRecord: VaultMetaRecord(
        id: 'default_vault',
        kdfAlgorithm: 'pbkdf2_sha256',
        kdfMemoryKb: 0,
        kdfIterations: 120000,
        kdfParallelism: 1,
        saltBase64: base64Encode(salt),
        wrappedVaultKeyBase64: base64Encode(utf8.encode(wrappedPayload)),
        vaultVersion: 1,
        createdAt: now,
        updatedAt: now,
      ).toRow(),
      biometricEnvelope: base64Encode(vaultKey),
    );
  }

  @override
  Future<bool> verifyMasterPassword({
    required String masterPassword,
    required VaultMetaRecord vaultMeta,
  }) async {
    try {
      await _unwrapVaultKey(
        masterPassword: masterPassword,
        vaultMeta: vaultMeta,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> unlock({
    required String masterPassword,
    required VaultMetaRecord vaultMeta,
  }) async {
    try {
      final vaultKey = await _unwrapVaultKey(
        masterPassword: masterPassword,
        vaultMeta: vaultMeta,
      );
      _vaultKeyBytes = Uint8List.fromList(vaultKey);
      return true;
    } catch (_) {
      _vaultKeyBytes = null;
      return false;
    }
  }

  @override
  Future<Map<String, Object?>> changeMasterPassword({
    required String currentMasterPassword,
    required String newMasterPassword,
    required VaultMetaRecord vaultMeta,
  }) async {
    final currentVaultKey = _vaultKeyBytes;
    if (currentVaultKey == null) {
      throw StateError('Vault is locked');
    }

    final unwrappedVaultKey = await _unwrapVaultKey(
      masterPassword: currentMasterPassword,
      vaultMeta: vaultMeta,
    );

    if (!_constantTimeEquals(unwrappedVaultKey, currentVaultKey)) {
      throw StateError('Invalid current password');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final salt = _randomBytes(16);
    final derivedKey = await _deriveKey(
      masterPassword: newMasterPassword,
      salt: salt,
      iterations: vaultMeta.kdfIterations,
      bits: 256,
    );
    final wrappedPayload = await _encryptBytes(
      plaintext: currentVaultKey,
      secretKey: derivedKey,
    );

    return VaultMetaRecord(
      id: vaultMeta.id,
      kdfAlgorithm: vaultMeta.kdfAlgorithm,
      kdfMemoryKb: vaultMeta.kdfMemoryKb,
      kdfIterations: vaultMeta.kdfIterations,
      kdfParallelism: vaultMeta.kdfParallelism,
      saltBase64: base64Encode(salt),
      wrappedVaultKeyBase64: base64Encode(utf8.encode(wrappedPayload)),
      vaultVersion: vaultMeta.vaultVersion,
      createdAt: vaultMeta.createdAt,
      updatedAt: now,
    ).toRow();
  }

  @override
  Future<Map<String, Object?>> createPasswordVerifier(String password) async {
    final salt = _randomBytes(16);
    const iterations = 120000;
    final derivedKey = await _deriveKey(
      masterPassword: password,
      salt: salt,
      iterations: iterations,
      bits: 256,
    );
    final derivedBytes = await derivedKey.extractBytes();

    return {
      'kdf': 'pbkdf2_sha256',
      'iter': iterations,
      'salt': base64Encode(salt),
      'digest': base64Encode(derivedBytes),
    };
  }

  @override
  Future<bool> verifyPasswordWithVerifier({
    required String password,
    required Map<String, dynamic> verifier,
  }) async {
    try {
      final salt = base64Decode(verifier['salt'] as String);
      final iterations = verifier['iter'] as int;
      final expected = base64Decode(verifier['digest'] as String);
      final derivedKey = await _deriveKey(
        masterPassword: password,
        salt: salt,
        iterations: iterations,
        bits: 256,
      );
      final actual = await derivedKey.extractBytes();
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<int>> encryptToBytes(String plaintext) async {
    final key = _sessionKey();
    final payload = await _encryptBytes(
      plaintext: utf8.encode(plaintext),
      secretKey: key,
    );
    return utf8.encode(payload);
  }

  @override
  Future<String> decryptFromBytes(List<int> ciphertext) async {
    final key = _sessionKey();
    final payload = utf8.decode(ciphertext);
    final bytes = await _decryptBytes(
      encodedPayload: payload,
      secretKey: key,
    );
    return utf8.decode(bytes);
  }

  @override
  Future<List<int>> encryptWithPassword({
    required String plaintext,
    required String password,
  }) async {
    final salt = _randomBytes(16);
    const iterations = 120000;
    final derivedKey = await _deriveKey(
      masterPassword: password,
      salt: salt,
      iterations: iterations,
      bits: 256,
    );
    final payload = await _encryptBytes(
      plaintext: utf8.encode(plaintext),
      secretKey: derivedKey,
    );

    return utf8.encode(
      jsonEncode({
        'v': 1,
        'kdf': 'pbkdf2_sha256',
        'iter': iterations,
        'salt': base64Encode(salt),
        'payload': payload,
      }),
    );
  }

  @override
  Future<String> decryptWithPassword({
    required List<int> ciphertext,
    required String password,
  }) async {
    final envelope = jsonDecode(utf8.decode(ciphertext)) as Map<String, dynamic>;
    final salt = base64Decode(envelope['salt'] as String);
    final iterations = envelope['iter'] as int;
    final derivedKey = await _deriveKey(
      masterPassword: password,
      salt: salt,
      iterations: iterations,
      bits: 256,
    );
    final payload = envelope['payload'] as String;
    final bytes = await _decryptBytes(
      encodedPayload: payload,
      secretKey: derivedKey,
    );
    return utf8.decode(bytes);
  }

  @override
  Future<void> lock() async {
    _vaultKeyBytes = null;
    await _secureKeyStorage.deleteSessionMaterial();
  }

  @override
  Future<String> createBiometricEnvelope() async {
    if (!isUnlocked) {
      throw StateError('Vault is locked');
    }
    return base64Encode(_vaultKeyBytes!);
  }

  @override
  Future<bool> unlockWithBiometricEnvelope(String envelope) async {
    if (envelope.isEmpty) {
      return false;
    }
    try {
      _vaultKeyBytes = Uint8List.fromList(base64Decode(envelope));
      return _vaultKeyBytes!.isNotEmpty;
    } catch (_) {
      _vaultKeyBytes = null;
      return false;
    }
  }

  SecretKey _sessionKey() {
    final vaultKeyBytes = _vaultKeyBytes;
    if (vaultKeyBytes == null) {
      throw StateError('Vault is locked');
    }
    return SecretKey(vaultKeyBytes);
  }

  Future<SecretKey> _deriveKey({
    required String masterPassword,
    required List<int> salt,
    required int iterations,
    required int bits,
  }) {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: bits,
    );

    return algorithm.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );
  }

  Future<String> _encryptBytes({
    required List<int> plaintext,
    required SecretKey secretKey,
  }) async {
    final nonce = _randomBytes(12);
    final secretBox = await _cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    return jsonEncode({
      'v': 1,
      'alg': 'aes-256-gcm',
      'n': base64Encode(secretBox.nonce),
      'c': base64Encode(secretBox.cipherText),
      'm': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<List<int>> _decryptBytes({
    required String encodedPayload,
    required SecretKey secretKey,
  }) async {
    final Map<String, dynamic> payload = jsonDecode(encodedPayload);
    final secretBox = SecretBox(
      base64Decode(payload['c'] as String),
      nonce: base64Decode(payload['n'] as String),
      mac: Mac(base64Decode(payload['m'] as String)),
    );

    return _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  Future<List<int>> _unwrapVaultKey({
    required String masterPassword,
    required VaultMetaRecord vaultMeta,
  }) async {
    final salt = base64Decode(vaultMeta.saltBase64);
    final derivedKey = await _deriveKey(
      masterPassword: masterPassword,
      salt: salt,
      iterations: vaultMeta.kdfIterations,
      bits: 256,
    );
    final wrappedPayloadJson = utf8.decode(
      base64Decode(vaultMeta.wrappedVaultKeyBase64),
    );

    return _decryptBytes(
      encodedPayload: wrappedPayloadJson,
      secretKey: derivedKey,
    );
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < left.length; i++) {
      result |= left[i] ^ right[i];
    }
    return result == 0;
  }

  Uint8List _randomBytes(int length) {
    final values = List<int>.generate(length, (_) => _random.nextInt(256));
    return Uint8List.fromList(values);
  }
}
