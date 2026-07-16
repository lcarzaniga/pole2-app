// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The application's single [GoRouter] instance.
///
/// Exposed as a provider (rather than a bare global) so navigation can later
/// react to app state — e.g. an onboarding gate — via `redirect` reading other
/// providers, without restructuring call sites. `keepAlive` because the router
/// lives for the whole app lifetime.
///
/// Note: `/possession/new` is declared before `/possession/:id` so the literal
/// `new` isn't captured as an id.

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// The application's single [GoRouter] instance.
///
/// Exposed as a provider (rather than a bare global) so navigation can later
/// react to app state — e.g. an onboarding gate — via `redirect` reading other
/// providers, without restructuring call sites. `keepAlive` because the router
/// lives for the whole app lifetime.
///
/// Note: `/possession/new` is declared before `/possession/:id` so the literal
/// `new` isn't captured as an id.

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// The application's single [GoRouter] instance.
  ///
  /// Exposed as a provider (rather than a bare global) so navigation can later
  /// react to app state — e.g. an onboarding gate — via `redirect` reading other
  /// providers, without restructuring call sites. `keepAlive` because the router
  /// lives for the whole app lifetime.
  ///
  /// Note: `/possession/new` is declared before `/possession/:id` so the literal
  /// `new` isn't captured as an id.
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'd1a6e2fffdb933a34c87f82a267bc1cddb3bf8f3';
