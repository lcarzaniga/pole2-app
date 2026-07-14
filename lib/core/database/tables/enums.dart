/// Domain enums, shared by the Drift tables and the app.
///
/// All are stored **by name** (`textEnum`) so reordering or inserting values
/// never corrupts existing rows, and all are additively extensible. See
/// `docs/DOMAIN_MODEL.md` §6.
library;

/// A possession's lifecycle. Note: this is *state*, never deletion — the record
/// is preserved in every state (see DOMAIN_MODEL §4).
enum PossessionStatus { active, archived, transferred, lost, disposed }

enum EvidenceKind { receipt, invoice, manual, warrantyCard, photo, label, other }

enum EventKind {
  acquired,
  note,
  service,
  repair,
  reminder,
  warranty,
  transfer,
  disposal,
  lost,
  custom,
}

/// Only meaningful for actionable events (e.g. reminders).
enum EventStatus { pending, done, dismissed }

enum PartyKind { retailer, manufacturer, repairer, insurer, person, other }

/// "What uniquely identifies this?" — see DOMAIN_MODEL §3.5.
enum IdentifierKind {
  serialNumber,
  imei,
  vin,
  macAddress,
  assetTag,
  registration,
  other,
}

/// A light typing hint for descriptive attributes.
enum AttributeValueType { text, number, date, dimension }

/// How a thing came to be owned. Stored on the single `acquired` event.
enum AcquisitionType { purchased, gift, inherited, alreadyOwned, other }

/// Optional advance notice for a reminder. Persisted for a future
/// notifications feature; today it also informs in-app "approaching" styling.
enum ReminderLead { sameDay, dayBefore, weekBefore, monthBefore }
