import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';

/// M9 — a record's optional end-of-validity date drives the existing reminder
/// pipeline **only when the owner explicitly opted in** (a `remindLead` is set).
/// A stored-but-silent end date must never surface a reminder.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final soon = DateTime.now().add(const Duration(days: 30));

  Future<String> possession() async =>
      (await db.possessionsDao.createPossession(title: 'Caldaia')).id;

  test('a validity end date WITHOUT a lead creates no reminder', () async {
    final p = await possession();
    await db.evidenceDao.createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.warranty,
      at: DateTime.now(),
      endsAt: soon,
      notes: 'Garanzia',
      // remindLead intentionally null → stored & displayed, never a reminder.
    );
    final reminders = await db.eventsDao.watchUpcomingReminders().first;
    expect(reminders, isEmpty);
  });

  test('a validity end date WITH an explicit lead surfaces a reminder dated by '
      'the end date', () async {
    final p = await possession();
    await db.evidenceDao.createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.insurance,
      at: DateTime.now(),
      endsAt: soon,
      notes: 'Assicurazione',
      remindLead: ReminderLead.weekBefore,
    );
    final reminders = await db.eventsDao.watchUpcomingReminders().first;
    expect(reminders, hasLength(1));
    expect(reminders.single.at, soon); // dated by the end of validity
    expect(reminders.single.possessionTitle, 'Caldaia');
  });

  test('a returned loan never resurfaces via the validity clause', () async {
    // Regression guard: the new validity clause must not match a done loan that
    // happens to carry endsAt + remindLead.
    final p = await possession();
    final loan = await db.eventsDao.lend(
      possessionId: p,
      personName: 'Marco',
      lentAt: DateTime.now(),
      expectedReturn: soon,
      lead: ReminderLead.dayBefore,
    );
    expect(await db.eventsDao.watchUpcomingReminders().first, hasLength(1));
    await db.eventsDao.returnLoan(
      possessionId: p,
      loanEventId: loan!.id,
      returnedAt: DateTime.now(),
    );
    expect(await db.eventsDao.watchUpcomingReminders().first, isEmpty);
  });
}
