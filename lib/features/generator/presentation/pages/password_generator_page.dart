import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/providers/app_providers.dart';

class PasswordGeneratorPage extends ConsumerStatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  ConsumerState<PasswordGeneratorPage> createState() =>
      _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState
    extends ConsumerState<PasswordGeneratorPage> {
  double _length = 20;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _symbols = true;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passwordGenerator)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _password,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('${l10n.length}: ${_length.round()}'),
          Slider(
            value: _length,
            min: 8,
            max: 32,
            divisions: 24,
            label: _length.round().toString(),
            onChanged: (value) {
              setState(() => _length = value);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: Text(l10n.uppercase),
            value: _uppercase,
            onChanged: (value) {
              setState(() => _uppercase = value);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: Text(l10n.lowercase),
            value: _lowercase,
            onChanged: (value) {
              setState(() => _lowercase = value);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: Text(l10n.numbers),
            value: _numbers,
            onChanged: (value) {
              setState(() => _numbers = value);
              _regenerate();
            },
          ),
          SwitchListTile(
            title: Text(l10n.symbols),
            value: _symbols,
            onChanged: (value) {
              setState(() => _symbols = value);
              _regenerate();
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _regenerate,
            child: Text(l10n.regenerate),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_password),
            child: Text(l10n.useThisPassword),
          ),
        ],
      ),
    );
  }

  void _regenerate() {
    final repository = ref.read(credentialRepositoryProvider);
    try {
      final generated = repository.generatePassword(
        length: _length.round(),
        uppercase: _uppercase,
        lowercase: _lowercase,
        numbers: _numbers,
        symbols: _symbols,
      );
      setState(() => _password = generated);
    } catch (_) {
      setState(
        () => _password = AppLocalizations.of(context).selectAtLeastOneOption,
      );
    }
  }
}
