import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/backup_limits.dart';
import '../domain/backup_manifest.dart';
import '../domain/safe_path.dart';
import 'backup_plan.dart';

/// Enumerates the physical files a backup must include, reading references from
/// the **snapshot** database (never the live one), so the file list matches the
/// exact bytes being archived.
///
/// Included: every file referenced by a restorable row — `possessions.cover_file_id`,
/// every `possession_photos.file_id` (active *and* soft-deleted/restorable), and
/// non-deleted `evidence_items.file_id`. Orphan files under `photos/` that no row
/// references are excluded. Missing-media policy:
/// - a missing file behind an **active** cover/gallery reference → stop (throw);
/// - a missing file behind a **dormant** (soft-deleted photo / evidence) reference
///   → skip with a recorded warning.
/// An unsafe stored path always stops the backup.
class BackupEnumerator {
  const BackupEnumerator();

  BackupPlan enumerate({
    required File snapshotDb,
    required Directory documentsDir,
  }) {
    final db = sqlite3.open(snapshotDb.path, mode: OpenMode.readOnly);
    try {
      // fileId -> relativePath
      final relById = <String, String>{};
      for (final row in db.select('SELECT id, relative_path FROM files')) {
        relById[row['id'] as String] = row['relative_path'] as String;
      }

      // Aggregate references per fileId.
      final refs = <String, _Ref>{};
      void add(String fileId, String kind, bool active, String desc) {
        final r = refs.putIfAbsent(fileId, () => _Ref(desc));
        r.kinds.add(kind);
        if (active) r.active = true;
      }

      for (final row in db.select(
        'SELECT title, cover_file_id FROM possessions '
        'WHERE cover_file_id IS NOT NULL',
      )) {
        add(
          row['cover_file_id'] as String,
          ReferenceKind.cover,
          true,
          (row['title'] as String?) ?? 'oggetto',
        );
      }
      for (final row in db.select(
        'SELECT pp.file_id AS fid, pp.deleted_at AS del, po.title AS title '
        'FROM possession_photos pp '
        'LEFT JOIN possessions po ON po.id = pp.possession_id',
      )) {
        final active = row['del'] == null;
        add(
          row['fid'] as String,
          active
              ? ReferenceKind.galleryActive
              : ReferenceKind.gallerySoftDeleted,
          active,
          (row['title'] as String?) ?? 'oggetto',
        );
      }
      for (final row in db.select(
        'SELECT file_id FROM evidence_items '
        'WHERE file_id IS NOT NULL AND deleted_at IS NULL',
      )) {
        add(
          row['file_id'] as String,
          ReferenceKind.evidence,
          false,
          'allegato',
        );
      }

      final planned = <PlannedFile>[];
      final warnings = <String>[];
      final usedPaths = <String>{};

      for (final entry in refs.entries) {
        final fileId = entry.key;
        final ref = entry.value;
        final raw = relById[fileId];
        if (raw == null) {
          if (ref.active) {
            throw BackupIncompleteException(ref.description);
          }
          warnings.add('Riferimento senza file: «${ref.description}».');
          continue;
        }
        final rel = normalizeRelativePath(raw);
        if (rel == null) {
          // Unsafe stored path always blocks — never archive it.
          throw BackupIncompleteException(ref.description);
        }
        if (!usedPaths.add(rel)) {
          throw BackupIncompleteException(ref.description); // path collision
        }
        final source = File(p.join(documentsDir.path, rel));
        if (!source.existsSync()) {
          if (ref.active) {
            throw BackupIncompleteException(ref.description);
          }
          warnings.add('Foto non più presente: «${ref.description}».');
          continue;
        }
        planned.add(
          PlannedFile(
            fileId: fileId,
            relativePath: rel,
            archivePath: '$kFilesPrefix$rel',
            source: source,
            referenceKinds: ref.kinds.toList()..sort(),
          ),
        );
      }

      // Deterministic order by archive path.
      planned.sort((a, b) => a.archivePath.compareTo(b.archivePath));

      return BackupPlan(
        files: planned,
        warnings: warnings,
        counts: _counts(db, planned.length),
      );
    } finally {
      db.close();
    }
  }

  Map<String, int> _counts(Database db, int physicalFiles) {
    int one(String sql) => db.select(sql).first.values.first as int;
    return {
      'possessions': one('SELECT COUNT(*) FROM possessions'),
      'places': one('SELECT COUNT(*) FROM places'),
      'people': one("SELECT COUNT(*) FROM parties WHERE kind = 'person'"),
      'events': one('SELECT COUNT(*) FROM events'),
      'photos': one(
        'SELECT COUNT(*) FROM possession_photos WHERE deleted_at IS NULL',
      ),
      'physicalFiles': physicalFiles,
    };
  }
}

class _Ref {
  _Ref(this.description);
  final String description;
  final Set<String> kinds = {};
  bool active = false;
}
