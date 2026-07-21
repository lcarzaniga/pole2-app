import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/media/photo_import_marker.dart';

/// M8.2D — the durable operation marker: round-trip, strict parsing, path safety.
void main() {
  PhotoImportMarker marker(String op, PhotoImportState state) =>
      PhotoImportMarker(
        operationId: op,
        state: state,
        createdAtUtc: '2026-07-21T00:00:00.000Z',
        entries: [
          PhotoImportEntry(
            fileId: 'f1',
            tempRelativePath: 'photo_imports/$op/f1.jpg',
            finalRelativePath: 'photos/f1.jpg',
            byteSize: 10,
            mimeType: 'image/jpeg',
          ),
        ],
      );

  test('encode/decode round-trips', () {
    final m = marker('op1', PhotoImportState.promoted);
    final back = PhotoImportMarker.decode(m.encode());
    expect(back, isNotNull);
    expect(back!.operationId, 'op1');
    expect(back.state, PhotoImportState.promoted);
    expect(back.entries.single.finalRelativePath, 'photos/f1.jpg');
  });

  test('decode rejects malformed / wrong-typed markers', () {
    expect(PhotoImportMarker.decode('not json'), isNull);
    expect(PhotoImportMarker.decode('[]'), isNull);
    expect(PhotoImportMarker.decode('{"operationId":"x"}'), isNull);
    expect(
      PhotoImportMarker.decode(
        '{"operationId":"x","state":"weird","createdAtUtc":"t","entries":[]}',
      ),
      isNull,
    );
    expect(
      PhotoImportMarker.decode(
        '{"operationId":"x","state":"prepared","createdAtUtc":"t","entries":[{"fileId":1}]}',
      ),
      isNull,
    );
  });

  test('pathsSafe accepts safe temp/final and rejects traversal/absolute', () {
    expect(marker('op1', PhotoImportState.prepared).pathsSafe(), isTrue);

    final traversal = PhotoImportMarker(
      operationId: 'op1',
      state: PhotoImportState.prepared,
      createdAtUtc: 't',
      entries: const [
        PhotoImportEntry(
          fileId: 'f',
          tempRelativePath: 'photo_imports/op1/../../evil.jpg',
          finalRelativePath: 'photos/f.jpg',
          byteSize: 1,
          mimeType: 'image/jpeg',
        ),
      ],
    );
    expect(traversal.pathsSafe(), isFalse);

    final wrongFinalRoot = PhotoImportMarker(
      operationId: 'op1',
      state: PhotoImportState.prepared,
      createdAtUtc: 't',
      entries: const [
        PhotoImportEntry(
          fileId: 'f',
          tempRelativePath: 'photo_imports/op1/f.jpg',
          finalRelativePath: 'other/f.jpg',
          byteSize: 1,
          mimeType: 'image/jpeg',
        ),
      ],
    );
    expect(wrongFinalRoot.pathsSafe(), isFalse);

    // Temp path not under this operation's directory.
    final wrongOp = PhotoImportMarker(
      operationId: 'op1',
      state: PhotoImportState.prepared,
      createdAtUtc: 't',
      entries: const [
        PhotoImportEntry(
          fileId: 'f',
          tempRelativePath: 'photo_imports/other/f.jpg',
          finalRelativePath: 'photos/f.jpg',
          byteSize: 1,
          mimeType: 'image/jpeg',
        ),
      ],
    );
    expect(wrongOp.pathsSafe(), isFalse);
  });

  test('isSafeOperationId rejects separators and traversal', () {
    expect(isSafeOperationId('abc-123_DEF'), isTrue);
    expect(isSafeOperationId(''), isFalse);
    expect(isSafeOperationId('a/b'), isFalse);
    expect(isSafeOperationId('..'), isFalse);
    expect(isSafeOperationId('a.b'), isFalse);
    expect(isSafeOperationId('x' * 65), isFalse);
  });
}
