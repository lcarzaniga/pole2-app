import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/shared/links/pole2_links.dart';

void main() {
  group('the five public addresses', () {
    test('are exactly the canonical URLs, with no query except support', () {
      expect(pole2LinkUrl(Pole2Link.site), 'https://pole2.app/');
      expect(pole2LinkUrl(Pole2Link.guide), 'https://pole2.app/guida/');
      expect(pole2LinkUrl(Pole2Link.news), 'https://pole2.app/novita/');
      expect(pole2LinkUrl(Pole2Link.privacy), 'https://pole2.app/privacy/');
      expect(
        pole2LinkUrl(Pole2Link.support, version: '1.0.16', buildNumber: '2021'),
        'https://pole2.app/supporto/?v=1.0.16&b=2021',
      );
    });

    test('every link passes the app\'s own allowlist', () {
      for (final link in Pole2Link.values) {
        expect(
          isAllowedPole2Url(
            pole2LinkUrl(link, version: '1.0.16', buildNumber: '2021'),
          ),
          isTrue,
          reason: '$link must be openable',
        );
      }
    });

    test('non-support links never carry a query at all', () {
      for (final link in Pole2Link.values.where(
        (l) => l != Pole2Link.support,
      )) {
        final uri = Uri.parse(pole2LinkUrl(link));
        expect(uri.hasQuery, isFalse, reason: '$link must be a bare path');
      }
    });
  });

  group('support URL', () {
    test('carries only v and b — no telemetry of any kind', () {
      final uri = Uri.parse(supportUrl(version: '1.0.16', buildNumber: '2021'));
      expect(uri.scheme, 'https');
      expect(uri.host, 'pole2.app');
      expect(uri.path, '/supporto/');
      // The complete set of parameters, asserted exhaustively: anything added
      // later (device id, model, email, installation id) fails this test.
      expect(uri.queryParameters.keys.toSet(), {'v', 'b'});
      expect(uri.queryParameters['v'], '1.0.16');
      expect(uri.queryParameters['b'], '2021');
    });

    test('percent-encodes values that could otherwise break out', () {
      // A hostile/unusual version string must not be able to inject another
      // parameter or a fragment.
      final uri = Uri.parse(
        supportUrl(version: '1.0 &b=9&x=y#frag', buildNumber: '20 21'),
      );
      expect(uri.queryParameters.keys.toSet(), {'v', 'b'});
      expect(uri.queryParameters['v'], '1.0 &b=9&x=y#frag');
      expect(uri.queryParameters['b'], '20 21');
      expect(uri.fragment, isEmpty);
    });

    test('omits unknown values rather than sending them blank', () {
      expect(supportUrl(), 'https://pole2.app/supporto/');
      expect(
        Uri.parse(supportUrl(version: '1.0.16')).queryParameters.keys.toSet(),
        {'v'},
      );
      expect(
        supportUrl(version: '', buildNumber: ''),
        'https://pole2.app/supporto/',
      );
    });
  });

  group('the allowlist accepts only canonical Pole² https URLs', () {
    test('accepts the canonical host', () {
      expect(isAllowedPole2Url('https://pole2.app/'), isTrue);
      expect(isAllowedPole2Url('https://pole2.app/guida/'), isTrue);
      expect(isAllowedPole2Url('https://POLE2.APP/guida/'), isTrue);
      expect(isAllowedPole2Url('https://pole2.app:443/guida/'), isTrue);
    });

    test('rejects non-https schemes', () {
      for (final url in const [
        'http://pole2.app/',
        'ftp://pole2.app/',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'intent://pole2.app/#Intent;scheme=https;end',
        'data:text/html,<script>alert(1)</script>',
      ]) {
        expect(isAllowedPole2Url(url), isFalse, reason: url);
      }
    });

    test('rejects deceptive prefix/suffix hosts', () {
      for (final url in const [
        'https://pole2.app.evil.com/',
        'https://evil-pole2.app/',
        'https://xpole2.app/',
        'https://pole2.appevil.com/',
        'https://pole2.app.co/',
        'https://sub.pole2.app/', // subdomains are deliberately not allowed
        'https://evil.com/https://pole2.app/',
        'https://evil.com/?next=https://pole2.app/',
      ]) {
        expect(isAllowedPole2Url(url), isFalse, reason: url);
      }
    });

    test('rejects embedded credentials', () {
      expect(isAllowedPole2Url('https://user:pw@pole2.app/'), isFalse);
      expect(isAllowedPole2Url('https://pole2.app@evil.com/'), isFalse);
      expect(isAllowedPole2Url('https://user@pole2.app/'), isFalse);
    });

    test('rejects non-default ports', () {
      expect(isAllowedPole2Url('https://pole2.app:8080/'), isFalse);
      expect(isAllowedPole2Url('https://pole2.app:80/'), isFalse);
    });

    test('rejects malformed, relative and empty input', () {
      for (final url in const [
        '',
        '   ',
        'not a url',
        '/guida/',
        'pole2.app/guida/',
        '//pole2.app/guida/',
        'https://',
        'https:///guida/',
      ]) {
        expect(isAllowedPole2Url(url), isFalse, reason: '"$url"');
      }
    });
  });
}
