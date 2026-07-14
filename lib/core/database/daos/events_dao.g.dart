// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'events_dao.dart';

// ignore_for_file: type=lint
mixin _$EventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FilesTable get files => attachedDatabase.files;
  $PossessionsTable get possessions => attachedDatabase.possessions;
  $PartiesTable get parties => attachedDatabase.parties;
  $EvidenceItemsTable get evidenceItems => attachedDatabase.evidenceItems;
  $EventsTable get events => attachedDatabase.events;
  EventsDaoManager get managers => EventsDaoManager(this);
}

class EventsDaoManager {
  final _$EventsDaoMixin _db;
  EventsDaoManager(this._db);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
  $$PossessionsTableTableManager get possessions =>
      $$PossessionsTableTableManager(_db.attachedDatabase, _db.possessions);
  $$PartiesTableTableManager get parties =>
      $$PartiesTableTableManager(_db.attachedDatabase, _db.parties);
  $$EvidenceItemsTableTableManager get evidenceItems =>
      $$EvidenceItemsTableTableManager(_db.attachedDatabase, _db.evidenceItems);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
}
