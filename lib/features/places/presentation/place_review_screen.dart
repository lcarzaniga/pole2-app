import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../possessions/application/possession_providers.dart';
import '../application/place_providers.dart';
import '../application/place_review_session.dart';
import 'place_picker.dart';
import 'widgets/review_card.dart';

/// "Riordina questo luogo": a calm, guided walk through a place's possessions,
/// one at a time. The user keeps, moves, unassigns or archives each thing — no
/// progress bar, no completion pressure, and leaving at any moment is fine.
///
/// The current item is chosen by [ReviewSession] (first live id not yet
/// handled), never by a numeric cursor, so the reactive list shrinking or
/// reordering under us never skips an item. Handled ids live only for this
/// screen instance; reopening starts a fresh walk on purpose.
class PlaceReviewScreen extends ConsumerStatefulWidget {
  const PlaceReviewScreen({super.key, required this.placeId});

  final String placeId;

  @override
  ConsumerState<PlaceReviewScreen> createState() => _PlaceReviewScreenState();
}

class _PlaceReviewScreenState extends ConsumerState<PlaceReviewScreen> {
  final ReviewSession _session = ReviewSession();

  /// True while an async mutation is in flight — gates every action so a rapid
  /// second tap can't fire a duplicate write or advance twice.
  bool _busy = false;

  /// Guards the "place deleted while open" auto-exit so it runs once.
  bool _exiting = false;

  String get _placeId => widget.placeId;

  void _leave() {
    final router = GoRouter.of(context);
    if (router.canPop()) router.pop();
  }

  void _scheduleExit() {
    if (_exiting) return;
    _exiting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave();
    });
  }

  void _keep(String id) {
    if (_busy) return;
    setState(() => _session.markHandled(id));
  }

  Future<void> _move(Possession p) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);
    final fromPlaceId = _placeId;
    try {
      final choice = await showPlacePicker(
        context,
        currentPlaceId: fromPlaceId,
        disableCurrent: true,
      );
      // Cancelled, or "same place" — stay on this item, mark nothing handled.
      if (choice == null || choice.placeId == fromPlaceId) return;
      await dao.setPlace(p.id, choice.placeId);
      if (!mounted) return;
      setState(() => _session.markHandled(p.id));
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              choice.placeId == null
                  ? l10n.placeRemovedFromSnack
                  : l10n.placeMovedSnack,
            ),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => dao.setPlace(p.id, fromPlaceId),
            ),
          ),
        );
    } catch (_) {
      _showError(messenger, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unassign(Possession p) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);
    final fromPlaceId = _placeId;
    try {
      await dao.setPlace(p.id, null);
      if (!mounted) return;
      setState(() => _session.markHandled(p.id));
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.placeRemovedFromSnack),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => dao.setPlace(p.id, fromPlaceId),
            ),
          ),
        );
    } catch (_) {
      _showError(messenger, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive(Possession p) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);
    try {
      await dao.setStatus(p.id, PossessionStatus.archived);
      if (!mounted) return;
      setState(() => _session.markHandled(p.id));
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.archivedSnack),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => dao.restore(p.id),
            ),
          ),
        );
    } catch (_) {
      _showError(messenger, l10n);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Secondary "Altre opzioni" — keeps the four primary actions uncluttered.
  /// Offers lending and giving; both clear the place, so the item leaves this
  /// walk and is marked handled only on success, advancing safely by one.
  Future<void> _more(Possession p) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(l10n.lendToSomeone),
              onTap: () => Navigator.of(context).pop('lend'),
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: Text(l10n.giveToSomeone),
              onTap: () => Navigator.of(context).pop('give'),
            ),
          ],
        ),
      ),
    );
    if (action == 'lend') await _entrustVia(p, Routes.lendName);
    if (action == 'give') await _entrustVia(p, Routes.giveName);
  }

  /// Push a lend/give editor; only a successful save (pop `true`) marks the item
  /// handled and advances. Cancel/failure changes nothing and does not advance.
  Future<void> _entrustVia(Possession p, String routeName) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await context.pushNamed<bool>(
        routeName,
        pathParameters: {'id': p.id},
      );
      if (ok == true && mounted) setState(() => _session.markHandled(p.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(ScaffoldMessengerState messenger, AppLocalizations l10n) {
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.errorNothingLost),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeAsync = ref.watch(placeByIdProvider(_placeId));
    final itemsAsync = ref.watch(possessionsByPlaceProvider(_placeId));
    final place = placeAsync.value;

    // The place was deleted (or never resolved) while the review is open — leave
    // safely back to wherever we came from, never a broken or endless state.
    if (placeAsync.hasValue && place == null) {
      _scheduleExit();
      return Scaffold(
        appBar: AppBar(title: Text(l10n.placeLabel)),
        body: HexBackground(child: _Calm(l10n.goneMessage)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          place?.name ?? l10n.placeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: HexBackground(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Calm(l10n.errorNothingLost),
          data: (list) {
            final currentId = _session.currentId([for (final p in list) p.id]);
            if (currentId == null) {
              return ReviewComplete(onDone: _leave);
            }
            final current = list.firstWhere((p) => p.id == currentId);
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            return AnimatedSwitcher(
              // Instant under Reduce Motion; otherwise a brief, subtle fade.
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(currentId),
                child: ReviewCard(
                  possession: current,
                  placeName: place?.name,
                  count: list.length,
                  enabled: !_busy,
                  onKeep: () => _keep(currentId),
                  onMove: () => _move(current),
                  onUnassign: () => _unassign(current),
                  onArchive: () => _archive(current),
                  onMore: () => _more(current),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Calm extends StatelessWidget {
  const _Calm(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
