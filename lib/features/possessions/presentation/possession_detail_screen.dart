import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/brand_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../../../shared/photo_capture.dart';
import '../../../shared/phrasing.dart';
import '../../../shared/platform/photo_store.dart';
import '../application/event_providers.dart';
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
              _DetailsCard(id: id),
              const SizedBox(height: AppSpacing.md),
              _Placeholder(
                icon: Icons.folder_outlined,
                title: l10n.documentsTitle,
                description: l10n.documentsSubtitle,
              ),
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

/// A calm, ready-to-fill placeholder section (Documents, for now).
class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.borderLg,
      ),
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
                Text(description,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
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
