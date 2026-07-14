import '../core/database/tables/enums.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

/// Localized, human phrasing for the timeline. Kept out of `format.dart` because
/// these need translated words (via [AppLocalizations]), not just number/date
/// formatting.

/// e.g. "Oggi", "Domani", "tra 3 giorni", "2 giorni fa".
String relativeDay(AppLocalizations l10n, DateTime date) {
  final days = daysUntil(date);
  if (days == 0) return l10n.today;
  if (days == 1) return l10n.tomorrow;
  if (days == -1) return l10n.yesterday;
  if (days > 1) return l10n.inDays(days);
  return l10n.daysAgo(-days);
}

/// The one-line headline for how a thing was acquired, e.g. "Comprato da
/// MediaWorld", "Ricevuto in regalo", "Ereditato".
String acquisitionHeadline(
    AppLocalizations l10n, AcquisitionType? type, String? supplier) {
  final s = supplier?.trim() ?? '';
  final has = s.isNotEmpty;
  return switch (type) {
    AcquisitionType.purchased => has ? l10n.boughtAt(s) : l10n.bought,
    AcquisitionType.gift => l10n.receivedAsGift,
    AcquisitionType.inherited => l10n.inheritedHeadline,
    AcquisitionType.alreadyOwned => l10n.alreadyHadHeadline,
    AcquisitionType.other => l10n.keptHeadline,
    null => has ? l10n.fromSupplier(s) : l10n.purchaseDetailsHeadline,
  };
}

String acquisitionTypeLabel(AppLocalizations l10n, AcquisitionType type) =>
    switch (type) {
      AcquisitionType.purchased => l10n.acqTypeBought,
      AcquisitionType.gift => l10n.acqTypeGift,
      AcquisitionType.inherited => l10n.acqTypeInherited,
      AcquisitionType.alreadyOwned => l10n.acqTypeAlreadyHad,
      AcquisitionType.other => l10n.acqTypeOther,
    };

String reminderLeadLabel(AppLocalizations l10n, ReminderLead lead) =>
    switch (lead) {
      ReminderLead.sameDay => l10n.leadSameDay,
      ReminderLead.dayBefore => l10n.leadDayBefore,
      ReminderLead.weekBefore => l10n.leadWeekBefore,
      ReminderLead.monthBefore => l10n.leadMonthBefore,
    };
