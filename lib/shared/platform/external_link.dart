/// Platform seam for opening a Pole² web page in the user's **own browser**.
///
/// Resolved per platform via conditional import, matching `photo_store` and
/// `backup_saver`. Deliberately not a WebView: the public site is the web's,
/// not the app's, and an in-app browser would both misrepresent where the user
/// is and drag a browsing surface into a local-first app.
///
/// No new dependency and no permission: Android's `ACTION_VIEW` simply asks the
/// system who handles an https link.
library;

export 'external_link_outcome.dart';
export 'external_link_stub.dart' if (dart.library.io) 'external_link_io.dart';
