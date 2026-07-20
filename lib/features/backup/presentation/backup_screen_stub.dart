import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// Web/other-platform stub: backup is a native-only feature, so this screen just
/// explains it isn't available here. Imports nothing native (no `dart:io`).
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key, this.launchedForUpdate = false});

  /// Accepted for signature parity with the native screen; backup is native-only
  /// so there is nothing to launch-for-update here.
  final bool launchedForUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            l10n.restoreComingSoon,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
