import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: bootstrap.providerOverrides,
      child: const PasswordManagerApp(),
    ),
  );
}
