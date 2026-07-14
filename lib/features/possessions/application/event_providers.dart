import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/events_dao.dart';
import '../../../core/providers/database_provider.dart';

// Hand-written for the same reason as possession_providers: the Riverpod
// generator can't resolve Drift's generated row types in return positions.

final eventsDaoProvider = Provider<EventsDao>(
  (ref) => ref.watch(databaseProvider).eventsDao,
);

/// The single acquisition for a thing (or null).
final acquisitionProvider = StreamProvider.family<PossessionEvent?, String>(
  (ref, id) => ref.watch(eventsDaoProvider).watchAcquisition(id),
);

/// A thing's full timeline, oldest first.
final timelineProvider = StreamProvider.family<List<PossessionEvent>, String>(
  (ref, id) => ref.watch(eventsDaoProvider).watchTimeline(id),
);

/// A supplier (party) by id — to resolve its name for display.
final partyProvider = StreamProvider.family<Party?, String>(
  (ref, id) => ref.watch(eventsDaoProvider).watchParty(id),
);

/// All upcoming reminders across active things, soonest first — powers the
/// calm Home summary.
final upcomingRemindersProvider = StreamProvider<List<UpcomingReminder>>(
  (ref) => ref.watch(eventsDaoProvider).watchUpcomingReminders(),
);
