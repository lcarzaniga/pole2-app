import 'package:flutter/services.dart';

import '../links/pole2_links.dart';
import 'external_link_outcome.dart';

const MethodChannel _channel = MethodChannel('pole2/links');

/// Opens [url] in the user's browser, if — and only if — it is a canonical
/// Pole² https address.
///
/// The allowlist is applied **here, before the channel call**, so a malformed
/// or unexpected URL never reaches native code; Kotlin then re-validates
/// independently before `startActivity`. Two checks, one rule
/// ([isAllowedPole2Url]).
///
/// Never throws: every failure mode becomes an [ExternalLinkOutcome] the caller
/// can turn into calm copy. A user cancelling in the browser chooser is
/// indistinguishable from success (the system consumed the intent) and is
/// correctly *not* an error.
///
/// Platform support is derived from the channel rather than from a hard-coded
/// `Platform.isAndroid`: only Android registers `pole2/links`, so anywhere else
/// (desktop, iOS, a test without a mock) raises [MissingPluginException] and
/// becomes [ExternalLinkOutcome.unsupported]. One fewer assumption to keep in
/// sync, and the facade stays exercisable off-device.
Future<ExternalLinkOutcome> openExternalUrl(String url) async {
  if (!isAllowedPole2Url(url)) return ExternalLinkOutcome.rejected;
  try {
    final opened = await _channel.invokeMethod<bool>('open', {'url': url});
    return opened == true
        ? ExternalLinkOutcome.opened
        : ExternalLinkOutcome.failed;
  } on PlatformException catch (e) {
    return switch (e.code) {
      'no_handler' => ExternalLinkOutcome.noHandler,
      'rejected' => ExternalLinkOutcome.rejected,
      _ => ExternalLinkOutcome.failed,
    };
  } on MissingPluginException {
    // The channel isn't registered (e.g. a widget test without a mock).
    return ExternalLinkOutcome.unsupported;
  }
}
