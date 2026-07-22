import 'package:drift/drift.dart';

import 'enums.dart';

/// The frozen domain schema (see `docs/DOMAIN_MODEL.md` §6).
///
/// Conventions across every table:
/// - **UUID text primary keys** (client-generated) — the prerequisite for
///   offline-friendly cloud sync later.
/// - `createdAt` / `updatedAt` on every row; `deletedAt` where soft delete
///   makes conceptual sense (everywhere except [Files] and the link table).
/// - `@DataClassName` sets the row class name (notably `StoredFile`, to avoid
///   colliding with `dart:io`'s `File`).
///
/// Only `Possessions` has reactive CRUD wired so far; the rest exist so the
/// schema is frozen and migrations start from a complete v2. No `Secret` table:
/// secrets are first-class but deliberately unpersisted until encryption exists
/// (DOMAIN_MODEL §3.7).

/// The on-disk asset registry. Bytes live under the app documents dir; only
/// metadata is stored here. Hard-deleted (GC'd) when unreferenced.
@DataClassName('StoredFile')
class Files extends Table {
  TextColumn get id => text()();
  TextColumn get relativePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The anchor. Only `title` is required — nothing else may block a save.
@DataClassName('Possession')
@TableIndex(name: 'idx_possession_place', columns: {#placeId})
class Possessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      textEnum<PossessionStatus>().withDefault(const Constant('active'))();
  TextColumn get coverFileId => text().nullable().references(Files, #id)();

  /// Where this thing lives (M2 Places). **Null = "no place"** — there is never
  /// a physical placeholder record; the UI shows "no place" for null. Flat only:
  /// no hierarchy/parentId in R1.0 (DOMAIN_MODEL §3.11).
  TextColumn get placeId => text().nullable().references(Places, #id)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A user-defined, **reusable** place where possessions live ("Garage",
/// "Ufficio", "Cantina"). A **tree** of real physical containment (M5.4): a
/// place may hold child places and/or possessions at any level. Soft-deleted
/// like its siblings.
@DataClassName('Place')
@TableIndex(name: 'idx_place_parent', columns: {#parentId})
class Places extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get notes => text().nullable()();

  /// The containing place. **Null = root** (no hierarchy above). A self-
  /// reference (added in schema v7); the tree shape and cycle-safety are
  /// enforced by application logic, never by cascading DB deletes.
  TextColumn get parentId => text().nullable().references(Places, #id)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A possession's photo gallery (M5.1). One-to-many: each row is one image of
/// exactly one possession — never shared (that's what [EvidenceItems] is for).
///
/// The **cover** is not a flag here; it stays on `possessions.cover_file_id`,
/// which structurally guarantees "at most one cover" and keeps every legacy
/// cover working unchanged. A photo is the cover when its `fileId` equals the
/// possession's `coverFileId`. `sortOrder` gives a stable, deterministic order
/// for the rest; soft-deleted rows are excluded from the gallery.
@DataClassName('PossessionPhoto')
@TableIndex(name: 'idx_photo_possession', columns: {#possessionId})
@TableIndex(name: 'idx_photo_sort', columns: {#possessionId, #sortOrder})
class PossessionPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get fileId => text().references(Files, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// "What uniquely identifies this?" — serial, VIN, IMEI, MAC, …
@DataClassName('Identifier')
@TableIndex(name: 'idx_identifier_possession', columns: {#possessionId})
class Identifiers extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get kind => textEnum<IdentifierKind>()();
  TextColumn get label => text().nullable()();
  TextColumn get value => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// "What do I want to remember?" — descriptive, visible facts only.
@DataClassName('Attribute')
@TableIndex(name: 'idx_attribute_possession', columns: {#possessionId})
class Attributes extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get label => text()();
  TextColumn get value => text()();
  TextColumn get valueType => textEnum<AttributeValueType>().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A captured artifact, backed by a File. Many-to-many with possessions.
@DataClassName('EvidenceItem')
class EvidenceItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<EvidenceKind>()();
  TextColumn get label => text().nullable()();
  TextColumn get fileId => text().nullable().references(Files, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The many-to-many link: one receipt can belong to many possessions.
@DataClassName('PossessionEvidenceLink')
class PossessionEvidence extends Table {
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get evidenceId => text().references(EvidenceItems, #id)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {possessionId, evidenceId};
}

/// M9 (contextual records): the many-to-many link between a timeline record
/// ([Events]) and its document attachments ([EvidenceItems]). One record can
/// carry several attachments, and one attachment can be shared by several
/// records — so removing a record never blindly deletes a shared file. Added in
/// schema v8; the older single [Events.evidenceId] and [PossessionEvidence] are
/// left dormant and untouched.
@DataClassName('EventEvidenceLink')
@TableIndex(name: 'idx_event_evidence_evidence', columns: {#evidenceId})
class EventEvidence extends Table {
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get evidenceId => text().references(EvidenceItems, #id)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {eventId, evidenceId};
}

/// The timeline atom: past events, reminders, and intervals (warranty).
@DataClassName('PossessionEvent')
@TableIndex(name: 'idx_event_possession', columns: {#possessionId})
@TableIndex(name: 'idx_event_at', columns: {#at})
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get kind => textEnum<EventKind>()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get amountMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get partyId => text().nullable().references(Parties, #id)();
  TextColumn get evidenceId =>
      text().nullable().references(EvidenceItems, #id)();
  TextColumn get status => textEnum<EventStatus>().nullable()();
  // Added in schema v3 (Milestone 9). All nullable, only meaningful for their
  // respective event kinds.
  DateTimeColumn get purchasedOn =>
      dateTime().nullable()(); // explicit acquisition date
  TextColumn get acquisitionType => textEnum<AcquisitionType>().nullable()();
  TextColumn get remindLead => textEnum<ReminderLead>().nullable()();
  // Added in schema v6 (M5.2 loans): the possession's place at lend time, so a
  // return can safely restore it. Null = no place then. Only meaningful on a
  // `lent` event.
  TextColumn get originPlaceId => text().nullable().references(Places, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// People/orgs, reusable across events.
@DataClassName('Party')
class Parties extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<PartyKind>().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
