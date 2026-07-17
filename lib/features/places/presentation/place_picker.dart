import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../possessions/application/possession_providers.dart';
import '../application/place_providers.dart';

enum _PlaceMenu { rename, delete }

/// The result of the place picker. `placeId == null` means the user chose
/// "no place" (clear the assignment). The picker returns `null` only when
/// dismissed without choosing — the caller then changes nothing.
class PlaceChoice {
  const PlaceChoice(this.placeId);
  final String? placeId;
}

/// A calm bottom sheet to assign a place: choose an existing one, clear it
/// ("no place"), or create a new one inline. Reusable across screens.
///
/// When [disableCurrent] is true, the [currentPlaceId] row is shown but not
/// selectable — used by "move", so choosing the place a thing is already in
/// can't produce a confusing no-op.
Future<PlaceChoice?> showPlacePicker(
  BuildContext context, {
  String? currentPlaceId,
  bool disableCurrent = false,
}) {
  return showModalBottomSheet<PlaceChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlacePickerSheet(
      currentPlaceId: currentPlaceId,
      disableCurrent: disableCurrent,
    ),
  );
}

class _PlacePickerSheet extends ConsumerStatefulWidget {
  const _PlacePickerSheet({this.currentPlaceId, this.disableCurrent = false});

  final String? currentPlaceId;
  final bool disableCurrent;

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

  Future<void> _renamePlace(Place p) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.placeRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancelButton)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(l10n.saveButton)),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(placesDaoProvider).edit(p.id, name: name);
    }
  }

  Future<void> _deletePlace(Place p) async {
    final l10n = AppLocalizations.of(context);
    // How many possessions would be affected — drives the warning copy.
    final count = await ref.read(possessionsDaoProvider).countByPlace(p.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.placeDeleteTitle(p.name)),
        content: Text(
            count > 0 ? l10n.placeDeleteAssigned(count) : l10n.placeDeleteNone),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancelButton)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.placeDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Soft-delete the place and clear it from any possessions atomically, so
    // they safely resolve to "no place" (no dangling reference, no orphaned
    // crash, no half-deleted state).
    await ref.read(placesDaoProvider).deleteAndUnassign(p.id);
  }

  /// One place row. When the picker was opened to *move* and this is the place
  /// the thing is already in, the row is shown (with its check) but not
  /// selectable — so it can never be a confusing no-op.
  Widget _buildPlaceRow(
    BuildContext context,
    ColorScheme scheme,
    AppLocalizations l10n,
    Place p,
    void Function(String?) choose,
  ) {
    final isCurrent = p.id == widget.currentPlaceId;
    final locked = isCurrent && widget.disableCurrent;
    return ListTile(
      enabled: !locked,
      leading: Icon(Icons.place_outlined,
          color: locked ? scheme.onSurfaceVariant : scheme.primary),
      title: Text(p.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent) Icon(Icons.check, color: scheme.primary),
          PopupMenuButton<_PlaceMenu>(
            icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
            tooltip: l10n.placeManageTooltip,
            onSelected: (m) => switch (m) {
              _PlaceMenu.rename => _renamePlace(p),
              _PlaceMenu.delete => _deletePlace(p),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: _PlaceMenu.rename, child: Text(l10n.menuRename)),
              PopupMenuItem(
                value: _PlaceMenu.delete,
                child: Text(l10n.placeDelete,
                    style: TextStyle(color: scheme.error)),
              ),
            ],
          ),
        ],
      ),
      onTap: locked ? null : () => choose(p.id),
    );
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
                    _buildPlaceRow(context, scheme, l10n, p, choose),
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
