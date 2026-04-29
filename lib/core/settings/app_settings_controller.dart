import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VaultLockMode {
  onAppExit,
  onBackground,
}

class AppSettingsState {
  const AppSettingsState({
    this.exportDirectoryUri,
    this.exportDirectoryLabel,
    this.vaultLockMode = VaultLockMode.onAppExit,
    this.autoSyncOnChange = false,
  });

  final String? exportDirectoryUri;
  final String? exportDirectoryLabel;
  final VaultLockMode vaultLockMode;
  final bool autoSyncOnChange;

  AppSettingsState copyWith({
    String? exportDirectoryUri,
    String? exportDirectoryLabel,
    bool clearExportDirectory = false,
    VaultLockMode? vaultLockMode,
    bool? autoSyncOnChange,
  }) {
    return AppSettingsState(
      exportDirectoryUri: clearExportDirectory
          ? null
          : (exportDirectoryUri ?? this.exportDirectoryUri),
      exportDirectoryLabel: clearExportDirectory
          ? null
          : (exportDirectoryLabel ?? this.exportDirectoryLabel),
      vaultLockMode: vaultLockMode ?? this.vaultLockMode,
      autoSyncOnChange: autoSyncOnChange ?? this.autoSyncOnChange,
    );
  }
}

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
  throw UnimplementedError();
});

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController({
    required SharedPreferences preferences,
  })  : _preferences = preferences,
        super(_readInitialState(preferences));

  final SharedPreferences _preferences;

  AppSettingsState get currentState => state;

  static const _exportDirectoryUriKey = 'settings.export_directory_uri';
  static const _exportDirectoryLabelKey = 'settings.export_directory_label';
  static const _vaultLockModeKey = 'settings.vault_lock_mode';
  static const _autoSyncOnChangeKey = 'settings.auto_sync_on_change';

  static AppSettingsState _readInitialState(SharedPreferences preferences) {
    final exportDirectoryUri = preferences.getString(_exportDirectoryUriKey);
    final exportDirectoryLabel = preferences.getString(_exportDirectoryLabelKey);
    final lockModeValue = preferences.getString(_vaultLockModeKey);

    return AppSettingsState(
      exportDirectoryUri: exportDirectoryUri == null || exportDirectoryUri.isEmpty
          ? null
          : exportDirectoryUri,
      exportDirectoryLabel:
          exportDirectoryLabel == null || exportDirectoryLabel.isEmpty
              ? null
              : exportDirectoryLabel,
      vaultLockMode: lockModeValue == VaultLockMode.onBackground.name
          ? VaultLockMode.onBackground
          : VaultLockMode.onAppExit,
      autoSyncOnChange: preferences.getBool(_autoSyncOnChangeKey) ?? false,
    );
  }

  Future<void> setExportDirectory({
    required String uri,
    required String label,
  }) async {
    state = state.copyWith(
      exportDirectoryUri: uri,
      exportDirectoryLabel: label,
    );
    await _preferences.setString(_exportDirectoryUriKey, uri);
    await _preferences.setString(_exportDirectoryLabelKey, label);
  }

  Future<void> setVaultLockMode(VaultLockMode mode) async {
    state = state.copyWith(vaultLockMode: mode);
    await _preferences.setString(_vaultLockModeKey, mode.name);
  }

  Future<void> setAutoSyncOnChange(bool enabled) async {
    state = state.copyWith(autoSyncOnChange: enabled);
    await _preferences.setBool(_autoSyncOnChangeKey, enabled);
  }
}
