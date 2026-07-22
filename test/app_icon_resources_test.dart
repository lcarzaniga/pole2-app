import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// M8.3B — verifies the production app-icon resources exist, are correctly
/// wired, and match the approved C-max canonical source. Reads files from the
/// project root (the `flutter test` working directory); no image dependency.
({int w, int h, int colorType}) pngInfo(File f) {
  final b = f.readAsBytesSync();
  final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
  final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
  return (w: w, h: h, colorType: b[25]); // colorType 6 = RGBA
}

const _densFg = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};
const _densLegacy = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  const res = 'android/app/src/main/res';
  const tool = 'tool/app_icon';

  test(
    'AndroidManifest references valid launcher and round-icon resources',
    () {
      final m = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(m.contains('android:icon="@mipmap/ic_launcher"'), isTrue);
      expect(
        m.contains('android:roundIcon="@mipmap/ic_launcher_round"'),
        isTrue,
      );
    },
  );

  test(
    'adaptive XML has background + foreground (+ monochrome), no baked inset',
    () {
      for (final name in ['ic_launcher', 'ic_launcher_round']) {
        final x = File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
        expect(x.contains('<background'), isTrue, reason: '$name background');
        expect(x.contains('<foreground'), isTrue, reason: '$name foreground');
        expect(x.contains('ic_launcher_foreground'), isTrue);
        expect(
          x.contains('<monochrome'),
          isTrue,
          reason: '$name monochrome (API 33+)',
        );
        expect(
          x.contains('android:inset'),
          isFalse,
          reason: '$name must not shrink C-max',
        );
      }
    },
  );

  test(
    'adaptive foreground + monochrome exist at every density with correct dims',
    () {
      _densFg.forEach((d, px) {
        for (final n in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
          final f = File('$res/drawable-$d/$n.png');
          expect(f.existsSync(), isTrue, reason: '$d/$n');
          final info = pngInfo(f);
          expect((info.w, info.h), (px, px), reason: '$d/$n dims');
          expect(info.colorType, 6, reason: '$d/$n must have alpha');
        }
      });
    },
  );

  test(
    'legacy square + round mipmaps exist at every density with correct dims',
    () {
      _densLegacy.forEach((d, px) {
        for (final n in ['ic_launcher', 'ic_launcher_round']) {
          final f = File('$res/mipmap-$d/$n.png');
          expect(f.existsSync(), isTrue, reason: '$d/$n');
          final info = pngInfo(f);
          expect((info.w, info.h), (px, px), reason: '$d/$n dims');
        }
      });
    },
  );

  test('store master 512 exists', () {
    final f = File('android/app/src/main/ic_launcher-playstore.png');
    expect(f.existsSync(), isTrue);
    final i = pngInfo(f);
    expect((i.w, i.h), (512, 512));
  });

  test('adaptive background is the approved clean lemon-yellow (no pattern)', () {
    final c = File('$res/values/colors.xml').readAsStringSync();
    expect(c.contains('ic_launcher_background'), isTrue);
    expect(c.toUpperCase().contains('#EBB94C'), isTrue,
        reason: 'approved warm lemon-yellow');
    // The adaptive background must be a solid colour, not a drawable/gradient.
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      final x = File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
      expect(x.contains('@color/ic_launcher_background'), isTrue,
          reason: '$name background is the solid colour');
    }
  });

  test(
    'web favicon + PWA icons exist with correct dimensions and are referenced',
    () {
      expect(
        (
          pngInfo(File('web/favicon.png')).w,
          pngInfo(File('web/favicon.png')).h,
        ),
        (16, 16),
      );
      for (final n in ['Icon-192', 'Icon-maskable-192']) {
        expect((pngInfo(File('web/icons/$n.png')).w), 192, reason: n);
      }
      for (final n in ['Icon-512', 'Icon-maskable-512']) {
        expect((pngInfo(File('web/icons/$n.png')).w), 512, reason: n);
      }
      final man = File('web/manifest.json').readAsStringSync();
      for (final n in [
        'Icon-192.png',
        'Icon-512.png',
        'Icon-maskable-192.png',
        'Icon-maskable-512.png',
      ]) {
        expect(man.contains(n), isTrue, reason: 'manifest references $n');
      }
      expect(
        File('web/index.html').readAsStringSync().contains('favicon.png'),
        isTrue,
      );
    },
  );

  test(
    'canonical source has exactly seven scutes; monochrome is single-colour',
    () {
      final fg = File('$tool/foreground.svg').readAsStringSync();
      final mono = File('$tool/monochrome.svg').readAsStringSync();
      expect(RegExp('class="scute"').allMatches(fg).length, 7);
      expect(RegExp('class="scute"').allMatches(mono).length, 7);
      final fills = RegExp(
        r'fill="(#[0-9A-Fa-f]{6})"',
      ).allMatches(mono).map((m) => m.group(1)!.toUpperCase()).toSet();
      expect(fills, {
        '#101613',
      }, reason: 'monochrome must be genuinely single-colour');
      // No text/bitmap/external URL/font/script in the canonical foreground
      // (ignore the standard SVG namespace, which is not an external fetch).
      final scan = fg.replaceAll('xmlns="http://www.w3.org/2000/svg"', '');
      for (final bad in [
        '<image',
        'data:',
        'http',
        'href',
        '<script',
        '<text',
        'font-face',
      ]) {
        expect(scan.contains(bad), isFalse, reason: 'foreground contains $bad');
      }
    },
  );

  test('foreground geometry stays within the approved C-max safe bounds', () {
    final fg = File('$tool/foreground.svg').readAsStringSync();
    double maxR = 0;
    bool inBox = true;
    void box(double x, double y) {
      if (x < -0.01 || x > 108.01 || y < -0.01 || y > 108.01) inBox = false;
    }

    double distC(double x, double y) =>
        math.sqrt(math.pow(x - 54, 2) + math.pow(y - 54, 2));
    // path coordinate pairs are real geometry: bound both box and radius.
    for (final m in RegExp(r'd="([^"]+)"').allMatches(fg)) {
      final n = RegExp(
        r'-?\d+\.?\d*',
      ).allMatches(m.group(1)!).map((e) => double.parse(e.group(0)!)).toList();
      for (var i = 0; i + 1 < n.length; i += 2) {
        box(n[i], n[i + 1]);
        maxR = math.max(maxR, distC(n[i], n[i + 1]));
      }
    }
    // circles/ellipses: the true farthest radial point is dist(centre)+r, not a
    // bounding-box corner (corners bound the box only).
    for (final m in RegExp(
      r'<circle[^>]*cx="([\d.]+)"[^>]*cy="([\d.]+)"[^>]*r="([\d.]+)"',
    ).allMatches(fg)) {
      final cx = double.parse(m.group(1)!),
          cy = double.parse(m.group(2)!),
          r = double.parse(m.group(3)!);
      maxR = math.max(maxR, distC(cx, cy) + r);
      box(cx - r, cy - r);
      box(cx + r, cy + r);
    }
    for (final m in RegExp(
      r'<ellipse[^>]*cx="([\d.]+)"[^>]*cy="([\d.]+)"[^>]*rx="([\d.]+)"[^>]*ry="([\d.]+)"',
    ).allMatches(fg)) {
      final cx = double.parse(m.group(1)!),
          cy = double.parse(m.group(2)!),
          rx = double.parse(m.group(3)!),
          ry = double.parse(m.group(4)!);
      maxR = math.max(maxR, distC(cx, cy) + math.max(rx, ry));
      box(cx - rx, cy - ry);
      box(cx + rx, cy + ry);
    }
    expect(inBox, isTrue, reason: 'geometry within the 108 foreground canvas');
    // Unclipped under an 88 dp circle (r44); approved C-max target is 42.
    expect(maxR, lessThanOrEqualTo(44.0), reason: 'maxR=$maxR');
  });

  test('no production build resource references a rejected/review concept', () {
    // Build-consumed config/resource files only (not provenance docs/generators).
    final dirs = [Directory('android'), Directory('web')];
    for (final dir in dirs) {
      for (final e in dir.listSync(recursive: true)) {
        if (e is! File) continue;
        if (!RegExp(r'\.(xml|json|html)$').hasMatch(e.path)) continue;
        final t = e.readAsStringSync();
        expect(
          t.contains('icon-concepts'),
          isFalse,
          reason: '${e.path} refs review concepts',
        );
        expect(
          t.contains('revision-2'),
          isFalse,
          reason: '${e.path} refs review concepts',
        );
      }
    }
  });

  test(
    'KobePainter / animated mascot source is unchanged (canonical markers present)',
    () {
      final p = File('lib/shared/brand/turtle_mascot.dart').readAsStringSync();
      expect(p.contains('_KobePainter'), isTrue);
      expect(
        p.contains('0.70 * _rx'),
        isTrue,
        reason: 'canonical central hexagon',
      );
      expect(p.contains('class TurtleMascot'), isTrue);
      // The icon pipeline must not import KobePainter.
      final gen = File('$tool/kobe_icon.py').readAsStringSync();
      expect(gen.contains('import turtle_mascot'), isFalse);
    },
  );
}
