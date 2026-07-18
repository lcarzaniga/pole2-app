import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/places/application/place_tree.dart';

Place _p(String id, {String? parentId, String? name}) {
  final t = DateTime(2020);
  return Place(
    id: id,
    name: name ?? id,
    parentId: parentId,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  // Casa › Camera › Armadio › Ripiano ; Casa › Studio ; plus a second root Ufficio
  final places = [
    _p('casa', name: 'Casa'),
    _p('camera', parentId: 'casa', name: 'Camera'),
    _p('studio', parentId: 'casa', name: 'Studio'),
    _p('armadio', parentId: 'camera', name: 'Armadio'),
    _p('ripiano', parentId: 'armadio', name: 'Ripiano'),
    _p('ufficio', name: 'Ufficio'),
  ];

  test('roots and children are alphabetical', () {
    final tree = PlaceTree(places);
    expect(tree.roots.map((p) => p.id), ['casa', 'ufficio']);
    expect(tree.childrenOf('casa').map((p) => p.id), ['camera', 'studio']);
    expect(tree.childrenOf('ripiano'), isEmpty);
  });

  test('pathTo and ancestorsOf give the full chain', () {
    final tree = PlaceTree(places);
    expect(tree.pathTo('ripiano').map((p) => p.id), [
      'casa',
      'camera',
      'armadio',
      'ripiano',
    ]);
    expect(tree.ancestorsOf('ripiano').map((p) => p.id), [
      'casa',
      'camera',
      'armadio',
    ]);
    expect(tree.pathLabel('ripiano'), 'Casa › Camera › Armadio › Ripiano');
  });

  test('subtreeIds includes self and all descendants, once each', () {
    final tree = PlaceTree(places);
    expect(tree.subtreeIds('casa'), {
      'casa',
      'camera',
      'studio',
      'armadio',
      'ripiano',
    });
    expect(tree.subtreeIds('armadio'), {'armadio', 'ripiano'});
    expect(tree.subtreeIds('ufficio'), {'ufficio'});
  });

  test('direct and subtree counts, without double counting', () {
    final counts = {'casa': 3, 'armadio': 5, 'ripiano': 10};
    final tree = PlaceTree(places, counts);
    expect(tree.directCount('casa'), 3);
    expect(tree.directCount('camera'), 0);
    // Casa total = 3 (casa) + 5 (armadio) + 10 (ripiano) = 18.
    expect(tree.subtreeCount('casa'), 18);
    expect(tree.subtreeCount('armadio'), 15);
    expect(tree.subtreeCount('ripiano'), 10);
  });

  test('a node whose parent is absent surfaces as a root (no dangling)', () {
    final tree = PlaceTree([_p('orphan', parentId: 'ghost', name: 'Orfano')]);
    expect(tree.roots.map((p) => p.id), ['orphan']);
    expect(tree.pathTo('orphan').map((p) => p.id), ['orphan']);
  });

  test('a corrupt cycle never causes infinite recursion', () {
    // a → b → a (both non-null parents forming a loop).
    final cyclic = [_p('a', parentId: 'b'), _p('b', parentId: 'a')];
    final tree = PlaceTree(cyclic);
    // Traversals terminate and stay bounded.
    expect(tree.subtreeIds('a').length, lessThanOrEqualTo(2));
    expect(tree.pathTo('a').length, lessThanOrEqualTo(2));
    expect(() => tree.subtreeCount('a'), returnsNormally);
  });

  test(
    'same name under different parents is allowed and disambiguated by path',
    () {
      final dup = [
        _p('casa', name: 'Casa'),
        _p('c1', parentId: 'casa', name: 'Armadio'),
        _p('studio', parentId: 'casa', name: 'Studio'),
        _p('c2', parentId: 'studio', name: 'Armadio'),
      ];
      final tree = PlaceTree(dup);
      expect(tree.pathLabel('c1'), 'Casa › Armadio');
      expect(tree.pathLabel('c2'), 'Casa › Studio › Armadio');
    },
  );
}
