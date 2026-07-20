import '../links/pole2_links.dart';
import 'external_link_outcome.dart';

/// Web/other-platform stub: there is no external-link channel here, so this
/// degrades gracefully and keeps `flutter build web` compiling.
///
/// It still applies the allowlist first, so the security rule holds identically
/// on every platform: an unexpected URL is [ExternalLinkOutcome.rejected]
/// everywhere, and a legitimate one is honestly reported as
/// [ExternalLinkOutcome.unsupported] rather than silently pretending to work.
Future<ExternalLinkOutcome> openExternalUrl(String url) async {
  if (!isAllowedPole2Url(url)) return ExternalLinkOutcome.rejected;
  return ExternalLinkOutcome.unsupported;
}
