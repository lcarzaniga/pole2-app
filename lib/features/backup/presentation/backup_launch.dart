/// Sentinel passed as the Backup route's `extra` when the screen is opened by
/// the updater's backup-before-update flow. In this mode a successfully saved
/// backup pops the screen with `true` (→ the update continues to download); a
/// cancelled picker or a back-out pops `false` (→ back to the update choice).
///
/// Kept dependency-free so it can be shared by the (web-reachable) updater, the
/// router, and both the native and stub Backup screens without pulling any
/// `dart:io` code into the web graph.
library;

const String kBackupLaunchedForUpdate = 'launched_for_update';
