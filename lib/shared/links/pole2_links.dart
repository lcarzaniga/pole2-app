/// The canonical public web addresses of Pole², plus the single security rule
/// that governs every outbound link the app may open.
///
/// This module is deliberately **pure** (no Flutter, no platform, no I/O) so
/// both the UI and the native platform facade depend on exactly one definition
/// of "a link Pole² is allowed to open", and so that definition is fully
/// unit-testable. Lives in `shared/` rather than in the Information feature
/// because the platform facade must not depend on a feature.
library;

/// The one host Pole² will ever open. Anything else is refused.
const String kPole2Host = 'pole2.app';

/// The public pages the app links to.
enum Pole2Link {
  /// The landing / home page.
  site,

  /// How to use the app, calmly.
  guide,

  /// What changed between versions.
  news,

  /// The support form (carries the installed version/build — nothing else).
  support,

  /// The privacy explanation.
  privacy,
}

/// The canonical path of each link. Trailing slashes match the live site's
/// clean URLs, so no redirect hop is needed.
String pole2LinkPath(Pole2Link link) => switch (link) {
  Pole2Link.site => '/',
  Pole2Link.guide => '/guida/',
  Pole2Link.news => '/novita/',
  Pole2Link.support => '/supporto/',
  Pole2Link.privacy => '/privacy/',
};

/// Builds the absolute URL for [link].
///
/// [Pole2Link.support] is the only address that carries a query, and it carries
/// **only** the installed `v`ersion and `b`uild — see [supportUrl]. Every other
/// link is a bare path: no query, no identifiers, no telemetry.
String pole2LinkUrl(Pole2Link link, {String? version, String? buildNumber}) =>
    switch (link) {
      Pole2Link.support => supportUrl(
        version: version,
        buildNumber: buildNumber,
      ),
      _ => Uri.https(kPole2Host, pole2LinkPath(link)).toString(),
    };

/// The support address for a given installed build.
///
/// Carries exactly two query parameters — `v` (versionName) and `b`
/// (buildNumber) — so a support message arrives with the information needed to
/// reproduce a problem and nothing more. There is deliberately **no** device
/// id, model, OS build, installation id, email, or inventory data: the app
/// knows those things, and chooses not to say them.
///
/// [Uri.https] performs the percent-encoding, so a value containing `&`, `=`,
/// spaces or non-ASCII cannot break out of its parameter. Empty/unknown values
/// are omitted rather than sent blank.
String supportUrl({String? version, String? buildNumber}) {
  final query = <String, String>{
    if (version != null && version.isNotEmpty) 'v': version,
    if (buildNumber != null && buildNumber.isNotEmpty) 'b': buildNumber,
  };
  return Uri.https(
    kPole2Host,
    pole2LinkPath(Pole2Link.support),
    query.isEmpty ? null : query,
  ).toString();
}

/// Whether [raw] is a URL Pole² is allowed to hand to the browser.
///
/// The rule is an exact-host allowlist, not a pattern match, because every
/// cheap alternative is spoofable: a `contains`/`endsWith` check would accept
/// `pole2.app.evil.com` or `evil-pole2.app`. Requirements, all mandatory:
///
/// - parses as an **absolute** URI (a bare string or path is refused);
/// - scheme is exactly `https` (never `http`, `file`, `intent`, `javascript`);
/// - host equals [kPole2Host] **exactly**, case-insensitively;
/// - carries no credentials (`user:password@…`, a classic phishing dressing);
/// - uses the default HTTPS port (an explicit `:8080` is refused).
///
/// Enforced here *and* independently in Kotlin before `startActivity`, so a
/// bug on one side cannot alone turn this into an open redirector.
bool isAllowedPole2Url(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (!uri.isAbsolute) return false;
  // Uri normalizes the scheme to lower case during parsing.
  if (uri.scheme != 'https') return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (uri.host.toLowerCase() != kPole2Host) return false;
  // `port` reports 443 for https when none is written, so this accepts both the
  // implicit default and an explicit `:443`, and refuses everything else.
  if (uri.port != 443) return false;
  return true;
}
