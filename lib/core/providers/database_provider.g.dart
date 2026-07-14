// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single, app-wide [AppDatabase] instance.
///
/// `keepAlive` because the database must live for the whole app session;
/// features depend on this provider rather than constructing their own
/// connection, guaranteeing exactly one writer and one source of truth.
///
/// `onDispose` closes the connection so resources are released cleanly if the
/// provider container is ever torn down (e.g. in tests).

@ProviderFor(database)
final databaseProvider = DatabaseProvider._();

/// Single, app-wide [AppDatabase] instance.
///
/// `keepAlive` because the database must live for the whole app session;
/// features depend on this provider rather than constructing their own
/// connection, guaranteeing exactly one writer and one source of truth.
///
/// `onDispose` closes the connection so resources are released cleanly if the
/// provider container is ever torn down (e.g. in tests).

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Single, app-wide [AppDatabase] instance.
  ///
  /// `keepAlive` because the database must live for the whole app session;
  /// features depend on this provider rather than constructing their own
  /// connection, guaranteeing exactly one writer and one source of truth.
  ///
  /// `onDispose` closes the connection so resources are released cleanly if the
  /// provider container is ever torn down (e.g. in tests).
  DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'0fe56aaf5bde72ce9021e425b918c495557124c1';
