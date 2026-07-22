import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/brand_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/evidence_dao.dart';
import '../../../core/database/daos/possessions_dao.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../media/document_store.dart';
import '../media/document_pick.dart';
import '../media/record_flow.dart';
import '../media/photo_import_flow.dart';
import 'record_category_ui.dart';
import '../../../shared/phrasing.dart';
import '../../../shared/platform/photo_store.dart';
import '../../places/application/place_providers.dart';
import '../../places/presentation/place_picker.dart';
import '../application/archive_query.dart';
import '../application/event_providers.dart';
import '../application/gallery_order.dart';
import '../application/permanent_delete.dart';
import '../application/permanent_delete_result.dart';
import '../application/possession_providers.dart';
import 'lend_editor_screen.dart';
import 'reacquire_sheet.dart';
import 'return_sheet.dart';
import 'widgets/cover_area.dart';
import 'widgets/custody_card.dart';
import 'widgets/gallery_strip.dart';

/// A single thing, living inside Pole² — its dossier.
///
/// At a glance: what this is, when/where it was acquired, what it cost, and
/// what's coming next. Everything reactive; every editable thing is undoable or
/// safely re-editable.
class PossessionDetailScreen extends ConsumerWidget {
  const PossessionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final possession = ref.watch(possessionByIdProvider(id));
    final l10n = AppLocalizations.of(context);

    final p = possession.value;
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Rename/archive/remove only make sense for a live, active thing.
          if (p != null && !_isInactive(p)) _MoreMenu(id: id, possession: p),
        ],
      ),
      body: HexBackground(
        child: possession.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Calm(l10n.errorNothingLost),
          data: (p) =>
              p == null ? _Calm(l10n.goneMessage) : _Dossier(possession: p),
        ),
      ),
    );
  }
}

/// True when a thing has left normal use — soft-deleted, or any lifecycle
/// status other than active. Such a thing is consulted read-only in Archivio;
/// enrichment/state-changing actions are withheld until it is restored.
bool _isInactive(Possession p) =>
    p.deletedAt != null || p.status != PossessionStatus.active;

class _Dossier extends ConsumerWidget {
  const _Dossier({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final id = possession.id;
    final inactive = _isInactive(possession);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Cover(possession: possession, inactive: inactive),
        _Gallery(possession: possession, inactive: inactive),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      possession.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  // Renaming is enrichment — withheld until restored.
                  if (!inactive)
                    IconButton(
                      tooltip: l10n.renameTooltip,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: AppIconSize.md,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _rename(context, ref, possession),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.keptOn(formatDate(possession.createdAt, l10n.localeName)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (inactive) ...[
                const SizedBox(height: AppSpacing.lg),
                _StatusBanner(possession: possession),
                const SizedBox(height: AppSpacing.md),
                _PlaceCard(possession: possession, inactive: true),
              ] else ...[
                _NextGlance(id: id),
                const SizedBox(height: AppSpacing.lg),
                _ActionHub(possession: possession),
                const SizedBox(height: AppSpacing.xl),
                _Custody(possession: possession),
                const SizedBox(height: AppSpacing.md),
                _PlaceCard(possession: possession),
              ],
              const SizedBox(height: AppSpacing.md),
              _DetailsCard(id: id),
              const SizedBox(height: AppSpacing.md),
              _HistoryCard(id: id),
            ],
          ),
        ),
      ],
    );
  }
}

/// The calm banner shown when consulting an inactive/removed thing: what state
/// it is in, a reminder that it is read-only, and a single "Ripristina" that
/// honours the status ≠ deletion distinction (removed → keep prior status;
/// kept-aside → back to active).
class _StatusBanner extends ConsumerWidget {
  const _StatusBanner({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final removed = possession.deletedAt != null;
    // A given (transferred) thing that isn't removed gets its own banner: who
    // has it, when, and a *distinct* reacquisition action (not generic restore).
    final given = !removed && possession.status == PossessionStatus.transferred;
    final transfer = given
        ? ref.watch(activeTransferProvider(possession.id)).value
        : null;
    final recipient = transfer?.partyId == null
        ? null
        : ref.watch(partyProvider(transfer!.partyId!)).value;

    final label = removed
        ? l10n.removedBannerTitle
        : given
        ? l10n.givenToPerson(recipient?.name ?? '—')
        : lifecycleLabel(l10n, possession.status);
    final subline = given && transfer != null
        ? l10n.givenOn(formatDate(transfer.at, l10n.localeName))
        : l10n.inactiveReadOnlyHint;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadii.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                given
                    ? Icons.card_giftcard_outlined
                    : Icons.inventory_2_outlined,
                size: AppIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: given
                ? FilledButton.tonalIcon(
                    onPressed: transfer == null
                        ? null
                        : () => showReacquireSheet(
                            context,
                            possessionId: possession.id,
                            transfer: transfer,
                          ),
                    icon: const Icon(Icons.keyboard_return),
                    label: Text(l10n.reacquireAction),
                  )
                : removed
                // A removed thing can be restored, or — deliberately and
                // irreversibly — deleted for good. The permanent action is the
                // low-emphasis sibling of restore (never a red-filled button),
                // and lives only here, in the removed thing's own detail.
                ? Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _restore(context, ref, removed),
                        icon: const Icon(Icons.restore),
                        label: Text(l10n.archiveRestore),
                      ),
                      TextButton.icon(
                        onPressed: () => _permanentlyDelete(context, ref),
                        icon: const Icon(Icons.delete_forever_outlined),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          minimumSize: const Size(0, 48),
                        ),
                        label: Text(l10n.permanentDeleteAction),
                      ),
                    ],
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => _restore(context, ref, removed),
                    icon: const Icon(Icons.restore),
                    label: Text(l10n.archiveRestore),
                  ),
          ),
        ],
      ),
    );
  }

  /// Permanent, irreversible deletion of this removed thing: one calm, explicit
  /// confirmation (no name-typing, no countdown, no red flood), then the guarded
  /// coordinator. The result is reported honestly — including a partial
  /// file-cleanup outcome — and, on success, we leave the (now gone) detail.
  Future<void> _permanentlyDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final title = possession.title;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: const Icon(Icons.delete_forever_outlined),
          title: Text(l10n.permanentDeleteTitle(title)),
          content: Text(l10n.permanentDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.permanentDeleteCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(l10n.permanentDeleteConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final result = await permanentlyDeletePossession(ref, possession.id);
    if (!context.mounted) return;

    final gone =
        result.status == PermanentDeleteStatus.deleted ||
        result.status == PermanentDeleteStatus.deletedWithPendingFileCleanup;
    final message = switch (result.status) {
      PermanentDeleteStatus.deleted => l10n.permanentDeleteDoneSnack(title),
      PermanentDeleteStatus.deletedWithPendingFileCleanup =>
        l10n.permanentDeletePartialSnack(title),
      PermanentDeleteStatus.blockedByBackup =>
        l10n.permanentDeleteBlockedBackup,
      PermanentDeleteStatus.blockedByRestore =>
        l10n.permanentDeleteBlockedRestore,
      // staleSelection is a batch-only outcome; on the single path it cannot
      // occur, but the switch must stay exhaustive — treat it as a calm no-op.
      PermanentDeleteStatus.rejectedNotRemoved ||
      PermanentDeleteStatus.notFound ||
      PermanentDeleteStatus.staleSelection ||
      PermanentDeleteStatus.failedBeforeCommit =>
        l10n.permanentDeleteFailedSnack(title),
    };

    if (gone && router.canPop()) router.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    bool removed,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);
    if (removed) {
      await dao.restoreRemoved(possession.id);
    } else {
      await dao.restoreArchived(possession.id);
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            removed ? l10n.removedRestoredSnack : l10n.archiveRestoredSnack,
          ),
        ),
      );
  }
}

/// A calm one-line "what's next" cue, if a date is coming up.
class _NextGlance extends ConsumerWidget {
  const _NextGlance({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(timelineProvider(id)).value ?? const [];
    final upcoming =
        events
            .where((e) => e.kind == EventKind.reminder && daysUntil(e.at) >= 0)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final soon = daysUntil(next.at) <= 30;
    final color = soon
        ? context.brand.attention
        : theme.colorScheme.onSurfaceVariant;
    final what = '${next.title ?? ''} ${relativeDay(l10n, next.at)}'.trim();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.nextUp(what),
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The object detail's action hub: the most frequent things you do to a thing,
/// kept visible in one calm row so none hide behind a menu and each is a single
/// tap. The sections below are where those things are then seen.
class _ActionHub extends ConsumerWidget {
  const _ActionHub({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = possession.id;
    return Row(
      children: [
        _HubAction(
          icon: Icons.add_a_photo_outlined,
          label: l10n.hubPhoto,
          onTap: () => _addPhotos(context, ref, id),
        ),
        _HubAction(
          icon: Icons.sticky_note_2_outlined,
          label: l10n.hubNote,
          onTap: () =>
              context.pushNamed(Routes.noteName, pathParameters: {'id': id}),
        ),
        _HubAction(
          icon: Icons.event_outlined,
          label: l10n.hubDate,
          onTap: () => context.pushNamed(
            Routes.reminderName,
            pathParameters: {'id': id},
          ),
        ),
        _HubAction(
          icon: Icons.place_outlined,
          label: l10n.hubPlace,
          onTap: () => _pickPlace(context, ref, possession),
        ),
      ],
    );
  }
}

class _HubAction extends StatelessWidget {
  const _HubAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSize.md,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Details section — now the acquisition, in human words.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acq = ref.watch(acquisitionProvider(id)).value;
    final l10n = AppLocalizations.of(context);
    void onTap() =>
        context.pushNamed(Routes.acquisitionName, pathParameters: {'id': id});

    if (acq == null) {
      return _TapCard(
        icon: Icons.list_alt_outlined,
        title: l10n.detailsTitle,
        subtitle: l10n.detailsEmptySubtitle,
        onTap: onTap,
      );
    }

    final supplier = acq.partyId == null
        ? null
        : ref.watch(partyProvider(acq.partyId!)).value;
    final headline = acquisitionHeadline(
      l10n,
      acq.acquisitionType,
      supplier?.name,
    );
    final meta = <String>[
      if (acq.amountMinor != null)
        formatMoney(acq.amountMinor!, acq.currency, l10n.localeName),
      if (acq.purchasedOn != null)
        formatDate(acq.purchasedOn!, l10n.localeName),
    ].join(' · ');

    return _TapCard(
      icon: Icons.list_alt_outlined,
      title: headline,
      subtitle: meta.isEmpty ? l10n.tapToAddMore : meta,
      onTap: onTap,
      trailing: Icons.edit_outlined,
    );
  }
}

/// Custody: while lent, a calm card showing who has it and how to correct or
/// end the loan; otherwise a discoverable, secondary "Presta a qualcuno" action
/// (kept out of the Foto·Nota·Data·Luogo hub).
class _Custody extends ConsumerWidget {
  const _Custody({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loan = ref.watch(activeLoanProvider(possession.id)).value;

    if (loan == null) {
      return _TapCard(
        icon: Icons.people_alt_outlined,
        title: l10n.entrustToSomeone,
        subtitle: l10n.borrowerChoose,
        onTap: () => _entrust(context, possession.id),
      );
    }

    final borrower = loan.partyId == null
        ? null
        : ref.watch(partyProvider(loan.partyId!)).value;

    return CustodyCard(
      borrowerName: borrower?.name ?? '—',
      lentAt: loan.at,
      expectedReturn: loan.endsAt,
      hasReminder: loan.remindLead != null,
      onEdit: () => context.pushNamed(
        Routes.lendName,
        pathParameters: {'id': possession.id},
        extra: LendEditData(
          loanEventId: loan.id,
          borrowerName: borrower?.name ?? '',
          borrowerPartyId: loan.partyId,
          lentAt: loan.at,
          expectedReturn: loan.endsAt,
          lead: loan.remindLead,
        ),
      ),
      onReturn: () =>
          showReturnSheet(context, possessionId: possession.id, loan: loan),
    );
  }
}

/// Where this thing lives — always shown. When a place is assigned, tapping the
/// card opens that place's contents; a separate edit control changes / creates /
/// clears the place. When none is assigned, the card invites choosing one.
/// While the thing is lent, the place is calmly unavailable (it returns when the
/// object does), so we never claim it is in its old place.
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.possession, this.inactive = false});

  final Possession possession;
  final bool inactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Inactive/removed: show the retained place read-only (context, not an
    // invitation) — assigning is withheld until restored.
    if (inactive) {
      final pid = possession.placeId;
      final retained = pid == null
          ? null
          : ref.watch(placeByIdProvider(pid)).value;
      return _InfoCard(
        icon: Icons.place_outlined,
        title: retained?.name ?? l10n.noPlace,
        subtitle: l10n.placeLabel,
      );
    }

    // While lent, don't invite assigning a place (it would fight the loan).
    if (ref.watch(activeLoanProvider(possession.id)).value != null) {
      return _InfoCard(
        icon: Icons.place_outlined,
        title: l10n.noPlace,
        subtitle: l10n.cannotAssignPlaceWhileLent,
      );
    }

    final placeId = possession.placeId;
    // A deleted place resolves to null → treated as "no place" (invite choosing).
    final place = placeId == null
        ? null
        : ref.watch(placeByIdProvider(placeId)).value;

    if (place == null) {
      return _TapCard(
        icon: Icons.place_outlined,
        title: l10n.noPlace,
        subtitle: l10n.placeAssignHint,
        trailing: Icons.edit_outlined,
        onTap: () => _pickPlace(context, ref, possession),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadii.borderLg,
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.placeName,
          pathParameters: {'id': placeId!},
        ),
        borderRadius: AppRadii.borderLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: AppIconSize.md,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.placeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                iconSize: AppIconSize.md,
                color: scheme.onSurfaceVariant,
                tooltip: l10n.placeEditTooltip,
                onPressed: () => _pickPlace(context, ref, possession),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// History — acquisition and reminders, chronological, in human language.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(timelineProvider(id)).value ?? const [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.historyTitle, style: theme.textTheme.titleMedium),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.historyEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final e in events) _EventRow(event: e),
        ],
      ),
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.event});

  final PossessionEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    late final IconData icon;
    late final String title;
    Widget? trailing;
    Widget? whenLine;

    if (event.kind == EventKind.acquired) {
      icon = Icons.shopping_bag_outlined;
      final supplier = event.partyId == null
          ? null
          : ref.watch(partyProvider(event.partyId!)).value;
      title = acquisitionHeadline(l10n, event.acquisitionType, supplier?.name);
      final meta = <String>[
        if (event.amountMinor != null)
          formatMoney(event.amountMinor!, event.currency, l10n.localeName),
        if (event.purchasedOn != null)
          formatDate(event.purchasedOn!, l10n.localeName),
      ].join(' · ');
      if (meta.isNotEmpty) {
        whenLine = Text(
          meta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
      }
    } else if (event.kind == EventKind.lent) {
      icon = Icons.people_alt_outlined;
      final borrower = event.partyId == null
          ? null
          : ref.watch(partyProvider(event.partyId!)).value;
      title = l10n.lentToPerson(borrower?.name ?? '—');
      whenLine = Text(
        l10n.lentOn(formatDate(event.at, l10n.localeName)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (event.kind == EventKind.returned) {
      icon = Icons.assignment_turned_in_outlined;
      title = l10n.returnedOn(formatDate(event.at, l10n.localeName));
    } else if (event.kind == EventKind.transfer) {
      icon = Icons.card_giftcard_outlined;
      final recipient = event.partyId == null
          ? null
          : ref.watch(partyProvider(event.partyId!)).value;
      title = l10n.givenToPerson(recipient?.name ?? '—');
      final note = event.notes;
      whenLine = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.givenOn(formatDate(event.at, l10n.localeName)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (note != null && note.isNotEmpty)
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      );
    } else if (event.kind == EventKind.reacquired) {
      icon = Icons.keyboard_return;
      title = l10n.reacquiredTimeline;
      whenLine = Text(
        l10n.onDate(formatDate(event.at, l10n.localeName)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else if (event.kind == EventKind.note ||
        (isRecordKind(event.kind) && event.kind != EventKind.acquired)) {
      // M9 contextual records: the collapsed card shows the category label and
      // dates only — never the user's note/description text (that stays inside
      // the record, revealed when the card is tapped open).
      icon = recordCategoryIcon(event.kind);
      title = recordCategoryLabel(l10n, event.kind);
      whenLine = _recordWhen(l10n, theme, scheme, event);
      trailing = IconButton(
        tooltip: l10n.menuRemove,
        icon: Icon(
          Icons.close,
          size: AppIconSize.sm,
          color: scheme.onSurfaceVariant,
        ),
        onPressed: () => _removeEvent(context, ref, event.id),
      );
    } else {
      icon = Icons.event_outlined;
      title = event.title ?? l10n.addDate;
      final days = daysUntil(event.at);
      if (days >= 0) {
        // Upcoming or today — calm amber attention, never alarm.
        whenLine = _AttentionPill(text: relativeDay(l10n, event.at));
      } else {
        whenLine = Text(
          l10n.onDate(formatDate(event.at, l10n.localeName)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
      }
      trailing = IconButton(
        tooltip: l10n.menuRemove,
        icon: Icon(
          Icons.close,
          size: AppIconSize.sm,
          color: scheme.onSurfaceVariant,
        ),
        onPressed: () => _removeEvent(context, ref, event.id),
      );
    }

    // Records are editable (tap opens the record editor) and show their
    // attachments beneath. Other timeline entries render exactly as before.
    final isRecord = isRecordKind(event.kind);
    final attachments = isRecord
        ? (ref.watch(recordAttachmentsProvider(event.id)).value ?? const [])
        : const <AttachmentWithFile>[];

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.md, color: scheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              if (whenLine != null) ...[
                const SizedBox(height: AppSpacing.xs),
                whenLine,
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (!isRecord && attachments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: row,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: isRecord
            ? () => context.pushNamed(
                Routes.recordEditName,
                pathParameters: {
                  'id': event.possessionId,
                  'recordId': event.id,
                },
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row,
              if (attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppIconSize.md + AppSpacing.md,
                    top: AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final att in attachments)
                        AttachmentTile(
                          name: att.displayName,
                          onOpen: () => _openAttachment(context, att),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A record's date line, plus a calm validity line when it has an end date.
Widget _recordWhen(
  AppLocalizations l10n,
  ThemeData theme,
  ColorScheme scheme,
  PossessionEvent event,
) {
  final style = theme.textTheme.bodySmall?.copyWith(
    color: scheme.onSurfaceVariant,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l10n.onDate(formatDate(event.at, l10n.localeName)), style: style),
      if (event.endsAt != null)
        Text(
          l10n.recordValidUntil(formatDate(event.endsAt!, l10n.localeName)),
          style: style,
        ),
    ],
  );
}

/// Opens a record attachment in the OS viewer; calm snackbar on any problem.
Future<void> _openAttachment(
  BuildContext context,
  AttachmentWithFile att,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await openDocument(
    relativePath: att.file.relativePath,
    mimeType: att.file.mimeType,
    displayName: att.displayName,
  );
  final msg = switch (result) {
    DocumentOpenStatus.opened => null,
    DocumentOpenStatus.missing => l10n.documentMissing,
    DocumentOpenStatus.noHandler => l10n.documentOpenNoApp,
    _ => l10n.documentOpenFailed,
  };
  if (msg == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
}

class _AttentionPill extends StatelessWidget {
  const _AttentionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.brand.attention,
        borderRadius: AppRadii.borderSm,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: context.brand.onAttention,
        ),
      ),
    );
  }
}

/// A calm, tappable card used by the Details section.
class _TapCard extends StatelessWidget {
  const _TapCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadii.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppIconSize.md, color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                trailing ?? Icons.chevron_right,
                size: AppIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A calm, non-interactive informational card (same language as [_TapCard] but
/// nothing to tap) — used to explain why the place is unavailable while lent.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.borderLg,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover photo. With no cover, the area invites adding one. With a cover,
/// tapping the image opens it full-screen and a pencil replaces it — the two
/// actions are deliberately separate (see [CoverArea]).
class _Cover extends ConsumerWidget {
  const _Cover({required this.possession, this.inactive = false});

  final Possession possession;
  final bool inactive;

  static const double _height = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fileId = possession.coverFileId;

    // No cover yet → the calm "add a photo" invitation (disabled when inactive:
    // adding a photo is enrichment, withheld until restored).
    if (fileId == null) {
      return CoverArea(
        height: _height,
        image: null,
        addLabel: l10n.addPhoto,
        editTooltip: l10n.photoEditTooltip,
        onAdd: inactive ? null : () => _addPhotos(context, ref, possession.id),
      );
    }

    final file = ref.watch(fileByIdProvider(fileId)).value;
    final docs = ref.watch(appDocumentsPathProvider).value;

    // Still resolving the file/path → a plain calm surface, no flicker.
    if (file == null || docs == null) {
      return SizedBox(
        height: _height,
        width: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
      );
    }

    return CoverArea(
      height: _height,
      image: coverImage(
        docsPath: docs,
        relativePath: file.relativePath,
        height: _height,
      ),
      addLabel: l10n.addPhoto,
      editTooltip: l10n.photoEditTooltip,
      viewLabel: l10n.photoView,
      onView: () => context.pushNamed(
        Routes.photoName,
        pathParameters: {'id': possession.id},
      ),
      // Viewing always works; replacing the cover is enrichment (withheld while
      // inactive) — the pencil disappears until restored.
      onEdit: inactive
          ? null
          : () => _replaceCover(context, ref, possession.id),
    );
  }
}

/// The calm thumbnail gallery under the cover. Hidden when there are no photos,
/// so an object with nothing (or only the empty-cover invitation above) stays
/// uncluttered. Cover first, with a subtle badge; a trailing tile adds more.
class _Gallery extends ConsumerWidget {
  const _Gallery({required this.possession, this.inactive = false});

  final Possession possession;
  final bool inactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos =
        ref.watch(possessionPhotosProvider(possession.id)).value ??
        const <PhotoWithFile>[];
    if (photos.isEmpty) return const SizedBox.shrink();

    final docs = ref.watch(appDocumentsPathProvider).value;
    final ordered = orderCoverFirst(
      photos,
      fileId: (p) => p.file.id,
      coverFileId: possession.coverFileId,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: GalleryStrip(
        photos: ordered,
        coverFileId: possession.coverFileId,
        docsPath: docs,
        onOpen: (i) => context.pushNamed(
          Routes.photoName,
          pathParameters: {'id': possession.id},
          queryParameters: {'i': '$i'},
        ),
        onAdd: () => _addPhotos(context, ref, possession.id),
        showAdd: !inactive,
      ),
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.id, required this.possession});

  final String id;
  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (value) => switch (value) {
        'rename' => _rename(context, ref, possession),
        'archive' => _archive(context, ref, id),
        'remove' => _remove(context, ref, id),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.menuRename)),
        PopupMenuItem(value: 'archive', child: Text(l10n.menuPutAway)),
        PopupMenuItem(value: 'remove', child: Text(l10n.menuRemove)),
      ],
    );
  }
}

// ---- Actions ----

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Possession possession,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: possession.title);
  final newTitle = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.nameLabel),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (newTitle != null && newTitle.isNotEmpty) {
    await ref.read(possessionsDaoProvider).rename(possession.id, newTitle);
  }
}

/// True when the thing is actively lent — used to block actions that would
/// conflict with an open loan, with a calm explanation instead of silent damage.
Future<bool> _guardLent(BuildContext context, WidgetRef ref, String id) async {
  final loan = await ref.read(eventsDaoProvider).watchActiveLoan(id).first;
  if (loan == null) return false;
  if (context.mounted) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.resolveLoanBeforeArchive),
        ),
      );
  }
  return true;
}

Future<void> _archive(BuildContext context, WidgetRef ref, String id) async {
  if (await _guardLent(context, ref, id)) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final dao = ref.read(possessionsDaoProvider);
  await dao.setStatus(id, PossessionStatus.archived);
  if (router.canPop()) router.pop();
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.archivedSnack),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => dao.restore(id),
        ),
      ),
    );
}

Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
  if (await _guardLent(context, ref, id)) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final dao = ref.read(possessionsDaoProvider);
  await dao.softDelete(id);
  if (router.canPop()) router.pop();
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.removedSnack),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => dao.restore(id),
        ),
      ),
    );
}

/// Remove a record (timeline event): soft-delete with an Undo snackbar. The
/// record's attachment bytes are left untouched while Undo is possible; only
/// after the window closes (and if nothing else references them) are its
/// attachments unlinked and their orphan bytes reclaimed. A shared attachment is
/// never physically deleted.
Future<void> _removeEvent(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(eventsDaoProvider);
  await dao.deleteEvent(id);
  if (!context.mounted) return;

  var undone = false;
  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(l10n.eventRemovedSnack),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () {
          undone = true;
          dao.restoreEvent(id);
        },
      ),
    ),
  );
  await controller.closed;
  if (!undone) {
    await reclaimRecordAttachments(ref, id);
  }
}

/// Add one or more photos — the hub "Foto" action and the empty-cover
/// invitation. On an object with no photos the first becomes the cover;
/// otherwise the cover is left untouched (adding never silently replaces).
Future<void> _addPhotos(BuildContext context, WidgetRef ref, String id) async {
  final staged = await chooseAndStagePhotos(context);
  if (staged == null || staged.isEmpty) return;
  if (!context.mounted) return;
  final status = await saveStagedToPossession(
    ref,
    import: staged,
    possessionId: id,
  );
  if (context.mounted) _reportSave(context, status);
}

/// Replace the cover via the pencil: stage one image, promote it and make it the
/// cover on Save. The previous cover stays in the gallery (demoted, never
/// orphaned); a cancelled or blocked save leaves the existing cover untouched.
Future<void> _replaceCover(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final staged = await chooseAndStagePhoto(context);
  if (staged == null || staged.isEmpty) return;
  if (!context.mounted) return;
  final status = await saveStagedToPossession(
    ref,
    import: staged,
    possessionId: id,
    coverFirst: true,
  );
  if (context.mounted) _reportSave(context, status);
}

/// A calm snackbar only when a staged-photo save was blocked or failed; silent
/// on success (the new photo simply appears).
void _reportSave(BuildContext context, PhotoSaveStatus status) {
  final l10n = AppLocalizations.of(context);
  final msg = photoSaveMessage(l10n, status);
  if (msg == null) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
}

/// "Affida a qualcuno": choose between lending (temporary) and giving
/// (permanent) — kept out of the Foto·Nota·Data·Luogo hub. Only offered for an
/// active, non-lent thing (the custody card shows the loan state otherwise).
Future<void> _entrust(BuildContext context, String id) async {
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
  if (!context.mounted || action == null) return;
  if (action == 'lend') {
    context.pushNamed(Routes.lendName, pathParameters: {'id': id});
  } else if (action == 'give') {
    context.pushNamed(Routes.giveName, pathParameters: {'id': id});
  }
}

/// Assign or change a thing's place via the picker. Shared by the action hub
/// and the place card, so "assign a place" behaves identically wherever it is
/// reached.
Future<void> _pickPlace(
  BuildContext context,
  WidgetRef ref,
  Possession possession,
) async {
  // A lent thing has no place; assigning one would contradict the loan.
  final loan = await ref
      .read(eventsDaoProvider)
      .watchActiveLoan(possession.id)
      .first;
  if (loan != null) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.cannotAssignPlaceWhileLent),
          ),
        );
    }
    return;
  }
  if (!context.mounted) return;
  final choice = await showPlacePicker(
    context,
    currentPlaceId: possession.placeId,
  );
  if (choice == null) return;
  await ref
      .read(possessionsDaoProvider)
      .setPlace(possession.id, choice.placeId);
}

class _Calm extends StatelessWidget {
  const _Calm(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
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
