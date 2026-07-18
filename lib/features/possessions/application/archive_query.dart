import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';

/// Centralized, **exhaustive** lifecycle-status labels for the Archivio surface.
/// Keeping every status here (not scattered in widgets) means adding "Dato a
/// qualcuno" next only touches the enum + one arm, never the archive layout.
/// `active` is never shown in Archivio, so it maps to an empty label.
String lifecycleLabel(AppLocalizations l10n, PossessionStatus status) {
  return switch (status) {
    PossessionStatus.active => '',
    PossessionStatus.archived => l10n.archivedStatusLabel,
    PossessionStatus.transferred => l10n.transferredStatusLabel,
    PossessionStatus.lost => l10n.lostStatusLabel,
    PossessionStatus.disposed => l10n.disposedStatusLabel,
  };
}

/// Pure, DB-free search over an already-loaded archive list: matches title or
/// category (case-insensitive), preserving the incoming order (the DAO's
/// most-recently-updated-first). Trivially unit testable.
List<Possession> filterArchiveBySearch(List<Possession> items, String search) {
  final needle = search.trim().toLowerCase();
  if (needle.isEmpty) return List<Possession>.of(items);
  return items.where((p) {
    final inTitle = p.title.toLowerCase().contains(needle);
    final inCategory = p.category?.toLowerCase().contains(needle) ?? false;
    return inTitle || inCategory;
  }).toList();
}
