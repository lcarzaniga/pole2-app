// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_dao.dart';

// ignore_for_file: type=lint
mixin _$EvidenceDaoMixin on DatabaseAccessor<AppDatabase> {
  $FilesTable get files => attachedDatabase.files;
  $EvidenceItemsTable get evidenceItems => attachedDatabase.evidenceItems;
  $PlacesTable get places => attachedDatabase.places;
  $PossessionsTable get possessions => attachedDatabase.possessions;
  $PossessionEvidenceTable get possessionEvidence =>
      attachedDatabase.possessionEvidence;
  EvidenceDaoManager get managers => EvidenceDaoManager(this);
}

class EvidenceDaoManager {
  final _$EvidenceDaoMixin _db;
  EvidenceDaoManager(this._db);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
  $$EvidenceItemsTableTableManager get evidenceItems =>
      $$EvidenceItemsTableTableManager(_db.attachedDatabase, _db.evidenceItems);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$PossessionsTableTableManager get possessions =>
      $$PossessionsTableTableManager(_db.attachedDatabase, _db.possessions);
  $$PossessionEvidenceTableTableManager get possessionEvidence =>
      $$PossessionEvidenceTableTableManager(
        _db.attachedDatabase,
        _db.possessionEvidence,
      );
}
