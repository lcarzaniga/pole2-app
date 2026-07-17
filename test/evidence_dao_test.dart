import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> add(String possessionId, String name) => db.evidenceDao.addDocument(
        possessionId: possessionId,
        relativePath: 'documents/$name',
        mimeType: 'application/pdf',
        byteSize: 1234,
        label: name,
      );

  test('addDocument attaches a document with its backing file', () async {
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    await add(p.id, 'ricevuta.pdf');

    final docs = await db.evidenceDao.watchDocuments(p.id).first;
    expect(docs, hasLength(1));
    expect(docs.single.evidence.label, 'ricevuta.pdf');
    expect(docs.single.file.relativePath, 'documents/ricevuta.pdf');
    expect(docs.single.file.mimeType, 'application/pdf');
  });

  test('watchDocuments is scoped to the possession and newest-first', () async {
    final a = await db.possessionsDao.createPossession(title: 'A');
    final b = await db.possessionsDao.createPossession(title: 'B');

    await add(a.id, 'first.pdf');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await add(a.id, 'second.pdf');
    await add(b.id, 'other.pdf'); // belongs to b, must not leak into a

    final aDocs = await db.evidenceDao.watchDocuments(a.id).first;
    expect(aDocs.map((d) => d.evidence.label), ['second.pdf', 'first.pdf']);

    final bDocs = await db.evidenceDao.watchDocuments(b.id).first;
    expect(bDocs.map((d) => d.evidence.label), ['other.pdf']);
  });

  test('a document can be removed and restored', () async {
    final p = await db.possessionsDao.createPossession(title: 'Bici');
    await add(p.id, 'garanzia.pdf');
    final id = (await db.evidenceDao.watchDocuments(p.id).first).single.evidence.id;

    await db.evidenceDao.removeDocument(id);
    expect(await db.evidenceDao.watchDocuments(p.id).first, isEmpty);

    await db.evidenceDao.restoreDocument(id);
    expect(await db.evidenceDao.watchDocuments(p.id).first, hasLength(1));
  });
}
