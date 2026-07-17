import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/evidence_dao.dart';
import '../../../core/providers/database_provider.dart';

// Hand-written for the same reason as the other providers here: the Riverpod
// generator can't resolve Drift's generated row types in return positions.

/// The evidence data access, resolved from the app database.
final evidenceDaoProvider = Provider<EvidenceDao>(
  (ref) => ref.watch(databaseProvider).evidenceDao,
);

/// Reactive documents attached to a thing, newest first — powers the detail
/// screen's documents section.
final documentsByPossessionProvider =
    StreamProvider.family<List<PossessionDocument>, String>(
  (ref, id) => ref.watch(evidenceDaoProvider).watchDocuments(id),
);
