import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/application/gallery_order.dart';

/// A tiny stand-in so the ordering can be tested without any Drift rows.
typedef _P = ({String fileId});

void main() {
  String fid(_P p) => p.fileId;
  const a = (fileId: 'a');
  const b = (fileId: 'b');
  const c = (fileId: 'c');

  test('puts the cover first, keeping the rest in order', () {
    final out = orderCoverFirst([a, b, c], fileId: fid, coverFileId: 'b');
    expect(out.map(fid).toList(), ['b', 'a', 'c']);
  });

  test('a null cover leaves the stored order untouched', () {
    final out = orderCoverFirst([a, b, c], fileId: fid, coverFileId: null);
    expect(out.map(fid).toList(), ['a', 'b', 'c']);
  });

  test('a cover id not present is a no-op ordering', () {
    final out = orderCoverFirst([a, b, c], fileId: fid, coverFileId: 'zzz');
    expect(out.map(fid).toList(), ['a', 'b', 'c']);
  });

  test('the cover already first stays first', () {
    final out = orderCoverFirst([a, b, c], fileId: fid, coverFileId: 'a');
    expect(out.map(fid).toList(), ['a', 'b', 'c']);
  });

  test('empty stays empty', () {
    expect(orderCoverFirst(<_P>[], fileId: fid, coverFileId: 'a'), isEmpty);
  });
}
