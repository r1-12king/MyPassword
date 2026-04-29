import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLocaleControllerProvider =
    StateNotifierProvider<AppLocaleController, Locale?>((ref) {
  throw UnimplementedError();
});

class AppLocaleController extends StateNotifier<Locale?> {
  AppLocaleController({
    required SharedPreferences preferences,
  })  : _preferences = preferences,
        super(_readInitialLocale(preferences));

  final SharedPreferences _preferences;

  static const _key = 'app_locale';

  static Locale? _readInitialLocale(SharedPreferences preferences) {
    final languageCode = preferences.getString(_key);
    if (languageCode == null || languageCode.isEmpty) {
      return null;
    }
    return Locale(languageCode);
  }

  Future<void> useSystem() async {
    state = null;
    await _preferences.remove(_key);
  }

  Future<void> setEnglish() async {
    state = const Locale('en');
    await _preferences.setString(_key, 'en');
  }

  Future<void> setChinese() async {
    state = const Locale('zh');
    await _preferences.setString(_key, 'zh');
  }
}
