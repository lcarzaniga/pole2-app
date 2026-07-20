import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/shared/links/pole2_links.dart';
import 'package:project_kobe/shared/platform/external_link.dart';

/// Drives the `pole2/links` channel the way the real MainActivity does, so the
/// Dart facade's contract is exercised without a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('pole2/links');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The URLs that actually reached native. Empty means the Dart-side
  /// allowlist stopped the call before it left the app.
  late List<String> reached;

  void mockNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      reached.add(call.arguments['url'] as String);
      return handler(call);
    });
  }

  setUp(() => reached = <String>[]);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('opens a canonical Pole² https URL', () async {
    mockNative((_) async => true);
    final outcome = await openExternalUrl('https://pole2.app/guida/');
    expect(outcome, ExternalLinkOutcome.opened);
    expect(reached, ['https://pole2.app/guida/']);
  });

  test('opens the real support URL with its version/build query', () async {
    mockNative((_) async => true);
    final url = pole2LinkUrl(
      Pole2Link.support,
      version: '1.0.16',
      buildNumber: '2021',
    );
    expect(await openExternalUrl(url), ExternalLinkOutcome.opened);
    expect(reached.single, 'https://pole2.app/supporto/?v=1.0.16&b=2021');
  });

  test('a disallowed URL never reaches native at all', () async {
    mockNative((_) async => true);
    for (final url in const [
      'http://pole2.app/',
      'https://pole2.app.evil.com/',
      'https://evil-pole2.app/',
      'https://user:pw@pole2.app/',
      'https://pole2.app:8080/',
      'javascript:alert(1)',
      'not a url',
      '',
    ]) {
      expect(
        await openExternalUrl(url),
        ExternalLinkOutcome.rejected,
        reason: url,
      );
    }
    // The decisive assertion: the channel was never invoked.
    expect(reached, isEmpty);
  });

  test('no browser on the device is a calm noHandler, not a crash', () async {
    mockNative((_) async => throw PlatformException(code: 'no_handler'));
    expect(
      await openExternalUrl('https://pole2.app/'),
      ExternalLinkOutcome.noHandler,
    );
  });

  test('a native rejection is reported as rejected', () async {
    mockNative((_) async => throw PlatformException(code: 'rejected'));
    expect(
      await openExternalUrl('https://pole2.app/'),
      ExternalLinkOutcome.rejected,
    );
  });

  test('an unforeseen platform error is a calm failure', () async {
    mockNative((_) async => throw PlatformException(code: 'open_failed'));
    expect(
      await openExternalUrl('https://pole2.app/'),
      ExternalLinkOutcome.failed,
    );
  });

  test(
    'native returning false is a calm failure, never a false success',
    () async {
      mockNative((_) async => false);
      expect(
        await openExternalUrl('https://pole2.app/'),
        ExternalLinkOutcome.failed,
      );
    },
  );

  test('an unregistered channel degrades to unsupported', () async {
    // No mock handler at all — as on web, desktop, or a plain widget test.
    messenger.setMockMethodCallHandler(channel, null);
    expect(
      await openExternalUrl('https://pole2.app/'),
      ExternalLinkOutcome.unsupported,
    );
  });

  test('the allowlist is applied before any platform dispatch', () async {
    // Even with no channel registered, a bad URL is *rejected* (not
    // "unsupported") — proving the security rule runs first and identically on
    // every platform, including the web stub.
    messenger.setMockMethodCallHandler(channel, null);
    expect(
      await openExternalUrl('https://evil.com/'),
      ExternalLinkOutcome.rejected,
    );
  });
}
