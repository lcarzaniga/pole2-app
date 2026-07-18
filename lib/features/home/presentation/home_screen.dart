import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/brand/turtle_shell_menu.dart';
import '../../../shared/photo_capture.dart';
import '../../possessions/application/possession_providers.dart';
import '../../possessions/presentation/possessions_home_view.dart';
import '../../update/update_gate.dart';
import 'widgets/home_empty_state.dart';

/// The home screen — the digital home's front door.
///
/// Reacts to the possessions stream: no possessions yet → the calm first-run
/// empty state; otherwise → the list. Both share the persistent [AppShell] and
/// route quick-actions through the same handler (only "New Possession" is wired
/// this milestone; the rest are calm placeholders).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final possessions = ref.watch(possessionListProvider);
    final l10n = AppLocalizations.of(context);

    Future<void> handleQuickAction(QuickAction action) async {
      // "Un oggetto" opens the full creation flow; "Una foto" captures first,
      // then starts a new thing from that photo. The rest are calm placeholders
      // that point back to what the user can do now.
      switch (action) {
        case QuickAction.object:
          context.pushNamed(Routes.newPossessionName);
          return;
        case QuickAction.photo:
          final photo = await chooseAndCapturePhoto(context);
          if (photo == null || !context.mounted) return;
          context.pushNamed(Routes.newPossessionName, extra: photo);
          return;
        case QuickAction.document:
        case QuickAction.reminder:
        case QuickAction.note:
        case QuickAction.detail:
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                content: Text(l10n.quickActionSoon),
              ),
            );
      }
    }

    // Non-blocking self-update check runs once here (below the navigator, so the
    // optional prompt can be shown). The gate renders its child unchanged.
    return UpdateGate(
      child: AppShell(
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'archive') context.pushNamed(Routes.archiveName);
              if (value == 'places') context.pushNamed(Routes.placesName);
              if (value == 'backup') context.pushNamed(Routes.backupName);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'places', child: Text(l10n.placesMenu)),
              PopupMenuItem(value: 'archive', child: Text(l10n.archiveMenu)),
              PopupMenuItem(value: 'backup', child: Text(l10n.backupMenu)),
            ],
          ),
        ],
        body: HexBackground(
          child: possessions.when(
            loading: () => const _CalmCenter(),
            error: (_, _) => _CalmCenter(message: l10n.errorNothingLost),
            data: (list) => list.isEmpty
                ? HomeEmptyState(onQuickAction: handleQuickAction)
                : PossessionsHomeView(
                    possessions: list,
                    onQuickAction: handleQuickAction,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A quiet centered state for loading / recoverable error — never alarming.
class _CalmCenter extends StatelessWidget {
  const _CalmCenter({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: message == null
          ? const SizedBox.square(
              dimension: AppSpacing.xl,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}
