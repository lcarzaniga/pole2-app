// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_dao.dart';

// ignore_for_file: type=lint
mixin _$PlacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlacesTable get places => attachedDatabase.places;
  $FilesTable get files => attachedDatabase.files;
  $PossessionsTable get possessions => attachedDatabase.possessions;
  PlacesDaoManager get managers => PlacesDaoManager(this);
}

class PlacesDaoManager {
  final _$PlacesDaoMixin _db;
  PlacesDaoManager(this._db);
  $$PlacesTableTableManager get places =>
      $$PlacesTableTableManager(_db.attachedDatabase, _db.places);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
  $$PossessionsTableTableManager get possessions =>
      $$PossessionsTableTableManager(_db.attachedDatabase, _db.possessions);
}
