import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/event_providers.dart';

/// The chosen borrower: an existing person, or a new one to create by [name].
/// [partyId] is set only when an existing person was picked.
class PersonChoice {
  const PersonChoice({required this.name, this.partyId});
  final String name;
  final String? partyId;
}

/// A calm bottom sheet to choose a borrower: pick an existing person or type a
/// new name. People only — suppliers and other party kinds never appear here,
/// and creating one never touches an existing supplier. Returns null if
/// dismissed (the caller changes nothing).
Future<PersonChoice?> showPersonPicker(BuildContext context) {
  return showModalBottomSheet<PersonChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PersonPickerSheet(),
  );
}

class _PersonPickerSheet extends ConsumerStatefulWidget {
  const _PersonPickerSheet();

  @override
  ConsumerState<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<_PersonPickerSheet> {
  final _newController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  void _createAndSelect() {
    final name = _newController.text.trim();
    if (name.isEmpty) return;
    // Defer creation to save time: return the name; the loan DAO resolves it via
    // findOrCreatePerson (reusing an existing person with the same name).
    Navigator.of(context).pop(PersonChoice(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final people = ref.watch(peopleProvider).value ?? const <Party>[];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.selectPerson,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (people.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        l10n.personEmptyHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final person in people)
                    ListTile(
                      leading: Icon(
                        Icons.person_outline,
                        color: scheme.primary,
                      ),
                      title: Text(person.name),
                      onTap: () => Navigator.of(context).pop(
                        PersonChoice(name: person.name, partyId: person.id),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _createAndSelect(),
                      decoration: InputDecoration(
                        labelText: l10n.createPerson,
                        hintText: l10n.personNameHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _newController.text.trim().isEmpty
                        ? null
                        : _createAndSelect,
                    child: Text(l10n.addPersonButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
