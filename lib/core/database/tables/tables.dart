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
class Possessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      textEnum<PossessionStatus>().withDefault(const Constant('active'))();
  TextColumn get coverFileId =>
      text().nullable().references(Files, #id)();
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
  DateTimeColumn get purchasedOn => dateTime().nullable()(); // explicit acquisition date
  TextColumn get acquisitionType => textEnum<AcquisitionType>().nullable()();
  TextColumn get remindLead => textEnum<ReminderLead>().nullable()();
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
