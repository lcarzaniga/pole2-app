import 'package:flutter/material.dart';

import '../../../app/theme/app_icon_size.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';

/// M9 — the contextual-record categories offered in the record editor, in
/// display order. Each maps 1:1 to an [EventKind]; the user-facing category
/// always lives on the record, never on its attachments.
const List<EventKind> kRecordCategories = [
  EventKind.note,
  EventKind.acquired,
  EventKind.warranty,
  EventKind.manual,
  EventKind.service,
  EventKind.insurance,
  EventKind.custom,
];

/// EventKinds a person edits through the record editor (tap-to-edit on the
/// timeline). Includes `repair` so any legacy maintenance record stays editable.
bool isRecordKind(EventKind kind) => switch (kind) {
  EventKind.note ||
  EventKind.acquired ||
  EventKind.warranty ||
  EventKind.manual ||
  EventKind.service ||
  EventKind.repair ||
  EventKind.insurance ||
  EventKind.custom => true,
  _ => false,
};

/// The user-facing category label for a record's [EventKind].
String recordCategoryLabel(AppLocalizations l10n, EventKind kind) =>
    switch (kind) {
      EventKind.note => l10n.catNote,
      EventKind.acquired => l10n.catPurchase,
      EventKind.warranty => l10n.catWarranty,
      EventKind.manual => l10n.catManual,
      EventKind.service || EventKind.repair => l10n.catMaintenance,
      EventKind.insurance => l10n.catInsurance,
      _ => l10n.catOther,
    };

/// The calm category icon for a record's [EventKind].
IconData recordCategoryIcon(EventKind kind) => switch (kind) {
  EventKind.note => Icons.sticky_note_2_outlined,
  EventKind.acquired => Icons.shopping_bag_outlined,
  EventKind.warranty => Icons.verified_user_outlined,
  EventKind.manual => Icons.menu_book_outlined,
  EventKind.service || EventKind.repair => Icons.build_outlined,
  EventKind.insurance => Icons.shield_outlined,
  _ => Icons.description_outlined,
};

/// A single attachment row: file icon, name, open, and (optional) remove. Kept
/// here so the record editor and the timeline render attachments identically.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.name,
    required this.onOpen,
    this.onRemove,
    this.removeTooltip,
  });

  final String name;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.attach_file,
              size: AppIconSize.sm,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: removeTooltip,
                icon: Icon(
                  Icons.close,
                  size: AppIconSize.sm,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
