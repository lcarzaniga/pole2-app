import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/features/possessions/application/archive_query.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

void main() {
  test('lifecycleLabel maps every status exhaustively (Italian)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('it'));
    expect(lifecycleLabel(l10n, PossessionStatus.active), '');
    expect(lifecycleLabel(l10n, PossessionStatus.archived), 'Messo da parte');
    expect(lifecycleLabel(l10n, PossessionStatus.transferred), 'Dato');
    expect(lifecycleLabel(l10n, PossessionStatus.lost), 'Smarrito');
    expect(lifecycleLabel(l10n, PossessionStatus.disposed), 'Dismesso');
    // Exhaustive by construction: a new enum value would fail to compile the
    // switch in archive_query.dart, forcing a label to be added.
    for (final s in PossessionStatus.values) {
      expect(lifecycleLabel(l10n, s), isNotNull);
    }
  });

  group('filterArchiveBySearch', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<Possession> make(String title, {String? category}) =>
        db.possessionsDao.createPossession(title: title, category: category);

    test('empty search returns everything, order preserved', () async {
      final a = await make('Trapano');
      final b = await make('Martello');
      final out = filterArchiveBySearch([a, b], '   ');
      expect(out.map((p) => p.id).toList(), [a.id, b.id]);
    });

    test('matches title or category, case-insensitively', () async {
      final a = await make('Trapano', category: 'Utensili');
      final b = await make('Bici', category: 'Sport');
      expect(filterArchiveBySearch([a, b], 'trap').map((p) => p.id), [a.id]);
      expect(filterArchiveBySearch([a, b], 'SPORT').map((p) => p.id), [b.id]);
      expect(filterArchiveBySearch([a, b], 'zzz'), isEmpty);
    });
  });
}
