import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/providers/database_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../places/presentation/widgets/possession_thumb.dart';
import '../../possessions/application/event_providers.dart';
import '../application/people_providers.dart';
import '../application/people_queries.dart';
import '../domain/custody.dart';

/// One person's detail: what they currently have of yours ("In prestito"),
/// what you've permanently given them ("Dati"), and the past ("Storico").
/// Read-only lists that navigate into each possession; calm, never a CRM.
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final person = ref.watch(partyProvider(id)).value;
    final name = person?.name ?? '';
    final loans = ref.watch(personLoansProvider(id));
    final given = ref.watch(personGivenProvider(id));
    final history = ref.watch(personHistoryProvider(id));

    final empty = loans.isEmpty && given.isEmpty && history.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'rename') _rename(context, ref, name);
              if (v == 'delete') _delete(context, ref, name);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.personRename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.personDelete)),
            ],
          ),
        ],
      ),
      body: HexBackground(
        child: ListView(
          padding: padWithSafeBottom(
            context,
            const EdgeInsets.only(bottom: AppSpacing.lg),
          ),
          children: [
            if (empty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  l10n.personEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (loans.isNotEmpty) ...[
              _SectionHeader(l10n.personSectionLent),
              for (final l in loans)
                _PossessionRow(
                  possessionId: l.possession.id,
                  title: l.possession.title,
                  thumb: PossessionThumb(possession: l.possession),
                  info: l.loan.endsAt == null
                      ? null
                      : l10n.expectedReturnOn(
                          formatDate(l.loan.endsAt!, l10n.localeName),
                        ),
                ),
            ],
            if (given.isNotEmpty) ...[
              _SectionHeader(l10n.personSectionGiven),
              for (final g in given)
                _PossessionRow(
                  possessionId: g.possession.id,
                  title: g.possession.title,
                  thumb: PossessionThumb(possession: g.possession),
                  info: l10n.personGivenOn(
                    formatDate(g.transfer.at, l10n.localeName),
                  ),
                ),
            ],
            if (history.isNotEmpty) ...[
              _SectionHeader(l10n.personSectionHistory),
              for (final h in history)
                _PossessionRow(
                  possessionId: h.possessionId,
                  title: h.possessionTitle,
                  thumb: _HistoryIcon(kind: h.kind),
                  info: _historyLabel(l10n, h),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _historyLabel(AppLocalizations l10n, HistoryEntry h) {
    final date = formatDate(h.at, l10n.localeName);
    return switch (h.kind) {
      HistoryKind.returnedLoan => l10n.personHistReturned(date),
      HistoryKind.pastTransfer => l10n.personHistGiven(date),
      HistoryKind.reacquired => l10n.personHistReacquired(date),
    };
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String name) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.personRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l10n.personNameHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    final ok = await renamePerson(ref.read(databaseProvider), id, newName);
    if (!ok) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.personRenameDuplicate),
          ),
        );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(databaseProvider);

    // Block deletion while the person still holds current custody.
    if (await personHasCurrentCustody(db, id)) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.personDeleteBlocked(name)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancelButton),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.personDeleteTitle(name)),
        content: Text(l10n.personDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.personDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await softDeletePerson(db, id);
    if (!context.mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.personDeletedSnack),
        ),
      );
    if (context.canPop()) context.pop();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _PossessionRow extends StatelessWidget {
  const _PossessionRow({
    required this.possessionId,
    required this.title,
    required this.thumb,
    this.info,
  });

  final String possessionId;
  final String title;
  final Widget thumb;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          leading: thumb,
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: info == null
              ? null
              : Text(
                  info!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
          trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          onTap: () => context.pushNamed(
            Routes.possessionName,
            pathParameters: {'id': possessionId},
          ),
        ),
      ),
    );
  }
}

/// A calm, colour-independent leading icon for a history row — the relationship
/// type is carried by both the icon and the row's text label.
class _HistoryIcon extends StatelessWidget {
  const _HistoryIcon({required this.kind});

  final HistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (kind) {
      HistoryKind.returnedLoan => Icons.assignment_return_outlined,
      HistoryKind.pastTransfer => Icons.card_giftcard_outlined,
      HistoryKind.reacquired => Icons.keyboard_return,
    };
    return SizedBox(
      width: 48,
      height: 48,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}
