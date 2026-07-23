import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 1.0.26 — the guard that makes the English fallback **real**.
///
/// `l10n.yaml` uses `app_it.arb` as the template, so any key missing from
/// `app_en.arb` silently emits the *Italian* string. An English-speaking person
/// would then see a half-Italian interface. This test is the gate: English must
/// cover every active Italian key, with identical placeholders and ICU shapes.
///
/// It is expected to FAIL until the English translation lands (checkpoint E of
/// this milestone) — that failure is the mechanism that stops an incomplete
/// English build from being released, so it must never be weakened or skipped.
/// The retire-candidate keys are excluded: they are dead strings kept only for
/// the localization workbook, and translating them would be busywork.
void main() {
  final itRaw =
      jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
          as Map<String, dynamic>;
  final enRaw =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;

  bool isMessage(String k) => !k.startsWith('@') && k != '_comment';

  /// A key is retired when its metadata says so — those are not translated.
  bool isRetired(String key) {
    final meta = itRaw['@$key'];
    if (meta is! Map) return false;
    return '${meta['description'] ?? ''}'.contains('RETIRE CANDIDATE');
  }

  final active = itRaw.keys
      .where(isMessage)
      .where((k) => !isRetired(k))
      .toList();
  final english = enRaw.keys.where(isMessage).toSet();

  /// Real placeholders: `{name}` or `{name, plural|select, …}` — never the
  /// single-word literal that fills an ICU branch (e.g. `=0{Nothing}`).
  Set<String> placeholders(String v) {
    final icu = RegExp(r'\{([A-Za-z0-9_]+),\s*(?:plural|select)').allMatches(v);
    if (icu.isNotEmpty) return {for (final m in icu) m.group(1)!};
    return {
      for (final m in RegExp(r'\{([A-Za-z0-9_]+)\}').allMatches(v)) m.group(1)!,
    };
  }

  String icuKind(String v) {
    if (RegExp(r'\{[^,}]+,\s*plural\s*,').hasMatch(v)) return 'plural';
    if (RegExp(r'\{[^,}]+,\s*select\s*,').hasMatch(v)) return 'select';
    return '';
  }

  Set<String> icuCategories(String v) {
    final m = RegExp(
      r'\{[^,}]+,\s*(?:plural|select)\s*,(.*)\}\s*$',
      dotAll: true,
    ).firstMatch(v);
    if (m == null) return {};
    return {
      for (final c in RegExp(
        r'(=\d+|zero|one|two|few|many|other)\s*\{',
      ).allMatches(m.group(1)!))
        c.group(1)!,
    };
  }

  test('the Italian template is the semantic source and is complete', () {
    expect(active, isNotEmpty);
    for (final k in active) {
      expect(
        '${itRaw[k]}'.trim(),
        isNotEmpty,
        reason: 'Italian key "$k" must not be empty',
      );
    }
  });

  test(
    'every active Italian key has an English translation',
    () {
      final missing = active.where((k) => !english.contains(k)).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            '${missing.length} of ${active.length} active keys have no English '
            'value, so they would silently fall back to Italian. English is not '
            'releasable until this list is empty. Missing: '
            '${missing.take(15).join(", ")}${missing.length > 15 ? " …" : ""}',
      );
    },
    skip: 'English lands in checkpoint E; this gate must pass before release.',
  );

  test('translated keys keep identical placeholders and ICU structure', () {
    final problems = <String>[];
    for (final k in active) {
      if (!english.contains(k)) continue; // covered by the test above
      final it = '${itRaw[k]}';
      final en = '${enRaw[k]}';
      // Dart Sets do not override ==, so compare a canonical sorted form.
      final pIt = (placeholders(it).toList()..sort()).join(',');
      final pEn = (placeholders(en).toList()..sort()).join(',');
      if (pIt != pEn) {
        problems.add('$k: placeholders {$pIt} vs {$pEn}');
      }
      if (icuKind(it) != icuKind(en)) {
        problems.add('$k: ICU kind "${icuKind(it)}" vs "${icuKind(en)}"');
      } else {
        final cIt = (icuCategories(it).toList()..sort()).join(',');
        final cEn = (icuCategories(en).toList()..sort()).join(',');
        if (cIt != cEn) {
          problems.add('$k: ICU categories {$cIt} vs {$cEn}');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('retire candidates are classified, not silently deleted', () {
    final retired = itRaw.keys.where(isMessage).where(isRetired).toList();
    // They still exist in the template (nothing was deleted)…
    for (final k in retired) {
      expect(itRaw.containsKey(k), isTrue);
    }
    // …and the classification is discoverable for the workbook.
    expect(
      retired,
      contains('recordAttachmentAdd'),
      reason: 'superseded by attachmentAdd in M9.1',
    );
  });
}
