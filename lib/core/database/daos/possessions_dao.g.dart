// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'possessions_dao.dart';

// ignore_for_file: type=lint
mixin _$PossessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FilesTable get files => attachedDatabase.files;
  $PossessionsTable get possessions => attachedDatabase.possessions;
  PossessionsDaoManager get managers => PossessionsDaoManager(this);
}

class PossessionsDaoManager {
  final _$PossessionsDaoMixin _db;
  PossessionsDaoManager(this._db);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
  $$PossessionsTableTableManager get possessions =>
      $$PossessionsTableTableManager(_db.attachedDatabase, _db.possessions);
}
