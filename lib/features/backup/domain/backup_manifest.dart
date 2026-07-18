/// The backup manifest — the source of truth for what a `.pole2backup` contains.
/// Pure model + JSON (de)serialization, no IO, so it's unit-testable.
library;

/// How a physical file is referenced by the database (for diagnostics/warnings).
class ReferenceKind {
  static const cover = 'cover';
  static const galleryActive = 'galleryActive';
  static const gallerySoftDeleted = 'gallerySoftDeleted';
  static const evidence = 'evidence';
}

/// One included physical file.
class BackupFileEntry {
  const BackupFileEntry({
    required this.fileId,
    required this.archivePath,
    required this.originalRelativePath,
    required this.byteSize,
    required this.sha256,
    required this.referenceKinds,
  });

  /// The `Files.id` this came from (always set in M6.0).
  final String? fileId;

  /// Canonical path inside the ZIP, e.g. `files/photos/uuid.jpg`.
  final String archivePath;

  /// The original `Files.relativePath`, e.g. `photos/uuid.jpg`.
  final String originalRelativePath;
  final int byteSize;
  final String sha256;
  final List<String> referenceKinds;

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'archivePath': archivePath,
    'originalRelativePath': originalRelativePath,
    'byteSize': byteSize,
    'sha256': sha256,
    'referenceKinds': referenceKinds,
  };

  static BackupFileEntry fromJson(Map<String, dynamic> j) => BackupFileEntry(
    fileId: j['fileId'] as String?,
    archivePath: j['archivePath'] as String,
    originalRelativePath: j['originalRelativePath'] as String,
    byteSize: (j['byteSize'] as num).toInt(),
    sha256: j['sha256'] as String,
    referenceKinds: (j['referenceKinds'] as List).cast<String>(),
  );
}

/// The database entry inside the archive.
class BackupDatabaseEntry {
  const BackupDatabaseEntry({
    required this.archivePath,
    required this.byteSize,
    required this.sha256,
  });

  final String archivePath;
  final int byteSize;
  final String sha256;

  Map<String, dynamic> toJson() => {
    'archivePath': archivePath,
    'byteSize': byteSize,
    'sha256': sha256,
  };

  static BackupDatabaseEntry fromJson(Map<String, dynamic> j) =>
      BackupDatabaseEntry(
        archivePath: j['archivePath'] as String,
        byteSize: (j['byteSize'] as num).toInt(),
        sha256: j['sha256'] as String,
      );
}

/// Human/record counts, useful for the validation summary.
class BackupCounts {
  const BackupCounts({
    required this.possessions,
    required this.places,
    required this.people,
    required this.events,
    required this.photos,
    required this.physicalFiles,
  });

  final int possessions;
  final int places;
  final int people;
  final int events;
  final int photos;
  final int physicalFiles;

  Map<String, dynamic> toJson() => {
    'possessions': possessions,
    'places': places,
    'people': people,
    'events': events,
    'photos': photos,
    'physicalFiles': physicalFiles,
  };

  static BackupCounts fromJson(Map<String, dynamic> j) => BackupCounts(
    possessions: (j['possessions'] as num).toInt(),
    places: (j['places'] as num).toInt(),
    people: (j['people'] as num).toInt(),
    events: (j['events'] as num).toInt(),
    photos: (j['photos'] as num).toInt(),
    physicalFiles: (j['physicalFiles'] as num).toInt(),
  );
}

class BackupManifest {
  const BackupManifest({
    required this.backupFormatVersion,
    required this.appVersion,
    required this.versionCode,
    required this.databaseSchemaVersion,
    required this.createdAtUtc,
    required this.platform,
    required this.encrypted,
    required this.database,
    required this.files,
    required this.counts,
    required this.warnings,
    required this.totalUncompressedBytes,
  });

  final int backupFormatVersion;
  final String appVersion;
  final int versionCode;
  final int databaseSchemaVersion;
  final String createdAtUtc;
  final String platform;
  final bool encrypted;
  final BackupDatabaseEntry database;
  final List<BackupFileEntry> files;
  final BackupCounts counts;
  final List<String> warnings;
  final int totalUncompressedBytes;

  Map<String, dynamic> toJson() => {
    'backupFormatVersion': backupFormatVersion,
    'appVersion': appVersion,
    'versionCode': versionCode,
    'databaseSchemaVersion': databaseSchemaVersion,
    'createdAtUtc': createdAtUtc,
    'platform': platform,
    'encrypted': encrypted,
    'database': database.toJson(),
    'files': files.map((f) => f.toJson()).toList(),
    'counts': counts.toJson(),
    'warnings': warnings,
    'totalUncompressedBytes': totalUncompressedBytes,
  };

  static BackupManifest fromJson(Map<String, dynamic> j) => BackupManifest(
    backupFormatVersion: (j['backupFormatVersion'] as num).toInt(),
    appVersion: j['appVersion'] as String,
    versionCode: (j['versionCode'] as num).toInt(),
    databaseSchemaVersion: (j['databaseSchemaVersion'] as num).toInt(),
    createdAtUtc: j['createdAtUtc'] as String,
    platform: j['platform'] as String,
    encrypted: j['encrypted'] as bool,
    database: BackupDatabaseEntry.fromJson(
      j['database'] as Map<String, dynamic>,
    ),
    files: (j['files'] as List)
        .map((e) => BackupFileEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    counts: BackupCounts.fromJson(j['counts'] as Map<String, dynamic>),
    warnings: (j['warnings'] as List).cast<String>(),
    totalUncompressedBytes: (j['totalUncompressedBytes'] as num).toInt(),
  );
}
