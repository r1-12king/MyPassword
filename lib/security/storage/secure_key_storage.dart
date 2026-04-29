import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureKeyStorage {
  Future<void> writeBiometricEnvelope(String value);
  Future<String?> readBiometricEnvelope();
  Future<void> deleteBiometricEnvelope();
  Future<void> writeWebDavAppPassword(String value);
  Future<String?> readWebDavAppPassword();
  Future<void> deleteWebDavAppPassword();
  Future<void> writeSessionMaterial(String value);
  Future<String?> readSessionMaterial();
  Future<void> deleteSessionMaterial();
  Future<void> clearAll();
}

class SecureKeyStorageImpl implements SecureKeyStorage {
  SecureKeyStorageImpl({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _biometricEnvelopeKey = 'secure.biometric_envelope';
  static const _webDavAppPasswordKey = 'secure.webdav_app_password';
  static const _sessionMaterialKey = 'secure.session_material';

  @override
  Future<void> writeBiometricEnvelope(String value) {
    return _storage.write(key: _biometricEnvelopeKey, value: value);
  }

  @override
  Future<String?> readBiometricEnvelope() {
    return _storage.read(key: _biometricEnvelopeKey);
  }

  @override
  Future<void> deleteBiometricEnvelope() {
    return _storage.delete(key: _biometricEnvelopeKey);
  }

  @override
  Future<void> writeWebDavAppPassword(String value) {
    return _storage.write(key: _webDavAppPasswordKey, value: value);
  }

  @override
  Future<String?> readWebDavAppPassword() {
    return _storage.read(key: _webDavAppPasswordKey);
  }

  @override
  Future<void> deleteWebDavAppPassword() {
    return _storage.delete(key: _webDavAppPasswordKey);
  }

  @override
  Future<void> writeSessionMaterial(String value) {
    return _storage.write(key: _sessionMaterialKey, value: value);
  }

  @override
  Future<String?> readSessionMaterial() {
    return _storage.read(key: _sessionMaterialKey);
  }

  @override
  Future<void> deleteSessionMaterial() {
    return _storage.delete(key: _sessionMaterialKey);
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: _biometricEnvelopeKey);
    await _storage.delete(key: _webDavAppPasswordKey);
    await _storage.delete(key: _sessionMaterialKey);
  }
}
