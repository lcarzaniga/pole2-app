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
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../../../shared/photo_capture.dart';
import '../../../shared/phrasing.dart';
import '../../../shared/platform/document_store.dart';
import '../../../shared/platform/photo_store.dart';
import '../../places/application/place_providers.dart';
import '../../places/presentation/place_picker.dart';
import '../application/event_providers.dart';
import '../application/evidence_providers.dart';
import '../application/possession_providers.dart';

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

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (possession.value != null)
            _MoreMenu(id: id, possession: possession.value!),
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

class _Dossier extends ConsumerWidget {
  const _Dossier({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final id = possession.id;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Cover(possession: possession),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(possession.title,
                        style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    tooltip: l10n.renameTooltip,
                    icon: Icon(Icons.edit_outlined,
                        size: AppIconSize.md, color: scheme.onSurfaceVariant),
                    onPressed: () => _rename(context, ref, possession),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.keptOn(formatDate(possession.createdAt, l10n.localeName)),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              _NextGlance(id: id),
              const SizedBox(height: AppSpacing.xl),
              _PlaceCard(possession: possession),
              const SizedBox(height: AppSpacing.md),
              _DetailsCard(id: id),
              const SizedBox(height: AppSpacing.md),
              _DocumentsCard(id: id),
              const SizedBox(height: AppSpacing.md),
              _HistoryCard(id: id),
            ],
          ),
        ),
      ],
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
    final upcoming = events
        .where((e) => e.kind == EventKind.reminder && daysUntil(e.at) >= 0)
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final soon = daysUntil(next.at) <= 30;
    final color =
        soon ? context.brand.attention : theme.colorScheme.onSurfaceVariant;
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

/// The Details section — now the acquisition, in human words.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acq = ref.watch(acquisitionProvider(id)).value;
    final l10n = AppLocalizations.of(context);
    void onTap() => context.pushNamed(Routes.acquisitionName,
        pathParameters: {'id': id});

    if (acq == null) {
      return _TapCard(
        icon: Icons.list_alt_outlined,
        title: l10n.detailsTitle,
        subtitle: l10n.detailsEmptySubtitle,
        onTap: onTap,
      );
    }

    final supplier =
        acq.partyId == null ? null : ref.watch(partyProvider(acq.partyId!)).value;
    final headline =
        acquisitionHeadline(l10n, acq.acquisitionType, supplier?.name);
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

/// Where this thing lives — always shown. When a place is assigned, tapping the
/// card opens that place's contents; a separate edit control changes / creates /
/// clears the place. When none is assigned, the card invites choosing one.
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.possession});

  final Possession possession;

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final choice = await showPlacePicker(
      context,
      currentPlaceId: possession.placeId,
    );
    if (choice == null) return;
    await ref
        .read(possessionsDaoProvider)
        .setPlace(possession.id, choice.placeId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final placeId = possession.placeId;
    // A deleted place resolves to null → treated as "no place" (invite choosing).
    final place =
        placeId == null ? null : ref.watch(placeByIdProvider(placeId)).value;

    if (place == null) {
      return _TapCard(
        icon: Icons.place_outlined,
        title: l10n.noPlace,
        subtitle: l10n.placeAssignHint,
        trailing: Icons.edit_outlined,
        onTap: () => _openPicker(context, ref),
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
                onPressed: () => _openPicker(context, ref),
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
          Row(
            children: [
              Expanded(
                child: Text(l10n.historyTitle, style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => context.pushNamed(Routes.reminderName,
                    pathParameters: {'id': id}),
                icon: const Icon(Icons.add, size: AppIconSize.sm),
                label: Text(l10n.addDate),
              ),
            ],
          ),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.historyEmpty,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
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
        whenLine = Text(meta,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant));
      }
    } else if (event.kind == EventKind.note) {
      icon = Icons.sticky_note_2_outlined;
      // The note's body is the headline; its title (if any) is rarely used.
      title = event.notes ?? event.title ?? l10n.addNote;
      whenLine = Text(l10n.onDate(formatDate(event.at, l10n.localeName)),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant));
      trailing = IconButton(
        tooltip: l10n.menuRemove,
        icon: Icon(Icons.close, size: AppIconSize.sm, color: scheme.onSurfaceVariant),
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
        whenLine = Text(l10n.onDate(formatDate(event.at, l10n.localeName)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant));
      }
      trailing = IconButton(
        tooltip: l10n.menuRemove,
        icon: Icon(Icons.close, size: AppIconSize.sm, color: scheme.onSurfaceVariant),
        onPressed: () => _removeEvent(context, ref, event.id),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
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
      ),
    );
  }
}

class _AttentionPill extends StatelessWidget {
  const _AttentionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.brand.attention,
        borderRadius: AppRadii.borderSm,
      ),
      child: Text(text,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: context.brand.onAttention)),
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
                    Text(subtitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(trailing ?? Icons.chevron_right,
                  size: AppIconSize.md, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover photo — tap to add or change.
class _Cover extends ConsumerWidget {
  const _Cover({required this.possession});

  final Possession possession;

  static const double _height = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fileId = possession.coverFileId;

    Widget content;
    if (fileId == null) {
      content =
          _AddPhotoHint(onTap: () => _pickPhoto(context, ref, possession.id));
    } else {
      final file = ref.watch(fileByIdProvider(fileId)).value;
      final docs = ref.watch(appDocumentsPathProvider).value;
      if (file != null && docs != null) {
        content = GestureDetector(
          onTap: () => _pickPhoto(context, ref, possession.id),
          child: coverImage(
            docsPath: docs,
            relativePath: file.relativePath,
            height: _height,
          ),
        );
      } else {
        content = const SizedBox.shrink();
      }
    }

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: ColoredBox(color: scheme.surfaceContainerLow, child: content),
    );
  }
}

class _AddPhotoHint extends StatelessWidget {
  const _AddPhotoHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: AppIconSize.lg, color: scheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(AppLocalizations.of(context).addPhoto,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Documents — receipts, manuals and warranties attached to a thing. Adding
/// one is a visible action in the section header (never hidden in a menu); each
/// document lists by its name and can be removed with an undo.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final docs = ref.watch(documentsByPossessionProvider(id)).value ?? const [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.documentsTitle,
                    style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => _addDocument(context, ref, id),
                icon: const Icon(Icons.add, size: AppIconSize.sm),
                label: Text(l10n.documentAdd),
              ),
            ],
          ),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(l10n.documentsSubtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            )
          else
            for (final d in docs) _DocumentRow(document: d),
        ],
      ),
    );
  }
}

class _DocumentRow extends ConsumerWidget {
  const _DocumentRow({required this.document});

  final PossessionDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = document.evidence.label ?? l10n.documentsTitle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(_documentIcon(document.file.mimeType),
              size: AppIconSize.md, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(name,
                style: theme.textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: l10n.menuRemove,
            icon: Icon(Icons.close,
                size: AppIconSize.sm, color: scheme.onSurfaceVariant),
            onPressed: () =>
                _removeDocument(context, ref, document.evidence.id),
          ),
        ],
      ),
    );
  }
}

/// A calm icon for a document, chosen from its stored MIME type.
IconData _documentIcon(String mimeType) {
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  return Icons.description_outlined;
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
    BuildContext context, WidgetRef ref, Possession possession) async {
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

Future<void> _archive(BuildContext context, WidgetRef ref, String id) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final dao = ref.read(possessionsDaoProvider);
  await dao.setStatus(id, PossessionStatus.archived);
  if (router.canPop()) router.pop();
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(l10n.archivedSnack),
      action:
          SnackBarAction(label: l10n.undo, onPressed: () => dao.restore(id)),
    ));
}

Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final dao = ref.read(possessionsDaoProvider);
  await dao.softDelete(id);
  if (router.canPop()) router.pop();
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(l10n.removedSnack),
      action:
          SnackBarAction(label: l10n.undo, onPressed: () => dao.restore(id)),
    ));
}

Future<void> _removeEvent(BuildContext context, WidgetRef ref, String id) async {
  final l10n = AppLocalizations.of(context);
  final dao = ref.read(eventsDaoProvider);
  await dao.deleteEvent(id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(l10n.eventRemovedSnack),
      action: SnackBarAction(
          label: l10n.undo, onPressed: () => dao.restoreEvent(id)),
    ));
}

Future<void> _pickPhoto(
    BuildContext context, WidgetRef ref, String id) async {
  final photo = await chooseAndCapturePhoto(context);
  if (photo == null) return;
  await ref.read(possessionsDaoProvider).setCover(
        id,
        relativePath: photo.relativePath,
        mimeType: photo.mimeType,
        byteSize: photo.byteSize,
      );
}

Future<void> _addDocument(
    BuildContext context, WidgetRef ref, String id) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final result = await pickDocument();
  switch (result.outcome) {
    case DocumentOutcome.cancelled:
      return; // dismissed — silent, nothing changed.
    case DocumentOutcome.failed:
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.documentAddFailed),
        ));
      return;
    case DocumentOutcome.success:
      final doc = result.document!;
      await ref.read(evidenceDaoProvider).addDocument(
            possessionId: id,
            relativePath: doc.relativePath,
            mimeType: doc.mimeType,
            byteSize: doc.byteSize,
            label: doc.name,
          );
  }
}

Future<void> _removeDocument(
    BuildContext context, WidgetRef ref, String evidenceId) async {
  final l10n = AppLocalizations.of(context);
  final dao = ref.read(evidenceDaoProvider);
  await dao.removeDocument(evidenceId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(l10n.documentRemovedSnack),
      action: SnackBarAction(
          label: l10n.undo, onPressed: () => dao.restoreDocument(evidenceId)),
    ));
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
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
