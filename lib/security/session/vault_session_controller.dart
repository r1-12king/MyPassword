import 'package:flutter_riverpod/flutter_riverpod.dart';

class VaultSessionState {
  const VaultSessionState({
    this.masterPassword,
  });

  final String? masterPassword;

  bool get hasMasterPassword =>
      masterPassword != null && masterPassword!.trim().isNotEmpty;

  VaultSessionState copyWith({
    String? masterPassword,
    bool clearMasterPassword = false,
  }) {
    return VaultSessionState(
      masterPassword:
          clearMasterPassword ? null : (masterPassword ?? this.masterPassword),
    );
  }
}

class VaultSessionController extends StateNotifier<VaultSessionState> {
  VaultSessionController() : super(const VaultSessionState());

  String? get currentMasterPassword => state.masterPassword;

  void setMasterPassword(String value) {
    final trimmed = value.trim();
    state = state.copyWith(
      masterPassword: trimmed.isEmpty ? null : trimmed,
    );
  }

  void clear() {
    state = state.copyWith(clearMasterPassword: true);
  }
}
