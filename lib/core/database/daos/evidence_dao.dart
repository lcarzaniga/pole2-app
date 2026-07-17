import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'evidence_dao.g.dart';

/// A document attached to a thing: the [EvidenceItem] paired with its backing
/// [StoredFile], so the UI can show a name and open the bytes without a second
/// lookup.
class PossessionDocument {
  const PossessionDocument({required this.evidence, required this.file});

  final EvidenceItem evidence;
  final StoredFile file;
}

/// Data access for evidence — the receipts, manuals and warranties a thing
/// carries. Evidence is many-to-many with possessions (one receipt can cover
/// several things), so a document is an [EvidenceItems] row backed by a [Files]
/// row and linked through [PossessionEvidence]. Reactive throughout.
@DriftAccessor(tables: [EvidenceItems, PossessionEvidence, Files])
class EvidenceDao extends DatabaseAccessor<AppDatabase>
    with _$EvidenceDaoMixin {
  EvidenceDao(super.db);

  static const _uuid = Uuid();

  /// Documents attached to [possessionId], newest first. Excludes soft-removed
  /// evidence; only rows with a backing file surface (a document is its file).
  Stream<List<PossessionDocument>> watchDocuments(String possessionId) {
    final query = select(possessionEvidence).join([
      innerJoin(
          evidenceItems, evidenceItems.id.equalsExp(possessionEvidence.evidenceId)),
      innerJoin(files, files.id.equalsExp(evidenceItems.fileId)),
    ])
      ..where(possessionEvidence.possessionId.equals(possessionId) &
          evidenceItems.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(possessionEvidence.addedAt)]);
    return query.watch().map((rows) => rows
        .map((r) => PossessionDocument(
              evidence: r.readTable(evidenceItems),
              file: r.readTable(files),
            ))
        .toList());
  }

  /// Stores an already-copied document (its bytes live on disk) as evidence and
  /// links it to [possessionId]. [label] is the original file name, shown to the
  /// user. Kept in one transaction so a document is never half-attached.
  Future<void> addDocument({
    required String possessionId,
    required String relativePath,
    required String mimeType,
    required int byteSize,
    String? label,
    EvidenceKind kind = EvidenceKind.other,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final fileId = _uuid.v4();
      await into(files).insert(FilesCompanion.insert(
        id: fileId,
        relativePath: relativePath,
        mimeType: mimeType,
        byteSize: byteSize,
        createdAt: now,
      ));
      final evidenceId = _uuid.v4();
      await into(evidenceItems).insert(EvidenceItemsCompanion.insert(
        id: evidenceId,
        kind: kind,
        label: Value(label),
        fileId: Value(fileId),
        createdAt: now,
        updatedAt: now,
      ));
      await into(possessionEvidence).insert(PossessionEvidenceCompanion.insert(
        possessionId: possessionId,
        evidenceId: evidenceId,
        addedAt: now,
      ));
    });
  }

  /// Soft-removes a document (tombstones the evidence) — recoverable via
  /// [restoreDocument]. The file bytes and link are left intact.
  Future<void> removeDocument(String evidenceId) {
    return (update(evidenceItems)..where((t) => t.id.equals(evidenceId))).write(
      EvidenceItemsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Undo for [removeDocument].
  Future<void> restoreDocument(String evidenceId) {
    return (update(evidenceItems)..where((t) => t.id.equals(evidenceId))).write(
      EvidenceItemsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
