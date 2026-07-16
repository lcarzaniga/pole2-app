import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/place_providers.dart';

/// The result of the place picker. `placeId == null` means the user chose
/// "no place" (clear the assignment). The picker returns `null` only when
/// dismissed without choosing — the caller then changes nothing.
class PlaceChoice {
  const PlaceChoice(this.placeId);
  final String? placeId;
}

/// A calm bottom sheet to assign a place: choose an existing one, clear it
/// ("no place"), or create a new one inline. Reusable across screens.
Future<PlaceChoice?> showPlacePicker(
  BuildContext context, {
  String? currentPlaceId,
}) {
  return showModalBottomSheet<PlaceChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlacePickerSheet(currentPlaceId: currentPlaceId),
  );
}

class _PlacePickerSheet extends ConsumerStatefulWidget {
  const _PlacePickerSheet({this.currentPlaceId});

  final String? currentPlaceId;

  @override
  ConsumerState<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<_PlacePickerSheet> {
  final _newController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect() async {
    final name = _newController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    final id = await ref.read(placesDaoProvider).create(name: name);
    if (mounted) Navigator.of(context).pop(PlaceChoice(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placeListProvider).value ?? const <Place>[];

    void choose(String? placeId) =>
        Navigator.of(context).pop(PlaceChoice(placeId));

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
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(l10n.placePickerTitle,
                  style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "No place" — clear the assignment.
                  ListTile(
                    leading: Icon(Icons.not_listed_location_outlined,
                        color: scheme.onSurfaceVariant),
                    title: Text(l10n.noPlace),
                    trailing: widget.currentPlaceId == null
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => choose(null),
                  ),
                  const Divider(height: 1),
                  for (final p in places)
                    ListTile(
                      leading: Icon(Icons.place_outlined, color: scheme.primary),
                      title: Text(p.name),
                      trailing: p.id == widget.currentPlaceId
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () => choose(p.id),
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
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _createAndSelect(),
                      decoration: InputDecoration(
                        hintText: l10n.newPlaceHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _newController.text.trim().isEmpty || _creating
                        ? null
                        : _createAndSelect,
                    child: Text(l10n.addPlaceButton),
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
