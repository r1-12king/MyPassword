import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_locale_controller.dart';
import '../core/localization/app_localizations.dart';
import '../core/settings/app_settings_controller.dart';
import '../shared/providers/app_providers.dart';
import 'router/app_router.dart';

class PasswordManagerApp extends ConsumerStatefulWidget {
  const PasswordManagerApp({super.key});

  @override
  ConsumerState<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends ConsumerState<PasswordManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final vaultRepository = ref.read(vaultRepositoryProvider);
      if (ref.read(appSettingsControllerProvider).vaultLockMode ==
              VaultLockMode.onBackground &&
          ref.read(vaultRepositoryProvider).hasVaultCached &&
          !vaultRepository.isUnlocked) {
        ref.read(appRouterProvider).go('/lock');
      }
      return;
    }

    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) {
      return;
    }

    final settings = ref.read(appSettingsControllerProvider);
    if (settings.vaultLockMode != VaultLockMode.onBackground) {
      return;
    }

    final vaultRepository = ref.read(vaultRepositoryProvider);
    if (!vaultRepository.isUnlocked) {
      return;
    }

    vaultRepository.lockVault();
    ref.read(vaultSessionControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
    );
  }
}
