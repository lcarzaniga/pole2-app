import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/providers/database_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../possessions/application/event_providers.dart';
import '../application/people_providers.dart';
import '../application/people_queries.dart';
import '../domain/custody.dart';

/// Persone: a calm, non-hierarchical browser of the people you lend or give
/// things to. Mirrors the Places browser's language; never an address book.
class PeopleBrowserScreen extends ConsumerStatefulWidget {
  const PeopleBrowserScreen({super.key});

  @override
  ConsumerState<PeopleBrowserScreen> createState() =>
      _PeopleBrowserScreenState();
}

class _PeopleBrowserScreenState extends ConsumerState<PeopleBrowserScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // People (for loading/empty state) plus their current counts.
    final peopleAsync = ref.watch(peopleProvider);
    final rows = ref.watch(peopleWithCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.peopleTitle),
        actions: [
          IconButton(
            tooltip: l10n.peopleAddTooltip,
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => _addPerson(context),
          ),
        ],
      ),
      body: HexBackground(
        child: peopleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Calm(l10n.errorNothingLost),
          data: (_) {
            if (rows.isEmpty) return _Empty(onAdd: () => _addPerson(context));
            final needle = _query.trim().toLowerCase();
            final visible = needle.isEmpty
                ? rows
                : [
                    for (final s in rows)
                      if (s.party.name.toLowerCase().contains(needle)) s,
                  ];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.peopleSearchHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.searchClear,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _Calm(l10n.searchNoResults)
                      : ListView.separated(
                          padding: padWithSafeBottom(
                            context,
                            const EdgeInsets.all(AppSpacing.lg),
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, i) =>
                              _PersonRow(summary: visible[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.peopleAddTitle),
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
            child: Text(l10n.addPersonButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await createPerson(ref.read(databaseProvider), name);
    }
  }
}

/// The relationship line, omitting zeros: "2 in prestito · 1 dato". Null when
/// the person has no current relationship (row then shows just the name).
String? relationshipSummary(
  AppLocalizations l10n,
  int loanCount,
  int givenCount,
) {
  final parts = <String>[
    if (loanCount > 0) l10n.peopleCountLent(loanCount),
    if (givenCount > 0) l10n.peopleCountGiven(givenCount),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.summary});

  final PersonSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final line = relationshipSummary(
      l10n,
      summary.loanCount,
      summary.givenCount,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: Icon(Icons.person_outline, color: scheme.primary),
        title: Text(summary.party.name, style: theme.textTheme.titleMedium),
        subtitle: line == null
            ? null
            : Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => context.pushNamed(
          Routes.personName,
          pathParameters: {'id': summary.party.id},
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.peopleEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.peopleAddTitle),
            ),
          ],
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
