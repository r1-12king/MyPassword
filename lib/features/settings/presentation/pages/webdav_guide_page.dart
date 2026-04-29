import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class WebDavGuidePage extends StatelessWidget {
  const WebDavGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.webDavGuide)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GuideCard(
            title: l10n.webDavGuideWhatYouNeed,
            children: [
              _GuideBullet(text: l10n.webDavGuideNeedAccount),
              _GuideBullet(text: l10n.webDavGuideNeedAppPassword),
              _GuideBullet(text: l10n.webDavGuideNeedAddress),
            ],
          ),
          const SizedBox(height: 16),
          _GuideCard(
            title: l10n.webDavGuideJianguoyunExample,
            children: [
              _GuideField(
                label: l10n.webDavBaseUrl,
                value: 'https://dav.jianguoyun.com/dav/',
              ),
              _GuideField(
                label: l10n.webDavUsername,
                value: l10n.webDavGuideUsernameHint,
              ),
              _GuideField(
                label: l10n.webDavPassword,
                value: l10n.webDavGuidePasswordHint,
              ),
              _GuideField(
                label: l10n.webDavRemotePath,
                value: '/MyPassword/vault_sync.mpsync',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GuideCard(
            title: l10n.webDavGuideHowToGetPassword,
            children: [
              _GuideBullet(text: l10n.webDavGuideStepOpenJianguoyun),
              _GuideBullet(text: l10n.webDavGuideStepSecurity),
              _GuideBullet(text: l10n.webDavGuideStepAppPassword),
              _GuideBullet(text: l10n.webDavGuideStepPastePassword),
            ],
          ),
          const SizedBox(height: 16),
          _GuideCard(
            title: l10n.webDavGuideUsageFlow,
            children: [
              _GuideBullet(text: l10n.webDavGuideFlowConfig),
              _GuideBullet(text: l10n.webDavGuideFlowTest),
              _GuideBullet(text: l10n.webDavGuideFlowUpload),
              _GuideBullet(text: l10n.webDavGuideFlowRestore),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.webDavGuideTip,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  const _GuideBullet({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _GuideField extends StatelessWidget {
  const _GuideField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
