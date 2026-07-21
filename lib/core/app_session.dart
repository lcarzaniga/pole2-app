/// Captured once, as early as possible in `main()`, to mark when this app
/// process/session started.
///
/// The storage-cleanup scan (M8.2C) uses this as its **session cutoff**: only a
/// file whose last-modified time is strictly *before* the session started can be
/// a reclaimable orphan, so a photo copied into `photos/` during this session by
/// an unfinished capture/edit (with no database row yet) is never selected.
///
/// It is a lazily-initialized top-level final; `main()` touches it on the first
/// line so initialization happens at process start, not later on first use.
final DateTime appSessionStart = DateTime.now();

/// Forces [appSessionStart] to initialize now. Called at the very start of
/// `main()` so the cutoff reflects process start.
DateTime captureAppSessionStart() => appSessionStart;
