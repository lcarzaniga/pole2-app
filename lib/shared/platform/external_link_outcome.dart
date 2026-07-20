/// What happened when the app asked the system to open a link.
///
/// Shared by the io and stub implementations so callers switch over one type.
/// Every non-success value is a calm, expected outcome — none is an exception.
enum ExternalLinkOutcome {
  /// The system took the link; a browser is opening.
  opened,

  /// The URL failed the allowlist and was never handed to the system. This is
  /// a programming error caught before it can matter, not a user-facing state.
  rejected,

  /// Nothing on this device can open an https link (no browser installed).
  noHandler,

  /// This platform has no external-link capability (web, tests, desktop).
  unsupported,

  /// The system refused for an unforeseen reason.
  failed,
}
