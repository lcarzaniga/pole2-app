import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/brand/turtle_shell_menu.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/photo_capture.dart';
import '../../backup/restore/restore_confirm.dart';
import '../../backup/restore/restore_receipt.dart';
import '../../possessions/application/possession_providers.dart';
import '../../possessions/presentation/possessions_home_view.dart';
import '../../update/update_gate.dart';
import 'widgets/home_empty_state.dart';

/// Confirms a freshly restored install and then reports its outcome once.
///
/// The pre-DB swap only records an *unconfirmed* install. Here — after the
/// normal app has started — we run a real read through the normal Drift provider
/// (proving open + migrations + query all work) to confirm the restore, which
/// writes the one-time success receipt. If nothing is pending this is a cheap
/// no-op; if the app was actually broken, the probe fails and the next launch
/// rolls back. Then the receipt (success from here, or rollback from a previous
/// startup) is consumed exactly once and surfaced calmly on Home.
final _restoreReceiptProvider = FutureProvider<String?>((ref) async {
  final db = ref.read(databaseProvider);
  await confirmRestoreIfPending(
    probe: () async {
      // Minimal known-safe read through the normal Drift database: forces open,
      // migrations and open callbacks, then touches a real restored table.
      await db.customSelect('SELECT COUNT(*) FROM possessions').get();
      return true;
    },
  );
  return consumeRestoreReceipt();
});

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

    // Show the post-restore outcome once, when its receipt resolves.
    ref.listen(_restoreReceiptProvider, (prev, next) {
      final status = next.value;
      if (status == null) return;
      final msg = status == 'success'
          ? l10n.restoreDoneMessage
          : l10n.restoreFailedMessage;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
        );
    });

    // Guards against a rapid double-tap opening two creation routes or two photo
    // pickers. Held for the whole navigation (awaited), reset when Home is next
    // active. Both paths create the same entity — an object — differing only in
    // how the user starts.
    var launching = false;
    Future<void> handleQuickAction(QuickAction action) async {
      if (launching) return;
      launching = true;
      try {
        switch (action) {
          case QuickAction.object:
            // "Dal nome": the normal title-first creation flow, no photo.
            await context.pushNamed(Routes.newPossessionName);
          case QuickAction.photo:
            // "Dalla foto": capture (camera/gallery) first, then create with the
            // photo already attached. A cancelled capture creates nothing.
            final photo = await chooseAndCapturePhoto(context);
            if (photo == null || !context.mounted) return;
            await context.pushNamed(Routes.newPossessionName, extra: photo);
        }
      } finally {
        launching = false;
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
              if (value == 'people') context.pushNamed(Routes.peopleName);
              if (value == 'backup') context.pushNamed(Routes.backupName);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'places', child: Text(l10n.placesMenu)),
              PopupMenuItem(value: 'people', child: Text(l10n.peopleMenu)),
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
